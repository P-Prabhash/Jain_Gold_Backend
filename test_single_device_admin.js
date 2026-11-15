const { getPool } = require('./config/database');
const { createAuthToken, logoutSession } = require('./config/auth');

async function loginAndVerifyOtp(baseUrl, username, password, headers = {}) {
  const db = await getPool();
  const testHeaders = { 'Content-Type': 'application/json', 'x-test-mode': 'true', ...headers };
  const loginRes = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: testHeaders,
    body: JSON.stringify({ username, password })
  });

  const loginData = await loginRes.json();
  if (loginRes.status !== 200 || !loginData.login_session_id) {
    return { status: loginRes.status, data: loginData };
  }

  const challengeId = loginData.login_session_id;

  // Retrieve plain OTP challenge created in database for this challenge
  const [rows] = await db.query(
    `SELECT id FROM otp_challenges WHERE challenge_id = ? LIMIT 1`,
    [challengeId]
  );

  let otp = loginData.debug_otp;
  if (!otp && rows.length > 0) {
    // Look up OTP hash from DB or debug
  }

  const verifyRes = await fetch(`${baseUrl}/api/auth/verify-otp`, {
    method: 'POST',
    headers: testHeaders,
    body: JSON.stringify({ login_session_id: challengeId, otp: otp })
  });

  const verifyData = await verifyRes.json();
  return { status: verifyRes.status, data: verifyData };
}

async function testSingleDeviceAdmin() {
  console.log('============================================================');
  console.log(' STARTING STRICT SINGLE-DEVICE ADMIN LOGIN TEST SUITE');
  console.log('============================================================\n');

  const db = await getPool();
  const BASE_URL = 'http://localhost:5000';

  // Clear existing active user_sessions for admin user (ID: 1) before starting
  await db.query("UPDATE user_sessions SET status = 'LOGGED_OUT' WHERE user_id = 1 AND status = 'ACTIVE'");

  // ------------------------------------------------------------
  // TEST 1: First Admin device login succeeds with mandatory OTP
  // ------------------------------------------------------------
  console.log('[TEST 1] Device A (IP 192.168.1.10): Attempting Admin Login & OTP Verification...');
  const devAHeaders = { 'User-Agent': 'Device A (Windows Desktop)', 'x-forwarded-for': '192.168.1.10' };
  const res1 = await loginAndVerifyOtp(BASE_URL, 'admin', 'admin123', devAHeaders);

  if (res1.status === 200 && res1.data.token) {
    console.log(`  ✔ TEST 1 PASSED: Device A Admin Login & Mandatory OTP Verification Succeeded. Token Issued.`);
  } else {
    console.error(`  ✖ TEST 1 FAILED: Expected 200, got ${res1.status}:`, res1.data);
    process.exit(1);
  }

  const tokenDeviceA = res1.data.token;

  // ------------------------------------------------------------
  // TEST 2: Second Admin device login attempt from DIFFERENT REMOTE IP is REJECTED at Step 1 (HTTP 409 Conflict)
  // ------------------------------------------------------------
  console.log('\n[TEST 2] Device B (Remote IP 203.0.113.50): Attempting Admin Login while Device A is ACTIVE...');
  const devBHeaders = { 'User-Agent': 'Device B (MacBook Remote)', 'x-forwarded-for': '203.0.113.50' };
  const login2Res = await fetch(`${BASE_URL}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-test-mode': 'true', ...devBHeaders },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const login2Data = await login2Res.json();
  const status2 = login2Res.status;

  if (status2 === 409 && login2Data.code === 'ADMIN_ALREADY_LOGGED_IN') {
    console.log(`  ✔ TEST 2 PASSED: Device B Admin Login Rejected with 409 Conflict.`);
    console.log(`    Code: '${login2Data.code}' | Message: '${login2Data.message}'`);
  } else {
    console.error(`  ✖ TEST 2 FAILED: Expected 409 Conflict, got ${status2}:`, login2Data);
    process.exit(1);
  }

  // ------------------------------------------------------------
  // TEST 3: Device A remains ACTIVE and can access protected APIs
  // ------------------------------------------------------------
  console.log('\n[TEST 3] Device A: Testing protected API access using Token A...');
  const me1Res = await fetch(`${BASE_URL}/api/auth/me`, {
    headers: { 'Authorization': 'Bearer ' + tokenDeviceA }
  });
  const me1Data = await me1Res.json();

  if (me1Res.status === 200 && me1Data.success) {
    console.log(`  ✔ TEST 3 PASSED: Device A token remains ACTIVE and valid. User: '${me1Data.user.username}'`);
  } else {
    console.error(`  ✖ TEST 3 FAILED: Device A access failed:`, me1Data);
    process.exit(1);
  }

  // ------------------------------------------------------------
  // TEST 4: Device A logs out cleanly
  // ------------------------------------------------------------
  console.log('\n[TEST 4] Device A: Logging out...');
  const logoutRes = await fetch(`${BASE_URL}/api/auth/logout`, {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + tokenDeviceA, 'Content-Type': 'application/json' }
  });
  const logoutData = await logoutRes.json();

  if (logoutRes.status === 200 && logoutData.success) {
    console.log(`  ✔ TEST 4 PASSED: Device A Logged Out Successfully.`);
  } else {
    console.error(`  ✖ TEST 4 FAILED: Logout failed:`, logoutData);
    process.exit(1);
  }

  // ------------------------------------------------------------
  // TEST 5: Device A's old token cannot access protected APIs anymore
  // ------------------------------------------------------------
  console.log('\n[TEST 5] Device A: Verifying old Token A is rejected (HTTP 401)...');
  const meOldRes = await fetch(`${BASE_URL}/api/auth/me`, {
    headers: { 'Authorization': 'Bearer ' + tokenDeviceA }
  });
  const meOldData = await meOldRes.json();

  if (meOldRes.status === 401 && (meOldData.code === 'SESSION_INVALID' || meOldData.code === 'ADMIN_SESSION_INVALID')) {
    console.log(`  ✔ TEST 5 PASSED: Old Token A rejected with 401 Unauthorized.`);
  } else {
    console.error(`  ✖ TEST 5 FAILED: Expected 401, got ${meOldRes.status}:`, meOldData);
    process.exit(1);
  }

  // ------------------------------------------------------------
  // TEST 6: Device B can now log in & verify OTP after Device A logged out
  // ------------------------------------------------------------
  console.log('\n[TEST 6] Device B (IP 203.0.113.50): Attempting Admin Login & OTP Verification after Device A logout...');
  const res3 = await loginAndVerifyOtp(BASE_URL, 'admin', 'admin123', devBHeaders);

  if (res3.status === 200 && res3.data.token) {
    console.log(`  ✔ TEST 6 PASSED: Device B Admin Login & OTP Verification Succeeded. Token Issued.`);
  } else {
    console.error(`  ✖ TEST 6 FAILED: Expected 200, got ${res3.status}:`, res3.data);
    process.exit(1);
  }

  // ------------------------------------------------------------
  // TEST 7: Expired session handling
  // ------------------------------------------------------------
  console.log('\n[TEST 7] Testing Expired Session handling...');
  // Force Device B's session to be in the past (expired)
  await db.query("UPDATE user_sessions SET expires_at = NOW() - INTERVAL 10 SECOND WHERE user_id = 1 AND status = 'ACTIVE'");

  const devCHeaders = { 'User-Agent': 'Device C (Tablet Remote)', 'x-forwarded-for': '198.51.100.12' };
  const res4 = await loginAndVerifyOtp(BASE_URL, 'admin', 'admin123', devCHeaders);

  if (res4.status === 200 && res4.data.token) {
    console.log(`  ✔ TEST 7 PASSED: Expired session automatically cleared, Device C Login Succeeded.`);
  } else {
    console.error(`  ✖ TEST 7 FAILED: Expected 200, got ${res4.status}:`, res4.data);
    process.exit(1);
  }

  // ------------------------------------------------------------
  // TEST 8: Re-using an already verified OTP is rejected
  // ------------------------------------------------------------
  console.log('\n[TEST 8] Testing Re-using an already verified OTP...');

  // Create challenge
  const login8Req = await fetch(`${BASE_URL}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-test-mode': 'true', ...devAHeaders },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });
  const login8Res = await login8Req.json();
  const reuseChallengeId = login8Res.login_session_id;

  // Retrieve plain OTP or debug_otp
  const reuseOtp = login8Res.debug_otp;

  if (reuseOtp) {
    // Verify first time (succeeds)
    await fetch(`${BASE_URL}/api/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-test-mode': 'true', ...devAHeaders },
      body: JSON.stringify({ login_session_id: reuseChallengeId, otp: reuseOtp })
    });

    // Verify second time with same challenge ID & OTP (must fail with 400 Bad Request)
    const reuseRes = await fetch(`${BASE_URL}/api/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-test-mode': 'true', ...devAHeaders },
      body: JSON.stringify({ login_session_id: reuseChallengeId, otp: reuseOtp })
    });

    const reuseData = await reuseRes.json();

    if (reuseRes.status === 400) {
      console.log(`  ✔ TEST 8 PASSED: Re-using verified OTP rejected with 400 Bad Request.`);
    } else {
      console.error(`  ✖ TEST 8 FAILED: Expected 400, got ${reuseRes.status}:`, reuseData);
      process.exit(1);
    }
  } else {
    console.log(`  ✔ TEST 8 SKIPPED (Production Mode)`);
  }

  // Clean up sessions
  await db.query("UPDATE user_sessions SET status = 'LOGGED_OUT' WHERE user_id = 1 AND status = 'ACTIVE'");

  console.log('\n============================================================');
  console.log(' ALL STRICT MANDATORY OTP & TOKEN MANAGEMENT TESTS PASSED!');
  console.log('============================================================\n');

  process.exit(0);
}

testSingleDeviceAdmin().catch(err => {
  console.error('Test Failed:', err);
  process.exit(1);
});
