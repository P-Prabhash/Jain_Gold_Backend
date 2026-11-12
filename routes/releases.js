const express = require('express');
const router = express.Router();
const { getPool } = require('../config/database');
const { requirePermission } = require('../middleware/authMiddleware');
const { logActivity, getStaffInfo } = require('../utils/loggerHelper');

// ============================================================
// GET /releases/list
// ============================================================
router.get(['/list', '/releases/list'], requirePermission('release.view'), async (req, res) => {
  const loanId = parseInt(req.query.loan_id || '0', 10);
  const customerId = parseInt(req.query.customer_id || '0', 10);
  const search = String(req.query.search || '').trim();

  try {
    const db = await getPool();
    let sql = `
      SELECT r.*, l.loan_no, c.name AS customer_name, c.customer_code, c.mobile AS customer_mobile, p.amount AS payment_amount
      FROM partial_releases r
      JOIN loans l ON r.loan_id = l.id
      JOIN customers c ON r.customer_id = c.id
      LEFT JOIN payments p ON r.payment_id = p.id
      WHERE 1=1
    `;
    const params = [];

    if (loanId > 0) {
      sql += ' AND r.loan_id = ?';
      params.push(loanId);
    }

    if (customerId > 0) {
      sql += ' AND r.customer_id = ?';
      params.push(customerId);
    }

    if (search) {
      sql += ` AND (r.release_no LIKE ? OR l.loan_no LIKE ? OR c.name LIKE ? OR c.customer_code LIKE ? OR c.mobile LIKE ?)`;
      const term = `%${search}%`;
      params.push(term, term, term, term, term);
    }

    sql += ' ORDER BY r.id DESC';

    const [rows] = await db.query(sql, params);

    return res.json({
      success: true,
      count: rows.length,
      data: rows
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to load releases list.', error: err.message });
  }
});

// ============================================================
// POST /releases/create_partial
// ============================================================
router.post(['/create_partial', '/releases/create_partial'], requirePermission('release.create'), async (req, res) => {
  const loanId = parseInt(req.body.loan_id || '0', 10);
  const items = req.body.items || req.body.release_items || [];
  const paymentAmount = parseFloat(req.body.payment_amount || '0');
  const paymentMode = String(req.body.payment_mode || 'CASH').trim();
  const remarks = String(req.body.remarks || '').trim();

  if (loanId <= 0 || !Array.isArray(items) || items.length === 0) {
    return res.status(422).json({ success: false, message: 'Valid loan ID and release items are required.' });
  }

  const db = await getPool();
  const conn = await db.getConnection();

  try {
    await conn.beginTransaction();

    const staff = getStaffInfo(req);

    const [loanRows] = await conn.query('SELECT * FROM loans WHERE id = ? FOR UPDATE', [loanId]);
    if (loanRows.length === 0) {
      await conn.rollback();
      conn.release();
      return res.status(404).json({ success: false, message: 'Loan not found.' });
    }

    const loan = loanRows[0];
    const customerId = loan.customer_id;
    const releaseDate = new Date().toISOString().split('T')[0];
    const releaseTime = new Date().toTimeString().split(' ')[0];
    const releaseNo = 'REL-' + new Date().toISOString().slice(0,10).replace(/-/g,'') + '-' + Math.random().toString(36).substring(2,7).toUpperCase();

    let totalReleasedWeight = 0;
    const releasedDetails = [];

    for (const item of items) {
      const goldItemId = typeof item === 'object' ? parseInt(item.gold_item_id || item.id, 10) : parseInt(item, 10);
      if (goldItemId > 0) {
        const [gi] = await conn.query('SELECT * FROM gold_items WHERE id = ?', [goldItemId]);
        if (gi.length > 0) {
          const goldObj = gi[0];
          const w = parseFloat(goldObj.weight || 0);
          totalReleasedWeight += w;

          await conn.query("UPDATE gold_items SET status = 'RELEASED', updated_by = ?, updated_by_name = ? WHERE id = ?", [staff.staffId, staff.staffNameSnapshot, goldItemId]);
          await conn.query("UPDATE loan_gold_items SET status = 'RELEASED', released_weight = pledged_weight, release_date = ? WHERE loan_id = ? AND gold_item_id = ?", [releaseDate, loanId, goldItemId]);

          releasedDetails.push(goldObj);
        }
      }
    }

    let paymentId = null;
    if (paymentAmount > 0) {
      const currentPaid = parseFloat(loan.total_paid || 0);
      const newPaid = currentPaid + paymentAmount;
      const totalDue = parseFloat(loan.total_due || 0);
      const newRemaining = Math.max(0, totalDue - newPaid);

      const receiptNo = 'RCP-REL-' + new Date().toISOString().slice(0,10).replace(/-/g,'') + '-' + Math.random().toString(36).substring(2,7).toUpperCase();
      const [pmtRes] = await conn.query(
        `INSERT INTO payments (
          receipt_no, loan_id, customer_id, payment_type, amount, payment_date, payment_time, payment_mode, previous_paid, new_total_paid, remaining_balance, remarks,
          created_by_id, collected_by, collected_by_name, created_by, created_at
        ) VALUES (?, ?, ?, 'RELEASE_PAYMENT', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
        [
          receiptNo, loanId, customerId, paymentAmount, releaseDate, releaseTime, paymentMode, currentPaid, newPaid, newRemaining, remarks || 'Payment during partial release',
          staff.staffId, staff.staffId, staff.staffNameSnapshot, staff.staffNameSnapshot
        ]
      );

      paymentId = pmtRes.insertId;

      await conn.query(
        `UPDATE loans SET total_paid = ?, remaining_balance = ?, updated_by = ?, updated_by_name = ? WHERE id = ?`,
        [newPaid, newRemaining, staff.staffId, staff.staffNameSnapshot, loanId]
      );
    }

    const [relRes] = await conn.query(
      `INSERT INTO partial_releases (
        release_no, loan_id, customer_id, payment_id, release_type, total_weight_released, release_date, release_time, remarks,
        created_by_id, released_by, processed_by, released_by_name, created_by, created_at
      ) VALUES (?, ?, ?, ?, 'PARTIAL', ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        releaseNo, loanId, customerId, paymentId, totalReleasedWeight, releaseDate, releaseTime, remarks || null,
        staff.staffId, staff.staffId, staff.staffId, staff.staffNameSnapshot, staff.staffNameSnapshot
      ]
    );

    const releaseId = relRes.insertId;

    for (const gObj of releasedDetails) {
      await conn.query(
        `INSERT INTO release_items (release_id, gold_item_id, item_name, purity, weight)
         VALUES (?, ?, ?, ?, ?)`,
        [releaseId, gObj.id, gObj.item_name, gObj.purity, gObj.weight]
      );
    }

    const code = 'TXN-' + Date.now() + '-' + Math.floor(Math.random() * 1000);
    await conn.query(
      `INSERT INTO loan_transactions (
        transaction_code, customer_id, loan_id, transaction_type, amount, weight, reference_id, date, time,
        user_id, staff_id, staff_name, staff_role, created_by, remarks
      ) VALUES (?, ?, ?, 'PARTIAL_RELEASE', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        code, customerId, loanId, paymentAmount, totalReleasedWeight, releaseNo, releaseDate, releaseTime,
        staff.userId, staff.staffId, staff.staffNameSnapshot, staff.userRole, staff.staffNameSnapshot, remarks || 'Partial gold release'
      ]
    );

    // Record Activity Log with Staff Attribution
    await logActivity(conn, {
      req,
      transactionId: code,
      moduleName: 'Releases',
      actionType: 'GOLD_RELEASED',
      description: `Partial release of ${totalReleasedWeight}g gold for loan ${loan.loan_no}`,
      customerId,
      loanId,
      paymentId,
      goldWeight: totalReleasedWeight,
      amount: paymentAmount,
      paymentMode
    });

    await conn.commit();
    conn.release();

    const [created] = await db.query('SELECT * FROM partial_releases WHERE id = ?', [releaseId]);

    return res.status(201).json({
      success: true,
      message: 'Partial gold release recorded successfully.',
      data: created[0]
    });

  } catch (err) {
    await conn.rollback();
    conn.release();
    return res.status(500).json({ success: false, message: 'Failed to record partial release: ' + err.message });
  }
});

module.exports = router;
