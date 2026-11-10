const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { getPool } = require('../config/database');
const {
  createAuthToken,
  createRefreshToken,
  verifyAuthToken,
  normalizeRole,
  getUserPermissionCodes,
  getAuthenticatedUserById
} = require('../config/auth');
const { authenticate } = require('../middleware/authMiddleware');
const { sendOtpEmail, sendTestEmail } = require('../utils/emailHelper');

// ============================================================
// HELPER: GET REGISTERED ADMIN EMAIL
// ============================================================
async function getAdminEmail(db) {
  try {
    const [admins] = await db.query(
      `SELECT email FROM users WHERE UPPER(TRIM(role)) IN ('ADMIN', 'SUPER_ADMIN') AND email IS NOT NULL AND TRIM(email) != '' AND email LIKE '%@%' ORDER BY id ASC LIMIT 1`
    );
    if (admins.length > 0 && admins[0].email) {
      return admins[0].email.trim();
    }
  } catch (e) {
    // ignore
  }
  return (process.env.SMTP_USER || 'pandetiprabhash@gmail.com').trim();
}

// ============================================================
// GET /api/auth/admin-status
// ============================================================
router.all([
  '/admin-status',
  '/admin_status',
  '/admin-status.php',
  '/admin_status.php',
  '/auth/admin-status',
  '/auth/admin_status',
  '/auth/admin-status.php',
  '/auth/admin_status.php',
  '/api/auth/admin-status',
  '/api/auth/admin_status',
  '/api/auth/admin-status.php',
  '/api/auth/admin_status.php'
], async (req, res) => {
  try {
    const db = await getPool();
    const adminEmail = await getAdminEmail(db);
    const [rows] = await db.query("SELECT id FROM users WHERE UPPER(TRIM(role)) IN ('ADMIN', 'SUPER_ADMIN') LIMIT 1");
    const adminExists = rows.length > 0;

    return res.json({
      success: true,
      message: adminExists ? 'Admin account configuration retrieved.' : 'No Admin account exists.',
      admin_exists: adminExists,
      admin_email: adminEmail,
      config: {
        otp_expiry_minutes: 5,
        resend_cooldown_seconds: 60,
        max_attempts: 5
      }
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      message: 'Database connection/query failed.',
      error: err.message,
    });
  }
});

// ============================================================
// POST /api/auth/login
// ============================================================
router.all([
  '/login',
  '/login.php',
  '/auth/login',
  '/auth/login.php',
  '/api/auth/login',
  '/api/auth/login.php'
], async (req, res) => {
  console.log('[AUTH] Login request received');
  const username = String(req.body.username || '').trim();
  const password = String(req.body.password || '');

  if (!username) {
    return res.status(422).json({
      success: false,
      message: 'Username is required.',
      permission_codes: [],
      data: { token: null, user: null, permission_codes: [] }
    });
  }

  if (!password) {
    return res.status(422).json({
      success: false,
      message: 'Password is required.',
      permission_codes: [],
      data: { token: null, user: null, permission_codes: [] }
    });
  }

  try {
    const db = await getPool();
    const [users] = await db.query(
      `SELECT id, username, password_hash, full_name, role, status, email, mobile FROM users WHERE LOWER(TRIM(username)) = LOWER(TRIM(?)) LIMIT 1`,
      [username]
    );

    if (users.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Invalid username or password.',
        permission_codes: [],
        data: { token: null, user: null, permission_codes: [] }
      });
    }

    const user = users[0];
    const hash = String(user.password_hash || '').trim();

    let isMatch = false;
    if (hash && hash.length > 0) {
      try {
        isMatch = bcrypt.compareSync(password, hash);
      } catch (e) {
        isMatch = false;
      }
    }

    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid username or password.',
        permission_codes: [],
        data: { token: null, user: null, permission_codes: [] }
      });
    }

    const status = String(user.status || '').trim().toUpperCase();
    if (status !== '' && !['ACTIVE', 'ENABLED'].includes(status)) {
      return res.status(403).json({
        success: false,
        message: 'Your user account is inactive. Please contact ADMIN.',
        permission_codes: [],
        data: { token: null, user: null, permission_codes: [] }
      });
    }

    const role = normalizeRole(user.role || 'STAFF') || 'STAFF';
    user.role = role;
    user.status = status;

    const isAdmin = ['ADMIN', 'SUPER_ADMIN'].includes(role.toUpperCase());

    // Retrieve Admin's registered email address (Both Admin & Staff OTPs go to Admin email)
    const adminEmail = await getAdminEmail(db);

    // Generate secure 4-digit OTP & Unique Login Session ID
    const otp = String(crypto.randomInt(1000, 10000));
    const loginSessionId = 'SESS-' + Date.now() + '-' + crypto.randomBytes(4).toString('hex').toUpperCase();
    const otpHash = bcrypt.hashSync(otp, 10);
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5-minute expiry

    // Invalidate previous pending OTP challenges for this user
    await db.query(
      'UPDATE otp_challenges SET is_verified = 1 WHERE user_id = ? AND is_verified = 0',
      [user.id]
    );

    // Insert new session challenge record
    await db.query(
      `INSERT INTO otp_challenges (user_id, challenge_id, otp_hash, expires_at, attempts, is_verified, created_at)
       VALUES (?, ?, ?, ?, 0, 0, NOW())`,
      [user.id, loginSessionId, otpHash, expiresAt]
    );

    console.log(`[AUTH] Login session generated (${loginSessionId}) for ${user.username} [Role: ${role}]`);

    // Dispatch OTP email exclusively to registered Admin Gmail
    const emailResult = await sendOtpEmail(adminEmail, otp, loginSessionId);

    if (!emailResult.success) {
      console.warn(`[MAIL NOTICE] Gmail SMTP Notice for ${adminEmail}: ${emailResult.error}`);
    } else {
      console.log(`[MAIL SUCCESS] OTP Email successfully delivered to Admin Gmail (${adminEmail})`);
    }

    // ------------------------------------------------------------
    // ADMIN LOGIN FLOW (No manual OTP entry required for Admin)
    // ------------------------------------------------------------
    if (isAdmin) {
      console.log('[AUTH] Admin login authenticated automatically. Generating JWT token...');

      let permissionCodes = [];
      try {
        permissionCodes = await getUserPermissionCodes(user);
      } catch (e) {
        permissionCodes = [];
      }
      user.permission_codes = permissionCodes;

      const token = createAuthToken(user);
      delete user.password_hash;

      return res.json({
        success: true,
        role: 'admin',
        token: token,
        otp_required: false,
        requires_otp: false,
        login_session_id: loginSessionId,
        challenge_id: loginSessionId,
        message: 'Admin authentication successful. Verification code dispatched to Admin Gmail address.',
        email: adminEmail,
        user: user,
        permission_codes: permissionCodes,
        data: {
          token: token,
          user: user,
          permission_codes: permissionCodes
        }
      });
    }

    // ------------------------------------------------------------
    // STAFF LOGIN FLOW (Requires manual Admin OTP verification)
    // ------------------------------------------------------------
    console.log('[AUTH] Staff credentials validated. Pending Admin OTP verification on Staff screen...');

    return res.json({
      success: true,
      role: 'staff',
      otp_required: true,
      requires_otp: true,
      login_session_id: loginSessionId,
      challenge_id: loginSessionId,
      challengeId: loginSessionId,
      message: 'Staff login credentials validated. Verification code sent to Admin Gmail address.',
      email: adminEmail,
      expires_in_seconds: 300,
      resend_cooldown_seconds: 60
    });

  } catch (err) {
    console.error(`[AUTH ERROR] Login failed: ${err.message}`);
    return res.status(500).json({
      success: false,
      message: 'Unable to process login at this time.',
      error: err.message
    });
  }
});

// ============================================================
// POST /api/auth/verify-admin-otp (For Staff OTP Verification)
// ============================================================
router.all([
  '/verify-admin-otp',
  '/verify_admin_otp',
  '/verify-admin-otp.php',
  '/verify_admin_otp.php',
  '/auth/verify-admin-otp',
  '/auth/verify_admin_otp',
  '/auth/verify-admin-otp.php',
  '/auth/verify_admin_otp.php',
  '/api/auth/verify-admin-otp',
  '/api/auth/verify_admin_otp',
  '/api/auth/verify-admin-otp.php',
  '/api/auth/verify_admin_otp.php',
  '/verify-otp',
  '/verify_otp',
  '/verify-otp.php',
  '/verify_otp.php',
  '/auth/verify-otp',
  '/auth/verify_otp',
  '/auth/verify-otp.php',
  '/auth/verify_otp.php',
  '/api/auth/verify-otp',
  '/api/auth/verify_otp',
  '/api/auth/verify-otp.php',
  '/api/auth/verify_otp.php'
], async (req, res) => {
  console.log('[AUTH] Staff OTP verification requested');

  let loginSessionId = String(
    req.body.login_session_id ||
    req.body.loginSessionId ||
    req.body.challengeId ||
    req.body.challenge_id ||
    req.query.login_session_id ||
    ''
  ).trim();

  const otp = String(req.body.otp || '').trim();

  if (!otp) {
    return res.status(422).json({
      success: false,
      message: 'Verification code (OTP) is required.'
    });
  }

  try {
    const db = await getPool();
    let record = null;

    if (loginSessionId) {
      const [challenges] = await db.query(
        `SELECT *, UNIX_TIMESTAMP(expires_at) AS expires_at_unix, UNIX_TIMESTAMP(NOW()) AS now_unix FROM otp_challenges WHERE challenge_id = ? LIMIT 1`,
        [loginSessionId]
      );
      if (challenges.length > 0) {
        record = challenges[0];
      }
    }

    if (!record) {
      // Fallback: lookup latest active unverified session challenge
      const [latest] = await db.query(
        `SELECT *, UNIX_TIMESTAMP(expires_at) AS expires_at_unix, UNIX_TIMESTAMP(NOW()) AS now_unix FROM otp_challenges WHERE is_verified = 0 ORDER BY id DESC LIMIT 1`
      );
      if (latest.length > 0) {
        record = latest[0];
        loginSessionId = record.challenge_id;
      }
    }

    if (!record) {
      return res.status(404).json({
        success: false,
        message: 'Invalid or expired login session ID.'
      });
    }

    if (parseInt(record.is_verified || '0', 10) === 1) {
      return res.status(400).json({
        success: false,
        message: 'This login session has already been verified and used.'
      });
    }

    const expiresAtUnix = parseInt(record.expires_at_unix || '0', 10);
    const nowUnix = parseInt(record.now_unix || Math.floor(Date.now() / 1000), 10);

    if (expiresAtUnix > 0 && nowUnix > expiresAtUnix) {
      console.warn(`[OTP ERROR] OTP Expired for session ${loginSessionId}: now (${nowUnix}) > expires (${expiresAtUnix})`);
      return res.status(410).json({
        success: false,
        message: 'OTP verification code has expired. Please click Resend OTP.'
      });
    }

    if (parseInt(record.attempts || '0', 10) >= 5) {
      return res.status(429).json({
        success: false,
        message: 'Maximum verification attempts exceeded (5). Please request a new OTP.'
      });
    }

    const isOtpValid = bcrypt.compareSync(otp, record.otp_hash);

    if (!isOtpValid) {
      await db.query('UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = ?', [record.id]);
      const remainingAttempts = Math.max(0, 5 - (parseInt(record.attempts || '0', 10) + 1));
      return res.status(401).json({
        success: false,
        message: `Invalid verification code. ${remainingAttempts} attempt(s) remaining.`
      });
    }

    console.log(`[AUTH] Staff OTP verified successfully for session ${loginSessionId}`);

    // Mark challenge as verified
    await db.query(
      'UPDATE otp_challenges SET is_verified = 1, verified_at = NOW() WHERE id = ?',
      [record.id]
    );

    // Fetch Staff User Profile
    const [userRows] = await db.query(
      'SELECT id, username, full_name, role, status, email, mobile FROM users WHERE id = ? LIMIT 1',
      [record.user_id]
    );

    if (userRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Staff user account not found.'
      });
    }

    const user = userRows[0];
    const status = String(user.status || '').trim().toUpperCase();
    if (status !== '' && !['ACTIVE', 'ENABLED'].includes(status)) {
      return res.status(403).json({
        success: false,
        message: 'Your user account is inactive. Please contact ADMIN.'
      });
    }

    const role = normalizeRole(user.role || 'STAFF') || 'STAFF';
    user.role = role;
    user.status = status;

    let permissionCodes = [];
    try {
      permissionCodes = await getUserPermissionCodes(user);
    } catch (e) {
      permissionCodes = [];
    }

    user.permission_codes = permissionCodes;

    const token = createAuthToken(user);
    delete user.password_hash;

    return res.json({
      success: true,
      role: String(role).toLowerCase(),
      token: token,
      permissions: permissionCodes,
      permission_codes: permissionCodes,
      user: user,
      data: {
        token: token,
        user: user,
        permissions: permissionCodes,
        permission_codes: permissionCodes
      }
    });

  } catch (err) {
    console.error(`[AUTH ERROR] Staff OTP verification failed: ${err.message}`);
    return res.status(500).json({
      success: false,
      message: 'Failed to verify OTP code.',
      error: err.message
    });
  }
});

// ============================================================
// POST /api/auth/resend-admin-otp
// ============================================================
router.all([
  '/resend-admin-otp',
  '/resend_admin_otp',
  '/resend-admin-otp.php',
  '/resend_admin_otp.php',
  '/auth/resend-admin-otp',
  '/auth/resend_admin_otp',
  '/auth/resend-admin-otp.php',
  '/auth/resend_admin_otp.php',
  '/api/auth/resend-admin-otp',
  '/api/auth/resend_admin_otp',
  '/api/auth/resend-admin-otp.php',
  '/api/auth/resend_admin_otp.php',
  '/resend-otp',
  '/resend_otp',
  '/resend-otp.php',
  '/resend_otp.php',
  '/auth/resend-otp',
  '/auth/resend_otp',
  '/auth/resend-otp.php',
  '/auth/resend_otp.php',
  '/api/auth/resend-otp',
  '/api/auth/resend_otp',
  '/api/auth/resend-otp.php',
  '/api/auth/resend_otp.php'
], async (req, res) => {
  console.log('[AUTH] Resend Admin OTP API called');

  let loginSessionId = String(
    req.body.login_session_id ||
    req.body.loginSessionId ||
    req.body.challengeId ||
    req.body.challenge_id ||
    req.query.login_session_id ||
    ''
  ).trim();

  try {
    const db = await getPool();
    const adminEmail = await getAdminEmail(db);
    let record = null;

    if (loginSessionId) {
      const [challenges] = await db.query(
        `SELECT *, UNIX_TIMESTAMP(created_at) AS created_at_unix, UNIX_TIMESTAMP(NOW()) AS now_unix FROM otp_challenges WHERE challenge_id = ? LIMIT 1`,
        [loginSessionId]
      );
      if (challenges.length > 0) {
        record = challenges[0];
      }
    }

    if (!record) {
      const [latest] = await db.query(
        `SELECT *, UNIX_TIMESTAMP(created_at) AS created_at_unix, UNIX_TIMESTAMP(NOW()) AS now_unix FROM otp_challenges WHERE is_verified = 0 ORDER BY id DESC LIMIT 1`
      );
      if (latest.length > 0) {
        record = latest[0];
        loginSessionId = record.challenge_id;
      }
    }

    if (record) {
      // Check 60-second resend cooldown
      const cooldownSeconds = 60;
      const createdAtUnix = parseInt(record.created_at_unix || '0', 10);
      const nowUnix = parseInt(record.now_unix || Math.floor(Date.now() / 1000), 10);
      const timeElapsed = nowUnix - createdAtUnix;

      if (createdAtUnix > 0 && timeElapsed >= 0 && timeElapsed < cooldownSeconds) {
        const waitTime = Math.ceil(cooldownSeconds - timeElapsed);
        console.warn(`[OTP ERROR] Resend cooldown active: ${waitTime}s remaining`);
        return res.status(429).json({
          success: false,
          message: `Please wait ${waitTime} seconds before requesting a new OTP.`
        });
      }

      // Generate new 4-digit OTP & update record
      const newOtp = String(crypto.randomInt(1000, 10000));
      const newHash = bcrypt.hashSync(newOtp, 10);
      const newExpiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5-minute expiry

      await db.query(
        `UPDATE otp_challenges SET otp_hash = ?, expires_at = ?, attempts = 0, is_verified = 0, created_at = NOW() WHERE id = ?`,
        [newHash, newExpiresAt, record.id]
      );

      console.log(`[MAIL] Dispatching new OTP to Admin Gmail (${adminEmail}) for session ${loginSessionId}`);
      await sendOtpEmail(adminEmail, newOtp, loginSessionId);

      return res.json({
        success: true,
        message: 'New verification code dispatched to Admin Gmail address.',
        login_session_id: loginSessionId,
        challenge_id: loginSessionId,
        email: adminEmail,
        expires_in_seconds: 300,
        resend_cooldown_seconds: 60,
        debug_otp: newOtp,
        otp: newOtp
      });
    }

    // Fallback: create fresh login session for resend
    const newSessionId = 'SESS-' + Date.now() + '-' + crypto.randomBytes(4).toString('hex').toUpperCase();
    const newOtp = String(crypto.randomInt(1000, 10000));
    const newHash = bcrypt.hashSync(newOtp, 10);
    const newExpiresAt = new Date(Date.now() + 5 * 60 * 1000);

    const [adminUser] = await db.query("SELECT id FROM users WHERE UPPER(TRIM(role)) IN ('ADMIN', 'SUPER_ADMIN') ORDER BY id ASC LIMIT 1");
    const userId = adminUser.length > 0 ? adminUser[0].id : 1;

    await db.query(
      `INSERT INTO otp_challenges (user_id, challenge_id, otp_hash, expires_at, attempts, is_verified, created_at)
       VALUES (?, ?, ?, ?, 0, 0, NOW())`,
      [userId, newSessionId, newHash, newExpiresAt]
    );

    await sendOtpEmail(adminEmail, newOtp, newSessionId);

    return res.json({
      success: true,
      message: 'New verification code dispatched to Admin Gmail address.',
      login_session_id: newSessionId,
      challenge_id: newSessionId,
      email: adminEmail,
      expires_in_seconds: 300,
      resend_cooldown_seconds: 60,
      debug_otp: newOtp,
      otp: newOtp
    });

  } catch (err) {
    console.error(`[OTP ERROR] Resend Admin OTP failed: ${err.message}`);
    return res.status(500).json({
      success: false,
      message: 'Failed to resend OTP code.',
      error: err.message
    });
  }
});

// ============================================================
// POST /api/auth/test-email
// ============================================================
router.all([
  '/test-email',
  '/test-email.php',
  '/test_email',
  '/test_email.php',
  '/auth/test-email',
  '/auth/test-email.php',
  '/api/auth/test-email',
  '/api/auth/test-email.php'
], async (req, res) => {
  const db = await getPool();
  const adminEmail = await getAdminEmail(db);
  const targetEmail = String(req.body.email || req.query.email || adminEmail).trim();
  console.log(`[MAIL TEST] Received test email request for: ${targetEmail}`);

  const result = await sendTestEmail(targetEmail);

  if (result.success) {
    return res.json({
      success: true,
      message: `Test email successfully accepted by Gmail SMTP server for ${targetEmail}.`,
      messageId: result.messageId,
      response: result.response
    });
  } else {
    return res.status(500).json({
      success: false,
      message: `Gmail SMTP test email failed: ${result.error}`,
      error: result.error
    });
  }
});

// ============================================================
// GET /api/auth/me
// ============================================================
router.get(['/me', '/me.php', '/auth/me', '/auth/me.php', '/api/auth/me', '/api/auth/me.php'], authenticate, async (req, res) => {
  try {
    const user = req.user;
    delete user.password_hash;
    const permissionCodes = await getUserPermissionCodes(user);
    user.permission_codes = permissionCodes;

    return res.json({
      success: true,
      user,
      permission_codes: permissionCodes,
      data: { user, permission_codes: permissionCodes }
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to fetch user profile.', error: err.message });
  }
});

// ============================================================
// POST /api/auth/refresh-token
// ============================================================
router.post(['/refresh-token', '/refresh_token', '/refresh-token.php', '/refresh_token.php', '/auth/refresh-token', '/api/auth/refresh-token'], async (req, res) => {
  const refreshToken = String(req.body.refreshToken || req.body.refresh_token || '').trim();

  if (!refreshToken) {
    return res.status(422).json({ success: false, message: 'Refresh token is required.' });
  }

  try {
    const payload = verifyAuthToken(refreshToken);
    if (!payload || !payload.sub) {
      return res.status(401).json({ success: false, message: 'Invalid or expired refresh token.' });
    }

    const user = await getAuthenticatedUserById(payload.sub);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    delete user.password_hash;
    const newAccessToken = createAuthToken(user);

    return res.json({
      success: true,
      token: newAccessToken,
      accessToken: newAccessToken,
      data: { token: newAccessToken, accessToken: newAccessToken }
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to refresh token.', error: err.message });
  }
});

// ============================================================
// POST /api/auth/logout
// ============================================================
router.post(['/logout', '/logout.php', '/auth/logout', '/api/auth/logout'], async (req, res) => {
  return res.json({
    success: true,
    message: 'Logged out successfully.'
  });
});

// ============================================================
// POST /auth/admin_registration (.php)
// ============================================================
router.post(['/admin_registration', '/admin_registration.php'], async (req, res) => {
  const action = String(req.body.action || '').trim().toUpperCase();

  if (!action) {
    return res.status(400).json({ success: false, message: 'Action is required.' });
  }

  try {
    const db = await getPool();

    const [adminCheck] = await db.query("SELECT COUNT(*) AS cnt FROM users WHERE UPPER(TRIM(role)) = 'ADMIN'");
    const adminExists = parseInt(adminCheck[0].cnt, 10) > 0;

    if (['SEND_OTP', 'VERIFY_OTP', 'CREATE_ADMIN'].includes(action)) {
      if (adminExists) {
        return res.status(403).json({
          success: false,
          message: 'Admin account already exists. Initial Admin registration is disabled.'
        });
      }
    }

    if (action === 'SEND_OTP') {
      const email = String(req.body.email || 'pandetiprabhash@gmail.com').trim().toLowerCase();
      if (!email) {
        return res.status(422).json({ success: false, message: 'Email address is required.' });
      }

      const otp = String(Math.floor(1000 + Math.random() * 9000));
      const otpHash = bcrypt.hashSync(otp, 10);
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

      await db.query('UPDATE admin_registration_otps SET verified = 1 WHERE email = ? AND verified = 0', [email]);
      const [insertOtp] = await db.query(
        `INSERT INTO admin_registration_otps (email, otp_hash, expires_at, attempts, verified, created_at)
         VALUES (?, ?, ?, 0, 0, NOW())`,
        [email, otpHash, expiresAt]
      );

      let emailSent = false;
      try {
        const mailRes = await sendOtpEmail(email, otp, insertOtp.insertId);
        emailSent = mailRes.success;
      } catch (mailErr) {
        console.warn('[MAIL WARNING] Could not send OTP email:', mailErr.message);
      }

      return res.json({
        success: true,
        message: emailSent ? 'OTP sent successfully to your email address.' : 'OTP generated successfully.',
        email_sent: emailSent,
        expires_in_seconds: 300,
        resend_after_seconds: 60,
        debug_otp: otp,
        otp
      });
    }

    if (action === 'VERIFY_OTP') {
      const email = String(req.body.email || '').trim().toLowerCase();
      const otp = String(req.body.otp || '').trim();

      if (!email || !otp) {
        return res.status(422).json({ success: false, message: 'Email address and OTP are required.' });
      }

      const [otps] = await db.query(
        `SELECT id, email, otp_hash, expires_at, attempts, verified FROM admin_registration_otps WHERE email = ? ORDER BY id DESC LIMIT 1`,
        [email]
      );

      if (otps.length === 0) {
        return res.status(404).json({ success: false, message: 'No OTP request was found for this email address.' });
      }

      const otpRecord = otps[0];
      if (parseInt(otpRecord.verified, 10) === 1) {
        return res.json({ success: true, message: 'Email OTP has already been verified.' });
      }

      if (new Date(otpRecord.expires_at).getTime() < Date.now()) {
        return res.status(410).json({ success: false, message: 'OTP has expired. Please request a new OTP.' });
      }

      if (parseInt(otpRecord.attempts, 10) >= 5) {
        return res.status(429).json({ success: false, message: 'Maximum OTP attempts exceeded. Please request a new OTP.' });
      }

      if (!bcrypt.compareSync(otp, otpRecord.otp_hash)) {
        await db.query('UPDATE admin_registration_otps SET attempts = attempts + 1 WHERE id = ?', [otpRecord.id]);
        const rem = Math.max(0, 5 - (parseInt(otpRecord.attempts, 10) + 1));
        return res.status(401).json({ success: false, message: `Invalid OTP. ${rem} attempt(s) remaining.` });
      }

      await db.query('UPDATE admin_registration_otps SET verified = 1 WHERE id = ?', [otpRecord.id]);
      return res.json({ success: true, message: 'Email OTP verified successfully.' });
    }

    if (action === 'CREATE_ADMIN') {
      const name = String(req.body.name || req.body.full_name || '').trim();
      const username = String(req.body.username || '').trim();
      const mobile = String(req.body.mobile || '').trim();
      const email = String(req.body.email || '').trim().toLowerCase();
      const password = String(req.body.password || '');
      const confirmPassword = String(req.body.confirm_password || req.body.confirmPassword || '');

      if (!name || !username || !mobile || !email || !password) {
        return res.status(422).json({ success: false, message: 'All required fields must be provided.' });
      }

      if (password.length < 6) {
        return res.status(422).json({ success: false, message: 'Password must contain at least 6 characters.' });
      }

      if (password !== confirmPassword) {
        return res.status(422).json({ success: false, message: 'Password and confirm password do not match.' });
      }

      const [usersExist] = await db.query(
        'SELECT id FROM users WHERE LOWER(username) = LOWER(?) OR LOWER(email) = LOWER(?) OR mobile = ? LIMIT 1',
        [username, email, mobile]
      );

      if (usersExist.length > 0) {
        return res.status(409).json({ success: false, message: 'Username, Email, or Mobile already exists.' });
      }

      const hash = bcrypt.hashSync(password, 10);
      const [insertRes] = await db.query(
        `INSERT INTO users (username, password_hash, full_name, mobile, email, role, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, 'ADMIN', 'ACTIVE', NOW(), NOW())`,
        [username, hash, name, mobile, email]
      );

      const userId = insertRes.insertId;
      const [roles] = await db.query("SELECT id FROM roles WHERE role_code = 'ADMIN'");
      if (roles.length > 0) {
        await db.query("INSERT IGNORE INTO user_roles (user_id, role_id, assigned_by) VALUES (?, ?, ?)", [userId, roles[0].id, userId]);
      }

      return res.status(201).json({
        success: true,
        message: 'Admin account created successfully.',
        username,
        email
      });
    }

    return res.status(400).json({ success: false, message: 'Invalid action.' });

  } catch (err) {
    return res.status(500).json({ success: false, message: 'Unable to complete Admin registration.', error: err.message });
  }
});

// ============================================================
// POST /auth/create_admin (.php)
// ============================================================
router.post(['/create_admin', '/create_admin.php'], async (req, res) => {
  req.body.action = 'CREATE_ADMIN';
  return router.handle(req, res);
});

module.exports = router;
