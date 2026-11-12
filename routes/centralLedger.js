const express = require('express');
const router = express.Router();
const { getPool } = require('../config/database');
const { requirePermission, authenticate } = require('../middleware/authMiddleware');
const { getStaffInfo } = require('../utils/loggerHelper');

// Helper to sanitize dates (YYYY-MM-DD)
function sanitizeDate(dateStr) {
  if (!dateStr) return null;
  const d = String(dateStr).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(d)) return d;
  if (/^\d{4}-\d{2}-\d{2}T/.test(d)) return d.split('T')[0];
  return null;
}

// ============================================================
// GET /api/central-ledger/staff
// Returns list of Admin and Staff users for dropdown filters
// ============================================================
router.get(['/staff', '/api/central-ledger/staff', '/central-ledger/staff'], authenticate, async (req, res) => {
  try {
    const db = await getPool();
    const [rows] = await db.query(`
      SELECT
        id,
        id AS staff_id,
        username,
        full_name,
        full_name AS staff_name,
        role,
        role AS staff_role,
        status,
        email,
        mobile,
        employee_id,
        department,
        designation
      FROM users
      ORDER BY role ASC, full_name ASC
    `);

    return res.json({
      success: true,
      count: rows.length,
      data: rows,
      staff: rows
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to fetch staff list.', error: err.message });
  }
});

// ============================================================
// GET /api/central-ledger/transactions
// Get central ledger transactions with pagination & staff filters
// ============================================================
router.get(['/transactions', '/list', '/api/central-ledger/transactions', '/central-ledger/transactions'], authenticate, async (req, res) => {
  const search = String(req.query.search || req.query.query || req.query.q || '').trim();
  const staffIdParam = req.query.staffId || req.query.staff_id || req.query.user_id;
  const staffId = (staffIdParam && staffIdParam !== 'ALL' && parseInt(staffIdParam, 10) > 0) ? parseInt(staffIdParam, 10) : null;
  const eventType = String(req.query.eventType || req.query.event_type || req.query.action_type || req.query.transaction_type || '').trim().toUpperCase();

  const fromDate = sanitizeDate(req.query.fromDate || req.query.from_date || req.query.start_date);
  const toDate = sanitizeDate(req.query.toDate || req.query.to_date || req.query.end_date);

  const page = Math.max(1, parseInt(req.query.page || '1', 10));
  const limit = Math.max(1, Math.min(500, parseInt(req.query.limit || '25', 10)));
  const offset = (page - 1) * limit;

  const allowedSortCols = {
    'id': 'a.id',
    'created_at': 'a.created_at',
    'date': 'a.created_at',
    'amount': 'a.amount',
    'gold_weight': 'a.gold_weight',
    'staff_name': 'a.staff_name_snapshot',
    'action_type': 'a.action_type'
  };
  const sortByParam = String(req.query.sortBy || req.query.sort_by || 'created_at').trim().toLowerCase();
  const sortCol = allowedSortCols[sortByParam] || 'a.id';
  const sortOrder = String(req.query.sortOrder || req.query.sort_order || 'DESC').trim().toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

  try {
    const db = await getPool();

    let whereSql = ' WHERE 1=1';
    const params = [];

    if (staffId) {
      whereSql += ' AND (a.staff_id = ? OR a.user_id = ?)';
      params.push(staffId, staffId);
    }

    if (eventType && eventType !== 'ALL') {
      whereSql += ' AND (UPPER(a.action_type) = ? OR UPPER(a.module_name) = ?)';
      params.push(eventType, eventType);
    }

    if (fromDate) {
      whereSql += ' AND DATE(a.created_at) >= ?';
      params.push(fromDate);
    }

    if (toDate) {
      whereSql += ' AND DATE(a.created_at) <= ?';
      params.push(toDate);
    }

    if (search) {
      whereSql += ` AND (
        a.transaction_id LIKE ? OR
        a.staff_name_snapshot LIKE ? OR
        a.action_type LIKE ? OR
        a.module_name LIKE ? OR
        a.description LIKE ? OR
        c.name LIKE ? OR
        c.customer_code LIKE ? OR
        l.loan_no LIKE ? OR
        l.manual_loan_no LIKE ?
      )`;
      const term = `%${search}%`;
      params.push(term, term, term, term, term, term, term, term, term);
    }

    // 1. Total Count Query
    const countSql = `
      SELECT COUNT(*) AS total
      FROM activity_logs a
      LEFT JOIN customers c ON a.customer_id = c.id
      LEFT JOIN loans l ON a.loan_id = l.id
      ${whereSql}
    `;
    const [countRows] = await db.query(countSql, params);
    const totalRecords = parseInt(countRows[0].total || '0', 10);
    const totalPages = Math.ceil(totalRecords / limit) || 1;

    // 2. Fetch Paginated Records
    const dataSql = `
      SELECT
        a.id,
        a.transaction_id AS transaction_code,
        a.transaction_id,
        a.action_type AS event_type,
        a.action_type,
        a.module_name,
        a.user_id,
        a.staff_id,
        COALESCE(NULLIF(TRIM(a.staff_name_snapshot), ''), 'Historical / Not Recorded') AS staff_name,
        COALESCE(NULLIF(TRIM(a.staff_name_snapshot), ''), 'Historical / Not Recorded') AS staff_name_snapshot,
        COALESCE(NULLIF(TRIM(a.user_role), ''), 'N/A') AS staff_role,
        COALESCE(NULLIF(TRIM(a.user_role), ''), 'N/A') AS user_role,
        a.customer_id,
        c.name AS customer_name,
        c.customer_code,
        c.mobile AS customer_mobile,
        a.loan_id,
        l.loan_no,
        l.manual_loan_no,
        COALESCE(l.manual_loan_no, l.loan_no) AS display_loan_no,
        a.payment_id,
        a.receipt_id,
        a.amount,
        a.gold_weight,
        a.payment_mode,
        a.transaction_status,
        a.description AS remarks,
        a.description,
        a.old_values,
        a.new_values,
        a.ip_address,
        DATE_FORMAT(a.created_at, '%Y-%m-%d %H:%i:%s') AS date_time,
        DATE_FORMAT(a.created_at, '%Y-%m-%d') AS date,
        DATE_FORMAT(a.created_at, '%H:%i:%s') AS time,
        a.created_at
      FROM activity_logs a
      LEFT JOIN customers c ON a.customer_id = c.id
      LEFT JOIN loans l ON a.loan_id = l.id
      ${whereSql}
      ORDER BY ${sortCol} ${sortOrder}
      LIMIT ? OFFSET ?
    `;

    const queryParams = [...params, limit, offset];
    const [rows] = await db.query(dataSql, queryParams);

    // Format historical/null attribution cleanly
    for (const r of rows) {
      if (!r.staff_id || r.staff_name === 'Historical / Not Recorded') {
        r.staff_id = null;
        r.user_id = null;
        r.staff_name = 'Historical / Not Recorded';
        r.staff_name_snapshot = 'Historical / Not Recorded';
        r.staff_role = 'N/A';
        r.user_role = 'N/A';
      }
    }

    return res.json({
      success: true,
      count: rows.length,
      pagination: {
        page,
        limit,
        total_records: totalRecords,
        total_pages: totalPages
      },
      data: rows
    });

  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to fetch central ledger transactions.', error: err.message });
  }
});

// ============================================================
// GET /api/central-ledger/staff-summary
// Calculate staff-wise operation counts and financial totals
// ============================================================
router.get(['/staff-summary', '/api/central-ledger/staff-summary', '/central-ledger/staff-summary'], authenticate, async (req, res) => {
  const staffIdParam = req.query.staffId || req.query.staff_id || req.query.user_id;
  const staffId = (staffIdParam && staffIdParam !== 'ALL' && parseInt(staffIdParam, 10) > 0) ? parseInt(staffIdParam, 10) : null;

  const fromDate = sanitizeDate(req.query.fromDate || req.query.from_date || req.query.start_date);
  const toDate = sanitizeDate(req.query.toDate || req.query.to_date || req.query.end_date);

  try {
    const db = await getPool();

    let staffCondition = '';
    const params = [];

    if (staffId) {
      staffCondition = ' AND (staff_id = ? OR user_id = ?)';
      params.push(staffId, staffId);
    }

    if (fromDate) {
      staffCondition += ' AND DATE(created_at) >= ?';
      params.push(fromDate);
    }

    if (toDate) {
      staffCondition += ' AND DATE(created_at) <= ?';
      params.push(toDate);
    }

    // 1. Customers Added (Unique customer creation)
    const [custRows] = await db.query(
      `SELECT COUNT(DISTINCT customer_id) AS cnt FROM activity_logs WHERE action_type = 'CUSTOMER_CREATED' ${staffCondition}`,
      params
    );
    const customersAdded = parseInt(custRows[0].cnt || '0', 10);

    // 2. Gold Items Added
    const [goldRows] = await db.query(
      `SELECT COUNT(*) AS cnt, COALESCE(SUM(gold_weight), 0) AS weight FROM activity_logs WHERE action_type IN ('GOLD_ITEM_ADDED', 'GOLD_ADDED') ${staffCondition}`,
      params
    );
    const goldItemsAdded = parseInt(goldRows[0].cnt || '0', 10);

    // 3. Silver Items Added
    const [silverRows] = await db.query(
      `SELECT COUNT(*) AS cnt FROM activity_logs WHERE action_type IN ('SILVER_ITEM_ADDED', 'SILVER_ADDED') ${staffCondition}`,
      params
    );
    const silverItemsAdded = parseInt(silverRows[0].cnt || '0', 10);

    // 4. Loans Created & Disbursed
    const [loanCreatedRows] = await db.query(
      `SELECT COUNT(*) AS cnt, COALESCE(SUM(amount), 0) AS total_disbursed FROM activity_logs WHERE action_type IN ('LOAN_CREATED', 'EXISTING_LOAN_CREATED', 'ADDITIONAL_LOAN_CREATED') ${staffCondition}`,
      params
    );
    const loansCreated = parseInt(loanCreatedRows[0].cnt || '0', 10);
    const totalDisbursed = parseFloat(loanCreatedRows[0].total_disbursed || '0');

    // 5. Loans Closed
    const [loanClosedRows] = await db.query(
      `SELECT COUNT(*) AS cnt FROM activity_logs WHERE action_type IN ('LOAN_CLOSED', 'FINAL_SETTLEMENT') ${staffCondition}`,
      params
    );
    const loansClosed = parseInt(loanClosedRows[0].cnt || '0', 10);

    // 6. Payments Breakdown
    const [pmtRows] = await db.query(
      `SELECT
        SUM(CASE WHEN action_type = 'PARTIAL_PAYMENT' THEN 1 ELSE 0 END) AS partial_cnt,
        SUM(CASE WHEN action_type = 'INTEREST_PAYMENT' THEN 1 ELSE 0 END) AS interest_cnt,
        SUM(CASE WHEN action_type = 'FINAL_SETTLEMENT' THEN 1 ELSE 0 END) AS settlement_cnt,
        COALESCE(SUM(amount), 0) AS total_collected
      FROM activity_logs
      WHERE action_type IN ('PAYMENT_COLLECTED', 'PARTIAL_PAYMENT', 'INTEREST_PAYMENT', 'PRINCIPAL_PAYMENT', 'FULL_PAYMENT', 'FINAL_SETTLEMENT') ${staffCondition}`,
      params
    );
    const partialPayments = parseInt(pmtRows[0].partial_cnt || '0', 10);
    const interestPayments = parseInt(pmtRows[0].interest_cnt || '0', 10);
    const finalSettlements = parseInt(pmtRows[0].settlement_cnt || '0', 10);
    const totalCollected = parseFloat(pmtRows[0].total_collected || '0');

    // 7. Gold Releases
    const [releaseRows] = await db.query(
      `SELECT COUNT(*) AS cnt, COALESCE(SUM(gold_weight), 0) AS weight FROM activity_logs WHERE action_type IN ('GOLD_RELEASED', 'PARTIAL_RELEASE', 'FULL_RELEASE') ${staffCondition}`,
      params
    );
    const goldReleases = parseInt(releaseRows[0].cnt || '0', 10);
    const totalReleasedWeight = parseFloat(releaseRows[0].weight || '0');

    // 8. Manual Ledger Entries
    const [manualRows] = await db.query(
      `SELECT COUNT(*) AS cnt FROM activity_logs WHERE action_type = 'MANUAL_LEDGER_ENTRY' ${staffCondition}`,
      params
    );
    const manualLedgerEntries = parseInt(manualRows[0].cnt || '0', 10);

    // 9. Staff Profile if specific staffId selected
    let staffProfile = null;
    if (staffId) {
      const [uRows] = await db.query('SELECT id, username, full_name, role, status, mobile, email FROM users WHERE id = ?', [staffId]);
      if (uRows.length > 0) {
        staffProfile = uRows[0];
      }
    }

    return res.json({
      success: true,
      staff: staffProfile,
      summary: {
        customers_added: customersAdded,
        gold_items_added: goldItemsAdded,
        silver_items_added: silverItemsAdded,
        loans_created: loansCreated,
        loans_closed: loansClosed,
        partial_payments: partialPayments,
        interest_payments: interestPayments,
        final_settlements: finalSettlements,
        gold_releases: goldReleases,
        manual_ledger_entries: manualLedgerEntries,
        total_loan_amount_disbursed: totalDisbursed,
        total_payments_collected: totalCollected,
        total_released_weight: totalReleasedWeight
      }
    });

  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to generate staff summary.', error: err.message });
  }
});

// ============================================================
// GET /api/central-ledger/summary
// High-level KPI summary for Central Ledger Overview
// ============================================================
router.get(['/summary', '/api/central-ledger/summary', '/central-ledger/summary'], authenticate, async (req, res) => {
  const staffIdParam = req.query.staffId || req.query.staff_id || req.query.user_id;
  const staffId = (staffIdParam && staffIdParam !== 'ALL' && parseInt(staffIdParam, 10) > 0) ? parseInt(staffIdParam, 10) : null;
  const fromDate = sanitizeDate(req.query.fromDate || req.query.from_date || req.query.start_date);
  const toDate = sanitizeDate(req.query.toDate || req.query.to_date || req.query.end_date);

  try {
    const db = await getPool();

    let whereSql = ' WHERE 1=1';
    const params = [];

    if (staffId) {
      whereSql += ' AND (staff_id = ? OR user_id = ?)';
      params.push(staffId, staffId);
    }

    if (fromDate) {
      whereSql += ' AND DATE(created_at) >= ?';
      params.push(fromDate);
    }

    if (toDate) {
      whereSql += ' AND DATE(created_at) <= ?';
      params.push(toDate);
    }

    const [kpiRows] = await db.query(`
      SELECT
        COUNT(*) AS total_transactions,
        COALESCE(SUM(amount), 0) AS total_amount,
        COALESCE(SUM(gold_weight), 0) AS total_gold_weight,
        SUM(CASE WHEN action_type IN ('LOAN_CREATED', 'EXISTING_LOAN_CREATED', 'ADDITIONAL_LOAN_CREATED') THEN 1 ELSE 0 END) AS total_loans_created,
        SUM(CASE WHEN action_type IN ('LOAN_CREATED', 'EXISTING_LOAN_CREATED', 'ADDITIONAL_LOAN_CREATED') THEN amount ELSE 0 END) AS total_disbursed_amount,
        SUM(CASE WHEN action_type IN ('PAYMENT_COLLECTED', 'PARTIAL_PAYMENT', 'INTEREST_PAYMENT', 'PRINCIPAL_PAYMENT', 'FULL_PAYMENT', 'FINAL_SETTLEMENT') THEN amount ELSE 0 END) AS total_payments_collected,
        SUM(CASE WHEN action_type IN ('LOAN_CLOSED', 'FINAL_SETTLEMENT') THEN 1 ELSE 0 END) AS total_loans_closed,
        SUM(CASE WHEN action_type IN ('GOLD_RELEASED', 'PARTIAL_RELEASE', 'FULL_RELEASE') THEN 1 ELSE 0 END) AS total_gold_releases,
        SUM(CASE WHEN action_type IN ('GOLD_RELEASED', 'PARTIAL_RELEASE', 'FULL_RELEASE') THEN gold_weight ELSE 0 END) AS total_released_weight,
        SUM(CASE WHEN staff_id IS NOT NULL THEN 1 ELSE 0 END) AS staff_attribution_count,
        SUM(CASE WHEN staff_id IS NULL THEN 1 ELSE 0 END) AS historical_count
      FROM activity_logs
      ${whereSql}
    `, params);

    const kpi = kpiRows[0] || {};

    return res.json({
      success: true,
      summary: {
        total_transactions: parseInt(kpi.total_transactions || '0', 10),
        total_amount: parseFloat(kpi.total_amount || '0'),
        total_gold_weight: parseFloat(kpi.total_gold_weight || '0'),
        total_loans_created: parseInt(kpi.total_loans_created || '0', 10),
        total_disbursed_amount: parseFloat(kpi.total_disbursed_amount || '0'),
        total_payments_collected: parseFloat(kpi.total_payments_collected || '0'),
        total_loans_closed: parseInt(kpi.total_loans_closed || '0', 10),
        total_gold_releases: parseInt(kpi.total_gold_releases || '0', 10),
        total_released_weight: parseFloat(kpi.total_released_weight || '0'),
        staff_attribution_count: parseInt(kpi.staff_attribution_count || '0', 10),
        historical_count: parseInt(kpi.historical_count || '0', 10)
      }
    });

  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to fetch ledger summary.', error: err.message });
  }
});

// ============================================================
// GET /api/central-ledger/transactions/:id
// Get comprehensive transaction and staff attribution details
// ============================================================
router.get(['/transactions/:id', '/api/central-ledger/transactions/:id', '/central-ledger/transactions/:id'], authenticate, async (req, res) => {
  const idParam = req.params.id;

  try {
    const db = await getPool();

    let sql = 'SELECT a.* FROM activity_logs a WHERE 1=1';
    const params = [];

    if (/^\d+$/.test(idParam)) {
      sql += ' AND (a.id = ? OR a.transaction_id = ?)';
      params.push(parseInt(idParam, 10), idParam);
    } else {
      sql += ' AND a.transaction_id = ?';
      params.push(idParam);
    }

    const [rows] = await db.query(sql, params);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Transaction record not found.' });
    }

    const tx = rows[0];

    // Fetch related Customer Details
    let customer = null;
    if (tx.customer_id > 0) {
      const [cRows] = await db.query('SELECT * FROM customers WHERE id = ?', [tx.customer_id]);
      if (cRows.length > 0) customer = cRows[0];
    }

    // Fetch related Loan Details with Creators, Closers, Updaters
    let loan = null;
    if (tx.loan_id > 0) {
      const [lRows] = await db.query(`
        SELECT l.*,
          c_user.full_name AS creator_name,
          u_user.full_name AS updater_name,
          cls_user.full_name AS closer_name
        FROM loans l
        LEFT JOIN users c_user ON l.created_by = c_user.id
        LEFT JOIN users u_user ON l.updated_by = u_user.id
        LEFT JOIN users cls_user ON l.closed_by = cls_user.id
        WHERE l.id = ?
      `, [tx.loan_id]);
      if (lRows.length > 0) loan = lRows[0];
    }

    // Fetch related Payment Details
    let payment = null;
    if (tx.payment_id > 0) {
      const [pRows] = await db.query(`
        SELECT p.*,
          u.full_name AS collector_name
        FROM payments p
        LEFT JOIN users u ON p.collected_by = u.id
        WHERE p.id = ?
      `, [tx.payment_id]);
      if (pRows.length > 0) payment = pRows[0];
    }

    // Parse JSON Old & New Values safely
    let oldValues = null;
    let newValues = null;
    try { oldValues = typeof tx.old_values === 'string' ? JSON.parse(tx.old_values) : tx.old_values; } catch (e) {}
    try { newValues = typeof tx.new_values === 'string' ? JSON.parse(tx.new_values) : tx.new_values; } catch (e) {}

    const staffAttribution = {
      user_id: tx.user_id || null,
      staff_id: tx.staff_id || null,
      staff_name: tx.staff_name_snapshot || 'Historical / Not Recorded',
      staff_role: tx.user_role || 'N/A',
      is_historical: !tx.staff_id,
      creator_name: loan ? (loan.creator_name || loan.created_by_name || 'Historical / Not Recorded') : null,
      updater_name: loan ? (loan.updater_name || loan.updated_by_name || null) : null,
      closer_name: loan ? (loan.closer_name || loan.closed_by_name || null) : null,
      collector_name: payment ? (payment.collector_name || payment.collected_by_name || tx.staff_name_snapshot || null) : null
    };

    return res.json({
      success: true,
      data: {
        transaction: {
          ...tx,
          transaction_code: tx.transaction_id,
          event_type: tx.action_type,
          staff_name: staffAttribution.staff_name,
          staff_role: staffAttribution.staff_role,
          date_time: tx.created_at,
          old_values: oldValues,
          new_values: newValues
        },
        staff_attribution: staffAttribution,
        customer,
        loan,
        payment
      }
    });

  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to fetch transaction details.', error: err.message });
  }
});

module.exports = router;
