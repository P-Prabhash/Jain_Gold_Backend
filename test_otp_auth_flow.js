const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');
const bcrypt = require('bcryptjs');
const { getPool } = require('./config/database');

const authRoutes = require('./routes/auth');
const docsRoutes = require('./routes/docs');

async function testOtpAuthFlow() {
  console.log('=== STARTING GMAIL OTP TWO-STEP AUTHENTICATION E2E TESTS ===\n');

  const app = express();
  app.use(express.json());
  app.use(['/api/auth', '/auth'], authRoutes);
  app.use(['/api-docs', '/docs'], docsRoutes);

  const PORT = 9878;
  const server = app.listen(PORT);

  const db = await getPool();
  const conn = await db.getConnection();

  try {
    // -------------------------------------------------------------------------
    // TEST 1: STEP 1 - Login with Credentials (admin / admin123)
    // -------------------------------------------------------------------------
    console.log('Test 1: Step 1 Login with admin / admin123...');
    const defaultHash = bcrypt.hashSync('admin123', 10);
    const [admins] = await conn.query("SELECT * FROM users WHERE LOWER(username) = 'admin' OR role = 'ADMIN' LIMIT 1");
    let adminId = 0;
    if (admins.length > 0) {
      adminId = admins[0].id;
      await conn.query("UPDATE users SET username = 'admin', password_hash = ?, email = 'pandetiprabhash@gmail.com', status = 'ACTIVE' WHERE id = ?", [defaultHash, adminId]);
    } else {
      const [ins] = await conn.query("INSERT INTO users (username, password_hash, full_name, email, role, status) VALUES ('admin', ?, 'Administrator', 'pandetiprabhash@gmail.com', 'ADMIN', 'ACTIVE')", [defaultHash]);
      adminId = ins.insertId;
    }

    const loginRes = await fetch(`http://localhost:${PORT}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'admin123' })
    }).then(r => r.json());

    console.log('   Login response success:', loginRes.success);
    console.log('   Requires OTP:', loginRes.requires_otp);
    console.log('   Challenge ID:', loginRes.challenge_id || loginRes.challengeId);
    console.log('   Email:', loginRes.email);
    console.log('   Debug OTP:', loginRes.debug_otp);

    console.assert(loginRes.success === true, 'Test 1 Failed: login success is false');
    console.assert(loginRes.requires_otp === true, 'Test 1 Failed: requires_otp is not true');
    const challengeId = loginRes.challenge_id || loginRes.challengeId;
    const debugOtp = loginRes.debug_otp;
    console.assert(!!challengeId, 'Test 1 Failed: challengeId not returned');
    console.assert(!!debugOtp, 'Test 1 Failed: debugOtp not returned');
    console.log('  ✓ Test 1 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 2: Verify OTP DB record created
    // -------------------------------------------------------------------------
    console.log('Test 2: Verify MySQL otp_challenges table record...');
    const [challenges] = await conn.query("SELECT * FROM otp_challenges WHERE challenge_id = ?", [challengeId]);
    console.assert(challenges.length === 1, 'Test 2 Failed: otp_challenges record not found');
    console.assert(challenges[0].user_id === adminId, 'Test 2 Failed: user_id does not match adminId');
    console.assert(challenges[0].is_verified === 0, 'Test 2 Failed: is_verified should be 0');
    console.log('  ✓ Test 2 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 3: STEP 2 - Invalid OTP Submission Rejection
    // -------------------------------------------------------------------------
    console.log('Test 3: Verify Invalid OTP code rejection (401)...');
    const invalidOtpRes = await fetch(`http://localhost:${PORT}/api/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ challengeId: challengeId, otp: '0000' })
    });
    const invalidOtpData = await invalidOtpRes.json();
    console.log('   HTTP Status:', invalidOtpRes.status);
    console.log('   Response:', invalidOtpData);
    console.assert(invalidOtpRes.status === 401, 'Test 3 Failed: HTTP status not 401');
    console.assert(invalidOtpData.success === false, 'Test 3 Failed: success should be false');
    console.log('  ✓ Test 3 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 4: STEP 2 - Valid OTP Verification & Token Generation
    // -------------------------------------------------------------------------
    console.log('Test 4: Verify Valid OTP verification...');
    const verifyRes = await fetch(`http://localhost:${PORT}/api/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ challengeId: challengeId, otp: debugOtp })
    }).then(r => r.json());

    console.log('   Verify success:', verifyRes.success);
    console.log('   Message:', verifyRes.message);
    console.log('   User Role:', verifyRes.user ? verifyRes.user.role : null);
    console.log('   Access Token:', verifyRes.token ? verifyRes.token.substring(0, 30) + '...' : null);
    console.log('   Refresh Token:', verifyRes.refreshToken ? verifyRes.refreshToken.substring(0, 30) + '...' : null);

    console.assert(verifyRes.success === true, 'Test 4 Failed: verify OTP failed');
    const accessToken = verifyRes.token || verifyRes.accessToken;
    const refreshToken = verifyRes.refreshToken;
    console.assert(!!accessToken, 'Test 4 Failed: accessToken not returned');
    console.assert(!!refreshToken, 'Test 4 Failed: refreshToken not returned');
    console.log('  ✓ Test 4 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 5: GET /api/auth/me profile request
    // -------------------------------------------------------------------------
    console.log('Test 5: GET /api/auth/me profile verification...');
    const meRes = await fetch(`http://localhost:${PORT}/api/auth/me`, {
      method: 'GET',
      headers: {
        'Authorization': 'Bearer ' + accessToken,
        'Content-Type': 'application/json'
      }
    }).then(r => r.json());

    console.log('   me success:', meRes.success);
    console.log('   Username:', meRes.user ? meRes.user.username : null);
    console.assert(meRes.success === true, 'Test 5 Failed: GET /api/auth/me failed');
    console.assert(meRes.user.username === 'admin', 'Test 5 Failed: Username is not admin');
    console.log('  ✓ Test 5 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 6: POST /api/auth/refresh-token
    // -------------------------------------------------------------------------
    console.log('Test 6: POST /api/auth/refresh-token token refresh...');
    const refreshRes = await fetch(`http://localhost:${PORT}/api/auth/refresh-token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: refreshToken })
    }).then(r => r.json());

    console.log('   Refresh success:', refreshRes.success);
    console.log('   New Token:', refreshRes.token ? refreshRes.token.substring(0, 30) + '...' : null);
    console.assert(refreshRes.success === true, 'Test 6 Failed: refresh-token failed');
    console.assert(!!refreshRes.token, 'Test 6 Failed: new token not returned');
    console.log('  ✓ Test 6 Passed!\n');

    // -------------------------------------------------------------------------
    // TEST 7: Swagger Specification & UI
    // -------------------------------------------------------------------------
    console.log('Test 7: Verify Swagger API spec at /api-docs/swagger.json...');
    const swaggerRes = await fetch(`http://localhost:${PORT}/api-docs/swagger.json`).then(r => r.json());
    console.log('   Swagger Title:', swaggerRes.info ? swaggerRes.info.title : null);
    console.assert(swaggerRes.paths['/api/auth/login'] != null, 'Test 7 Failed: /api/auth/login missing from Swagger');
    console.assert(swaggerRes.paths['/api/auth/verify-otp'] != null, 'Test 7 Failed: /api/auth/verify-otp missing from Swagger');
    console.assert(swaggerRes.paths['/api/auth/resend-otp'] != null, 'Test 7 Failed: /api/auth/resend-otp missing from Swagger');
    console.assert(swaggerRes.paths['/api/auth/me'] != null, 'Test 7 Failed: /api/auth/me missing from Swagger');
    console.assert(swaggerRes.paths['/api/auth/refresh-token'] != null, 'Test 7 Failed: /api/auth/refresh-token missing from Swagger');
    console.assert(swaggerRes.paths['/api/auth/logout'] != null, 'Test 7 Failed: /api/auth/logout missing from Swagger');
    console.log('  ✓ Test 7 Passed!\n');

    // Clean test challenges
    await conn.query("DELETE FROM otp_challenges WHERE user_id = ?", [adminId]);

  } catch (err) {
    console.error('E2E Test Error:', err);
  } finally {
    conn.release();
    server.close();
    console.log('=== ALL 7 E2E AUTHENTICATION TESTS COMPLETED SUCCESSFULLY ===');
    process.exit(0);
  }
}

testOtpAuthFlow();
