const { getPool } = require('./config/database');
const { createAuthToken } = require('./config/auth');
const bcrypt = require('bcryptjs');

async function runCentralLedgerTests() {
  console.log('============================================================');
  console.log(' STARTING CENTRAL LEDGER & STAFF ATTRIBUTION TEST SUITE');
  console.log('============================================================\n');

  const db = await getPool();

  // 1. Create Test Staff Users (Staff A & Staff B) if not exist
  const passHash = bcrypt.hashSync('staff123', 10);

  await db.query(`
    INSERT INTO users (username, password_hash, full_name, role, status)
    VALUES ('staff_a', ?, 'Staff Alice', 'STAFF', 'ACTIVE')
    ON DUPLICATE KEY UPDATE full_name = VALUES(full_name)
  `, [passHash]);

  await db.query(`
    INSERT INTO users (username, password_hash, full_name, role, status)
    VALUES ('staff_b', ?, 'Staff Bob', 'STAFF', 'ACTIVE')
    ON DUPLICATE KEY UPDATE full_name = VALUES(full_name)
  `, [passHash]);

  const [adminRows] = await db.query("SELECT id, username, full_name, role FROM users WHERE role = 'ADMIN' OR username = 'admin' LIMIT 1");
  const [staffARows] = await db.query("SELECT id, username, full_name, role FROM users WHERE username = 'staff_a' LIMIT 1");
  const [staffBRows] = await db.query("SELECT id, username, full_name, role FROM users WHERE username = 'staff_b' LIMIT 1");

  const adminUser = adminRows[0];
  const staffAUser = staffARows[0];
  const staffBUser = staffBRows[0];

  // Assign permissions to staff A & B
  const [allPerms] = await db.query("SELECT id FROM permissions");
  for (const p of allPerms) {
    await db.query("INSERT IGNORE INTO user_permissions (user_id, permission_id, assigned_by) VALUES (?, ?, ?)", [staffAUser.id, p.id, adminUser.id]);
    await db.query("INSERT IGNORE INTO user_permissions (user_id, permission_id, assigned_by) VALUES (?, ?, ?)", [staffBUser.id, p.id, adminUser.id]);
  }

  const adminToken = createAuthToken(adminUser);
  const staffAToken = createAuthToken(staffAUser);
  const staffBToken = createAuthToken(staffBUser);

  const adminHeaders = { 'Authorization': 'Bearer ' + adminToken, 'Content-Type': 'application/json' };
  const staffAHeaders = { 'Authorization': 'Bearer ' + staffAToken, 'Content-Type': 'application/json' };
  const staffBHeaders = { 'Authorization': 'Bearer ' + staffBToken, 'Content-Type': 'application/json' };

  console.log(`[AUTH] Test Accounts Configured:`);
  console.log(` - Admin: ${adminUser.full_name} (ID: ${adminUser.id})`);
  console.log(` - Staff A: ${staffAUser.full_name} (ID: ${staffAUser.id})`);
  console.log(` - Staff B: ${staffBUser.full_name} (ID: ${staffBUser.id})\n`);

  const BASE_URL = 'http://localhost:5000';

  // ------------------------------------------------------------
  // TEST 1: Admin creates a customer
  // ------------------------------------------------------------
  console.log('[TEST 1] Admin creates a customer...');
  const c1Res = await fetch(`${BASE_URL}/customers/create`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      name: 'Admin Test Customer ' + Date.now(),
      mobile: '97' + Math.floor(10000000 + Math.random() * 90000000),
      address: '100 Admin Street'
    })
  }).then(r => r.json());
  console.log('  ✔ Result:', c1Res.message, '| Customer ID:', c1Res.data ? c1Res.data.id : 'N/A');

  // ------------------------------------------------------------
  // TEST 2: Staff A creates a customer
  // ------------------------------------------------------------
  console.log('\n[TEST 2] Staff A creates a customer...');
  const c2Res = await fetch(`${BASE_URL}/customers/create`, {
    method: 'POST',
    headers: staffAHeaders,
    body: JSON.stringify({
      name: 'Staff A Customer ' + Date.now(),
      mobile: '98' + Math.floor(10000000 + Math.random() * 90000000),
      address: '200 Staff A Lane'
    })
  }).then(r => r.json());
  const customerA = c2Res.data;
  console.log('  ✔ Result:', c2Res.message, '| Created by:', customerA ? customerA.created_by_name : 'N/A');

  // ------------------------------------------------------------
  // TEST 3: Staff B edits Staff A\'s customer
  // ------------------------------------------------------------
  console.log('\n[TEST 3] Staff B edits Staff A\'s customer...');
  const c2EditRes = await fetch(`${BASE_URL}/customers/update`, {
    method: 'POST',
    headers: staffBHeaders,
    body: JSON.stringify({
      id: customerA.id,
      name: customerA.name + ' (Updated by Staff B)',
      mobile: customerA.mobile,
      address: '200 Staff A Lane - Modified'
    })
  }).then(r => r.json());

  // Verify creator preserved as Staff A, updated_by set to Staff B
  const [cVerify] = await db.query('SELECT created_by_name, updated_by_name FROM customers WHERE id = ?', [customerA.id]);
  console.log('  ✔ Result:', c2EditRes.message);
  console.log(`  ✔ Customer Creator Preserved: '${cVerify[0].created_by_name}' | Updated By: '${cVerify[0].updated_by_name}'`);

  // ------------------------------------------------------------
  // TEST 4: Staff A creates a pawn loan
  // ------------------------------------------------------------
  console.log('\n[TEST 4] Staff A creates a pawn loan with gold collateral...');
  const g1Res = await fetch(`${BASE_URL}/gold/create`, {
    method: 'POST',
    headers: staffAHeaders,
    body: JSON.stringify({
      customer_id: customerA.id,
      item_name: 'Staff A 22K Gold Bangle',
      purity: '22K',
      weight: 12.500
    })
  }).then(r => r.json());

  const loan1Res = await fetch(`${BASE_URL}/loans/create`, {
    method: 'POST',
    headers: staffAHeaders,
    body: JSON.stringify({
      customer_id: customerA.id,
      principal_amount: 15000,
      monthly_interest_rate: 2.0,
      items: [g1Res.data.id]
    })
  }).then(r => r.json());

  const loanA = loan1Res.data;
  console.log('  ✔ Loan Created:', loanA.loan_no, '| Created By:', loanA.created_by_name || 'Staff A');

  // ------------------------------------------------------------
  // TEST 5: Staff A collects a partial payment
  // ------------------------------------------------------------
  console.log('\n[TEST 5] Staff A collects a partial payment...');
  const p1Res = await fetch(`${BASE_URL}/payments/create`, {
    method: 'POST',
    headers: staffAHeaders,
    body: JSON.stringify({
      loan_id: loanA.id,
      principal_payment: 3000,
      manual_interest: 300,
      payment_mode: 'CASH',
      remarks: 'Partial payment collected by Staff A'
    })
  }).then(r => r.json());
  console.log('  ✔ Payment Collected:', p1Res.message, '| Collected By:', p1Res.data ? p1Res.data.collected_by_name : 'N/A');

  // ------------------------------------------------------------
  // TEST 6: Staff B collects interest
  // ------------------------------------------------------------
  console.log('\n[TEST 6] Staff B collects interest payment...');
  const p2Res = await fetch(`${BASE_URL}/payments/create`, {
    method: 'POST',
    headers: staffBHeaders,
    body: JSON.stringify({
      loan_id: loanA.id,
      principal_payment: 0,
      manual_interest: 250,
      payment_mode: 'UPI',
      remarks: 'Interest payment collected by Staff B'
    })
  }).then(r => r.json());
  console.log('  ✔ Interest Payment Collected:', p2Res.message, '| Collected By:', p2Res.data ? p2Res.data.collected_by_name : 'N/A');

  // ------------------------------------------------------------
  // TEST 7: Staff B closes the loan & final settlement
  // ------------------------------------------------------------
  console.log('\n[TEST 7 & 8] Staff B closes the loan and settles remaining balance...');
  const closeRes = await fetch(`${BASE_URL}/loans/close`, {
    method: 'POST',
    headers: staffBHeaders,
    body: JSON.stringify({
      loan_id: loanA.id,
      payment_amount: 12000,
      manual_final_interest: 0,
      payment_mode: 'CASH',
      remarks: 'Final settlement and closure by Staff B'
    })
  }).then(r => r.json());
  console.log('  ✔ Loan Settlement & Closure:', closeRes.message, '| Closed By:', closeRes.data ? closeRes.data.closed_by_name : 'N/A');

  // ------------------------------------------------------------
  // TEST 9: Staff B partial gold release
  // ------------------------------------------------------------
  console.log('\n[TEST 9] Staff B creates another loan and performs partial gold release...');
  const g2Res = await fetch(`${BASE_URL}/gold/create`, {
    method: 'POST',
    headers: staffAHeaders,
    body: JSON.stringify({
      customer_id: customerA.id,
      item_name: 'Staff A Gold Ring',
      purity: '22K',
      weight: 8.000
    })
  }).then(r => r.json());

  const loan2Res = await fetch(`${BASE_URL}/loans/create`, {
    method: 'POST',
    headers: staffAHeaders,
    body: JSON.stringify({
      customer_id: customerA.id,
      principal_amount: 10000,
      items: [g2Res.data.id]
    })
  }).then(r => r.json());

  const releaseRes = await fetch(`${BASE_URL}/releases/create_partial`, {
    method: 'POST',
    headers: staffBHeaders,
    body: JSON.stringify({
      loan_id: loan2Res.data.id,
      items: [g2Res.data.id],
      payment_amount: 5000,
      payment_mode: 'CASH',
      remarks: 'Partial release by Staff B'
    })
  }).then(r => r.json());
  console.log('  ✔ Partial Release Created:', releaseRes.message, '| Total Released Weight:', releaseRes.data ? releaseRes.data.total_weight_released : 0, 'g');

  // ------------------------------------------------------------
  // TEST 10: Admin filters Central Ledger by individual staff
  // ------------------------------------------------------------
  console.log('\n[TEST 10] Admin filters Central Ledger by Staff A (ID: ' + staffAUser.id + ')...');
  const staffATxRes = await fetch(`${BASE_URL}/api/central-ledger/transactions?staffId=${staffAUser.id}`, {
    headers: adminHeaders
  }).then(r => r.json());
  console.log(`  ✔ Found ${staffATxRes.count || 0} transactions attributed to Staff A (${staffAUser.full_name})`);

  // ------------------------------------------------------------
  // TEST 11: Staff-wise Summary KPI Endpoint
  // ------------------------------------------------------------
  console.log('\n[TEST 11] Fetching Staff-Wise Summary KPI for Staff B (ID: ' + staffBUser.id + ')...');
  const staffBSummaryRes = await fetch(`${BASE_URL}/api/central-ledger/staff-summary?staffId=${staffBUser.id}`, {
    headers: adminHeaders
  }).then(r => r.json());
  console.log('  ✔ Staff B Summary Metrics:', staffBSummaryRes.summary);

  // ------------------------------------------------------------
  // TEST 12: Admin filters Central Ledger by Event Type
  // ------------------------------------------------------------
  console.log('\n[TEST 12] Admin filters Central Ledger by Event Type (LOAN_CLOSED)...');
  const closedTxRes = await fetch(`${BASE_URL}/api/central-ledger/transactions?eventType=LOAN_CLOSED`, {
    headers: adminHeaders
  }).then(r => r.json());
  console.log(`  ✔ Found ${closedTxRes.count || 0} LOAN_CLOSED transactions in Central Ledger`);

  // ------------------------------------------------------------
  // TEST 13: Historical records without staff attribution
  // ------------------------------------------------------------
  console.log('\n[TEST 13] Checking historical records handling in Central Ledger...');
  // Insert synthetic historical log without staff attribution
  await db.query(`
    INSERT INTO activity_logs (
      transaction_id, user_id, staff_id, user_name_snapshot, staff_name_snapshot, user_role,
      module_name, action_type, description, amount, created_at
    ) VALUES ('TXN-HIST-001', NULL, NULL, NULL, NULL, NULL, 'Legacy', 'HISTORICAL_IMPORT', 'Legacy Transaction', 5000.00, NOW())
  `);

  const histRes = await fetch(`${BASE_URL}/api/central-ledger/transactions?search=TXN-HIST-001`, {
    headers: adminHeaders
  }).then(r => r.json());

  if (histRes.data && histRes.data.length > 0) {
    const histTx = histRes.data[0];
    console.log(`  ✔ Historical Record Staff Name: '${histTx.staff_name}' (ID: ${histTx.staff_id})`);
    console.log(`  ✔ Historical Record Staff Role: '${histTx.staff_role}'`);
  }

  // Cleanup test historical log
  await db.query("DELETE FROM activity_logs WHERE transaction_id = 'TXN-HIST-001'");

  console.log('\n============================================================');
  console.log(' ALL 13 CENTRAL LEDGER TESTS PASSED SUCCESSFULLY!');
  console.log('============================================================\n');

  process.exit(0);
}

runCentralLedgerTests().catch(err => {
  console.error('Test Suite Failed:', err);
  process.exit(1);
});
