const { getPool } = require('../config/database');

/**
 * Extracts staff attribution details from Express req or User object.
 * Never trusts frontend-provided staff identities.
 */
function getStaffInfo(reqOrUser) {
  let user = null;
  let req = null;

  if (reqOrUser && reqOrUser.user) {
    req = reqOrUser;
    user = reqOrUser.user;
  } else if (reqOrUser && reqOrUser.id) {
    user = reqOrUser;
  }

  if (!user) {
    return {
      userId: null,
      staffId: null,
      userNameSnapshot: 'System / Historical',
      staffNameSnapshot: 'Historical / Not Recorded',
      userRole: 'N/A',
      ipAddress: null
    };
  }

  const userId = parseInt(user.id || 0, 10) || null;
  const staffId = userId;
  const userNameSnapshot = String(user.full_name || user.username || `Staff #${userId}`).trim();
  const staffNameSnapshot = userNameSnapshot;
  const userRole = String(user.role || 'STAFF').trim().toUpperCase();
  const ipAddress = req ? (req.headers['x-forwarded-for'] || req.ip || (req.socket ? req.socket.remoteAddress : null) || null) : null;

  return {
    userId,
    staffId,
    userNameSnapshot,
    staffNameSnapshot,
    userRole,
    ipAddress
  };
}

/**
 * Logs an activity into activity_logs and audit_logs tables.
 * Can accept a database connection (for atomic MySQL transactions) or pool.
 */
async function logActivity(connOrDb, params) {
  try {
    const db = connOrDb || await getPool();
    const staff = getStaffInfo(params.req || params.user);

    const transactionId = params.transactionId || params.transaction_id || ('TXN-' + Date.now() + '-' + Math.floor(Math.random() * 1000));
    const moduleName = String(params.moduleName || params.module_name || 'System').trim();
    const actionType = String(params.actionType || params.action_type || params.action || 'GENERAL_ACTION').trim().toUpperCase();
    const description = String(params.description || params.remarks || '').trim();

    const customerId = parseInt(params.customerId || params.customer_id || 0, 10) || null;
    const loanId = parseInt(params.loanId || params.loan_id || 0, 10) || null;
    const paymentId = parseInt(params.paymentId || params.payment_id || 0, 10) || null;
    const receiptId = parseInt(params.receiptId || params.receipt_id || 0, 10) || null;

    const amount = parseFloat(params.amount || 0);
    const goldWeight = parseFloat(params.goldWeight || params.gold_weight || params.weight || 0);
    const paymentMode = params.paymentMode || params.payment_mode || null;
    const transactionStatus = String(params.transactionStatus || params.transaction_status || 'SUCCESS').trim().toUpperCase();

    const oldValues = (params.oldValues || params.old_data || params.old_values) ? JSON.stringify(params.oldValues || params.old_data || params.old_values) : null;
    const newValues = (params.newValues || params.new_data || params.new_values) ? JSON.stringify(params.newValues || params.new_data || params.new_values) : null;

    // 1. Insert into activity_logs
    await db.query(`
      INSERT INTO activity_logs (
        transaction_id, user_id, staff_id, user_name_snapshot, staff_name_snapshot, user_role,
        module_name, action_type, description, customer_id, loan_id, payment_id, receipt_id,
        amount, gold_weight, payment_mode, transaction_status, old_values, new_values, ip_address, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    `, [
      transactionId, staff.userId, staff.staffId, staff.userNameSnapshot, staff.staffNameSnapshot, staff.userRole,
      moduleName, actionType, description || null, customerId, loanId, paymentId, receiptId,
      amount, goldWeight, paymentMode, transactionStatus, oldValues, newValues, staff.ipAddress
    ]);

    // 2. Insert into audit_logs (for audit trail consistency)
    try {
      await db.query(`
        INSERT INTO audit_logs (
          user_id, username, action, module_name, reference_type, reference_id,
          old_data, new_data, description, ip_address, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
      `, [
        staff.userId, staff.staffNameSnapshot, actionType, moduleName,
        loanId ? 'LOAN' : (customerId ? 'CUSTOMER' : (paymentId ? 'PAYMENT' : 'SYSTEM')),
        String(loanId || customerId || paymentId || transactionId),
        oldValues, newValues, description || null, staff.ipAddress
      ]);
    } catch (e) {
      // ignore
    }

    return {
      success: true,
      transactionId,
      staff
    };

  } catch (err) {
    console.warn('[LOGGER WARNING] Activity logging failed:', err.message);
    return { success: false, error: err.message };
  }
}

module.exports = {
  getStaffInfo,
  logActivity
};
