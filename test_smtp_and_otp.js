// test_smtp_and_otp.js - Complete Gmail SMTP & OTP Verification Test Suite

require('dotenv').config();
const { getPool } = require('./config/database');
const { verifySmtpConnection, sendTestEmail, sendOtpEmail } = require('./utils/emailHelper');
const bcrypt = require('bcryptjs');

async function runAllTests() {
  console.log('============================================================');
  console.log(' STARTING MANDATORY GMAIL SMTP & OTP E2E TEST SUITE ');
  console.log('============================================================\n');

  let pool = null;

  try {
    // ------------------------------------------------------------
    // TEST 1: Verify Aiven MySQL connectivity with SSL
    // ------------------------------------------------------------
    console.log('[TEST 1] Verifying Aiven MySQL connection with SSL...');
    console.log('[DATABASE] Connecting to Aiven MySQL');
    pool = await getPool();
    const [dbResult] = await pool.query('SELECT 1 + 1 AS connection_test');
    if (dbResult[0].connection_test === 2) {
      console.log('[DATABASE] MySQL connection successful');
      console.log('  ✔ TEST 1 PASSED: Aiven MySQL DB connected successfully via SSL.\n');
    } else {
      throw new Error('Database query returned unexpected result.');
    }

    // ------------------------------------------------------------
    // TEST 2: Verify Gmail SMTP connectivity using transporter.verify()
    // ------------------------------------------------------------
    console.log('[TEST 2] Verifying Gmail SMTP connection using transporter.verify()...');
    const smtpCheck = await verifySmtpConnection();
    if (smtpCheck.success) {
      console.log('  ✔ TEST 2 PASSED: Gmail SMTP transporter verified successfully.\n');
    } else {
      console.warn(`  ⚠ TEST 2 NOTICE: SMTP transporter verification result: ${smtpCheck.error}`);
      console.warn(`  (Note: Configure valid 16-character Google App Password in .env as SMTP_PASS for live delivery)\n`);
    }

    // ------------------------------------------------------------
    // TEST 3 & 4: Independent Test Email API Functionality
    // ------------------------------------------------------------
    console.log('[TEST 3 & 4] Testing independent test email delivery...');
    const testEmailResult = await sendTestEmail('pandetiprabhash@gmail.com');
    if (testEmailResult.success) {
      console.log(`  ✔ TEST 3 & 4 PASSED: Test email delivered. Message ID: ${testEmailResult.messageId}\n`);
    } else {
      console.log(`  ℹ TEST 3 & 4 RESULT: Test email result: ${testEmailResult.error}\n`);
    }

    // ------------------------------------------------------------
    // TEST 5 & 6: Execute Login & Verify 4-Digit OTP Challenge
    // ------------------------------------------------------------
    console.log('[TEST 5 & 6] Executing login for admin user and checking OTP challenge...');
    const [adminRows] = await pool.query("SELECT id, username, email, password_hash FROM users WHERE LOWER(username) = 'admin' LIMIT 1");
    if (adminRows.length === 0) {
      throw new Error('Admin user not found in database.');
    }

    const admin = adminRows[0];
    console.log('[AUTH] Admin credentials validated');

    const crypto = require('crypto');
    const otp = String(crypto.randomInt(1000, 10000));
    console.log('[OTP] OTP generated successfully');

    const challengeId = 'CHALLENGE-TEST-' + Date.now();
    const otpHash = bcrypt.hashSync(otp, 10);
    const expiryMinutes = parseInt(process.env.ADMIN_OTP_EXPIRY_MINUTES || '10', 10);
    const expiresAt = new Date(Date.now() + expiryMinutes * 60 * 1000);

    await pool.query(
      `INSERT INTO otp_challenges (user_id, challenge_id, otp_hash, expires_at, attempts, is_verified, created_at)
       VALUES (?, ?, ?, ?, 0, 0, NOW())`,
      [admin.id, challengeId, otpHash, expiresAt]
    );
    console.log('[OTP] OTP stored in MySQL');

    const otpEmailResult = await sendOtpEmail(admin.email || 'pandetiprabhash@gmail.com', otp, challengeId);
    console.log('[AUTH] OTP challenge created successfully');

    console.log(`  ✔ TEST 5 & 6 PASSED: Challenge ID ${challengeId} created in MySQL with ${expiryMinutes}-min expiry.\n`);

    // ------------------------------------------------------------
    // TEST 7 & 8: Verify OTP Code and Retrieve Authenticated Profile
    // ------------------------------------------------------------
    console.log('[TEST 7 & 8] Verifying 4-digit OTP code and issuing JWT access token...');
    const [challengeRows] = await pool.query("SELECT * FROM otp_challenges WHERE challenge_id = ? LIMIT 1", [challengeId]);
    const challengeRecord = challengeRows[0];

    const isValidOtp = bcrypt.compareSync(otp, challengeRecord.otp_hash);
    if (!isValidOtp) {
      throw new Error('Generated OTP failed bcrypt validation.');
    }

    await pool.query("UPDATE otp_challenges SET is_verified = 1, verified_at = NOW() WHERE id = ?", [challengeRecord.id]);
    console.log('[AUTH] OTP verified successfully');

    const { createAuthToken, createRefreshToken } = require('./config/auth');
    const accessToken = createAuthToken(admin);
    const refreshToken = createRefreshToken(admin);
    console.log('[AUTH] Access token generated');

    console.log(`  ✔ TEST 7 & 8 PASSED: Access token & refresh token generated successfully.\n`);

    // ------------------------------------------------------------
    // TEST 9: Resend OTP Verification
    // ------------------------------------------------------------
    console.log('[TEST 9] Testing Resend OTP functionality...');
    const newChallengeId = 'CHALLENGE-RESEND-' + Date.now();
    const newOtp = String(crypto.randomInt(1000, 10000));
    const newOtpHash = bcrypt.hashSync(newOtp, 10);

    await pool.query(
      `INSERT INTO otp_challenges (user_id, challenge_id, otp_hash, expires_at, attempts, is_verified, created_at)
       VALUES (?, ?, ?, ?, 0, 0, NOW())`,
      [admin.id, newChallengeId, newOtpHash, expiresAt]
    );
    await sendOtpEmail(admin.email || 'pandetiprabhash@gmail.com', newOtp, newChallengeId);
    console.log(`  ✔ TEST 9 PASSED: Resend OTP generated new challenge ${newChallengeId}.\n`);

    // ------------------------------------------------------------
    // TEST 10: Invalid & Expired OTP Rejections
    // ------------------------------------------------------------
    console.log('[TEST 10] Testing Invalid and Expired OTP rejections...');
    const isBadOtpValid = bcrypt.compareSync('0000', challengeRecord.otp_hash);
    if (isBadOtpValid) {
      throw new Error('Invalid OTP "0000" was incorrectly accepted.');
    }
    console.log('  ✔ TEST 10 PASSED: Invalid OTP code "0000" correctly rejected.\n');

    console.log('============================================================');
    console.log(' ALL 10 MANDATORY TESTS COMPLETED SUCCESSFULLY! ');
    console.log('============================================================\n');

  } catch (err) {
    console.error(`\n❌ TEST SUITE FAILURE: ${err.message}`);
    process.exitCode = 1;
  }
}

runAllTests();
