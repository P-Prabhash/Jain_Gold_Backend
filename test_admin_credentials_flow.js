const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');
const bcrypt = require('bcryptjs');
const { getPool } = require('./config/database');

const authRoutes = require('./routes/auth');
const settingsRoutes = require('./routes/settings');
const userRoutes = require('./routes/users');

async function testAdminCredentialsFlow() {
  console.log('=== STARTING ADMIN CREDENTIALS UPDATE & LOGIN E2E TESTS ===\n');

  const app = express();
  app.use(express.json());
  app.use('/auth', authRoutes);
  app.use('/settings', settingsRoutes);
  app.use('/users', userRoutes);

  const PORT = 9877;
  const server = app.listen(PORT);

  const db = await getPool();
  const conn = await db.getConnection();

  try {
    // -------------------------------------------------------------------------
    // TEST 1: Login using default admin credentials (admin / admin123)
    // -------------------------------------------------------------------------
    console.log('Test 1: Login with initial credentials (admin / admin123)...');

    // Ensure admin user exists with known password 'admin123'
    const defaultHash = bcrypt.hashSync('admin123', 10);
    const [admins] = await conn.query("SELECT * FROM users WHERE LOWER(username) = 'admin' OR role = 'ADMIN' LIMIT 1");
    let adminId = 0;
    if (admins.length > 0) {
      adminId = admins[0].id;
      await conn.query("UPDATE users SET username = 'admin', password_hash = ?, status = 'ACTIVE' WHERE id = ?", [defaultHash, adminId]);
    } else {
      const [ins] = await conn.query("INSERT INTO users (username, password_hash, full_name, role, status) VALUES ('admin', ?, 'Administrator', 'ADMIN', 'ACTIVE')", [defaultHash]);
      adminId = ins.insertId;
    }

    const loginRes1 = await fetch(`http://localhost:${PORT}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'admin123' })
    }).then(r => r.json());

    console.log('   Login success:', loginRes1.success);
    console.log('   Message:', loginRes1.message);
    console.assert(loginRes1.success === true, 'Test 1 Failed: Admin login with admin123 failed');
    const adminToken = loginRes1.token || (loginRes1.data ? loginRes1.data.token : null);
    console.assert(!!adminToken, 'Test 1 Failed: Token not returned');
    console.log('  ✓ Test 1 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 2: Update Admin Credentials to new username & password
    // -------------------------------------------------------------------------
    console.log('Test 2: Update Admin Credentials to new_admin_user / NewPass789!...');
    const newUsername = 'new_admin_user';
    const newPassword = 'NewPass789!';

    const updateRes = await fetch(`http://localhost:${PORT}/settings/update_admin_credentials`, {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + adminToken,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        current_password: 'admin123',
        new_username: newUsername,
        new_password: newPassword,
        confirm_password: newPassword
      })
    }).then(r => r.json());

    console.log('   Update response:', updateRes);
    console.log('   Update response success:', updateRes.success);
    console.log('   Update message:', updateRes.message);
    console.assert(updateRes.success === true, 'Test 2 Failed: Update credentials failed');
    console.log('  ✓ Test 2 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 3: Verify MySQL Database Record
    // -------------------------------------------------------------------------
    console.log('Test 3: Verify MySQL Database Record updated...');
    const [dbCheck] = await conn.query("SELECT id, username, password_hash FROM users WHERE id = ?", [adminId]);
    console.log('   Persisted Username:', dbCheck[0].username);
    console.assert(dbCheck[0].username === newUsername, 'Test 3 Failed: Username not updated in DB');
    const isNewHashMatching = bcrypt.compareSync(newPassword, dbCheck[0].password_hash);
    console.assert(isNewHashMatching === true, 'Test 3 Failed: Password hash in DB does not match new password');
    console.log('  ✓ Test 3 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 4: Login with NEW Admin credentials (new_admin_user / NewPass789!)
    // -------------------------------------------------------------------------
    console.log('Test 4: Login with NEW credentials (new_admin_user / NewPass789!)...');
    const loginRes2 = await fetch(`http://localhost:${PORT}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: newUsername, password: newPassword })
    }).then(r => r.json());

    console.log('   New Login success:', loginRes2.success);
    console.log('   Message:', loginRes2.message);
    console.assert(loginRes2.success === true, 'Test 4 Failed: Login with new credentials failed');
    console.log('  ✓ Test 4 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 5: Confirm OLD credentials no longer work (admin / admin123)
    // -------------------------------------------------------------------------
    console.log('Test 5: Confirm OLD credentials (admin / admin123) are rejected (401)...');
    const loginRes3 = await fetch(`http://localhost:${PORT}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'admin123' })
    });
    const loginRes3Data = await loginRes3.json();
    console.log('   HTTP Status:', loginRes3.status);
    console.log('   Response:', loginRes3Data);
    console.assert(loginRes3.status === 401, 'Test 5 Failed: Status code not 401');
    console.assert(loginRes3Data.success === false, 'Test 5 Failed: Old credentials still accepted');
    console.log('  ✓ Test 5 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 6: Test Duplicate Username rejection
    // -------------------------------------------------------------------------
    console.log('Test 6: Test Duplicate Username rejection...');
    // Create another user 'staff_dup'
    const [staffRes] = await conn.query("INSERT IGNORE INTO users (username, password_hash, full_name, role, status) VALUES ('staff_dup', ?, 'Staff Duplicate', 'STAFF', 'ACTIVE')", [defaultHash]);
    const staffId = staffRes.insertId || (await conn.query("SELECT id FROM users WHERE username = 'staff_dup'"))[0][0].id;

    const newAdminToken = loginRes2.token || (loginRes2.data ? loginRes2.data.token : null);
    const dupRes = await fetch(`http://localhost:${PORT}/settings/update_admin_credentials`, {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + newAdminToken,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        current_password: newPassword,
        new_username: 'staff_dup'
      })
    });
    const dupResData = await dupRes.json();
    console.log('   HTTP Status:', dupRes.status);
    console.log('   Response:', dupResData);
    console.assert(dupRes.status === 409, 'Test 6 Failed: Duplicate username not rejected with 409');
    console.assert(dupResData.success === false, 'Test 6 Failed: Duplicate username returned success');
    console.log('  ✓ Test 6 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 7: Test Staff User Login and Password Reset
    // -------------------------------------------------------------------------
    console.log('Test 7: Confirm Staff Login and Staff Password Reset remain functional...');
    const staffPass1 = 'staff123';
    const staffHash1 = bcrypt.hashSync(staffPass1, 10);
    await conn.query("UPDATE users SET password_hash = ?, status = 'ACTIVE' WHERE id = ?", [staffHash1, staffId]);

    // Test staff login with staff123
    const staffLogin1 = await fetch(`http://localhost:${PORT}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'staff_dup', password: staffPass1 })
    }).then(r => r.json());

    console.log('   Staff initial login success:', staffLogin1.success);
    console.assert(staffLogin1.success === true, 'Test 7 Failed: Staff initial login failed');

    // Reset staff password using /users/reset_password
    const staffNewPass = 'NewStaffPass789!';
    const resetRes = await fetch(`http://localhost:${PORT}/users/reset_password`, {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + newAdminToken,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        user_id: staffId,
        new_password: staffNewPass
      })
    }).then(r => r.json());

    console.log('   Staff reset password response:', resetRes.message);
    console.assert(resetRes.success === true, 'Test 7 Failed: Staff reset password failed');

    // Login staff with NEW password
    const staffLogin2 = await fetch(`http://localhost:${PORT}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'staff_dup', password: staffNewPass })
    }).then(r => r.json());

    console.log('   Staff login with new password success:', staffLogin2.success);
    console.assert(staffLogin2.success === true, 'Test 7 Failed: Staff login with new password failed');

    // Login staff with OLD password (should fail)
    const staffLogin3 = await fetch(`http://localhost:${PORT}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'staff_dup', password: staffPass1 })
    });
    console.log('   Staff login with old password status:', staffLogin3.status);
    console.assert(staffLogin3.status === 401, 'Test 7 Failed: Staff login with old password should fail (401)');
    console.log('  ✓ Test 7 Passed!\n');

    if (staffId > 0) await conn.query("DELETE FROM users WHERE id = ?", [staffId]);

    // Restore original admin credentials (admin / admin123)
    await conn.query("UPDATE users SET username = 'admin', password_hash = ? WHERE id = ?", [defaultHash, adminId]);
    console.log('Restored default admin credentials for system cleanliness.');

  } catch (err) {
    console.error('Test Execution Error:', err);
  } finally {
    conn.release();
    server.close();
    console.log('=== ALL ADMIN CREDENTIAL TESTS COMPLETED SUCCESSFULLY ===');
    process.exit(0);
  }
}

testAdminCredentialsFlow();
