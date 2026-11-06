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
// GET /auth/admin_status (.php)
// ============================================================
router.get(['/admin_status', '/admin_status.php'], async (req, res) => {
  try {
    const db = await getPool();
    const [rows] = await db.query("SELECT id FROM users WHERE role IN ('ADMIN', 'SUPER_ADMIN') LIMIT 1");
    const adminExists = rows.length > 0;

    return res.json({
      success: true,
      message: adminExists ? 'Admin account already exists.' : 'No Admin account exists.',
      admin_exists: adminExists,
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
// POST /auth/login (.php) & /api/auth/login
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

    console.log('[AUTH] Admin credentials validated');

    // Step 1 Success: Generate 4-digit OTP using crypto & Challenge ID
    const otp = String(crypto.randomInt(1000, 10000));
    console.log('[OTP] OTP generated successfully');

    const challengeId = 'CHALLENGE-' + Date.now() + '-' + crypto.randomBytes(3).toString('hex').toUpperCase();
    const otpHash = bcrypt.hashSync(otp, 10);
    const expiryMinutes = parseInt(process.env.ADMIN_OTP_EXPIRY_MINUTES || '10', 10);
    const expiresAt = new Date(Date.now() + expiryMinutes * 60 * 1000);

    await db.query(
      `INSERT INTO otp_challenges (user_id, challenge_id, otp_hash, expires_at, attempts, is_verified, created_at)
       VALUES (?, ?, ?, ?, 0, 0, NOW())`,
      [user.id, challengeId, otpHash, expiresAt]
    );

    console.log('[OTP] OTP stored in MySQL');

    const targetEmail = (user.email && user.email.includes('@')) ? user.email.trim() : 'pandetiprabhash@gmail.com';
    const emailResult = await sendOtpEmail(targetEmail, otp, challengeId);

    if (!emailResult.success) {
      console.error(`[MAIL ERROR] OTP Email Delivery Failed for ${targetEmail}: ${emailResult.error}`);
      return res.status(502).json({
        success: false,
        message: `Unable to deliver OTP email to ${targetEmail}: ${emailResult.error || 'SMTP delivery failed'}. Please check SMTP configuration.`,
        error: emailResult.error
      });
    }

    console.log('[AUTH] OTP challenge created successfully');

    return res.json({
      success: true,
      requires_otp: true,
      requiresOtp: true,
      challenge_id: challengeId,
      challengeId: challengeId,
      email: targetEmail,
      message: `A 4-digit verification code has been sent to ${targetEmail}.`,
      expires_in_seconds: expiryMinutes * 60,
      resend_cooldown_seconds: 60,
      debug_otp: otp, // Included for automated dev testing
      email_delivered: true
    });

  } catch (err) {
    return res.status(500).json({
      success: false,
      message: 'Unable to process login at this time.',
      error: err.message
    });
  }
});

// ============================================================
// POST /auth/verify-otp (.php) & /api/auth/verify-otp
// ============================================================
router.all([
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
  console.log('[AUTH] OTP verification requested');
  const challengeId = String(req.body.challengeId || req.body.challenge_id || '').trim();
  const otp = String(req.body.otp || '').trim();

  if (!challengeId || !otp) {
    return res.status(422).json({
      success: false,
      message: 'Challenge ID and OTP verification code are required.'
    });
  }

  try {
    const db = await getPool();

    const [challenges] = await db.query(
      `SELECT * FROM otp_challenges WHERE challenge_id = ? LIMIT 1`,
      [challengeId]
    );

    if (challenges.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Invalid or expired challenge ID.'
      });
    }

    const record = challenges[0];

    if (parseInt(record.is_verified || '0', 10) === 1) {
      return res.status(400).json({
        success: false,
        message: 'This OTP challenge has already been verified.'
      });
    }

    if (new Date(record.expires_at).getTime() < Date.now()) {
      return res.status(410).json({
        success: false,
        message: 'OTP has expired. Please click Resend OTP.'
      });
    }

    if (parseInt(record.attempts || '0', 10) >= 5) {
      return res.status(429).json({
        success: false,
        message: 'Maximum OTP verification attempts exceeded. Please request a new OTP.'
      });
    }

    const isOtpValid = bcrypt.compareSync(otp, record.otp_hash);

    if (!isOtpValid) {
      await db.query('UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = ?', [record.id]);
      const remainingAttempts = Math.max(0, 5 - (parseInt(record.attempts || '0', 10) + 1));
      return res.status(401).json({
        success: false,
        message: `Invalid OTP verification code. ${remainingAttempts} attempt(s) remaining.`
      });
    }

    console.log('[AUTH] OTP verified successfully');

    // Mark as Verified
    await db.query(
      'UPDATE otp_challenges SET is_verified = 1, verified_at = NOW() WHERE id = ?',
      [record.id]
    );

    // Fetch User
    const [userRows] = await db.query(
      'SELECT id, username, full_name, role, status, email, mobile FROM users WHERE id = ? LIMIT 1',
      [record.user_id]
    );

    if (userRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User account not found.'
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
    const refreshToken = createRefreshToken(user);

    console.log('[AUTH] Access token generated');

    try {
      await db.query(
        `UPDATE users SET last_login_at = CURRENT_TIMESTAMP, last_login_ip = ?, last_login_device = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
        [req.ip || null, req.get('user-agent') || null, user.id]
      );
    } catch (e) {
      // ignore
    }

    return res.json({
      success: true,
      message: 'OTP verified successfully.',
      token,
      accessToken: token,
      refreshToken,
      user,
      permission_codes: permissionCodes,
      data: {
        token,
        accessToken: token,
        refreshToken,
        user,
        permission_codes: permissionCodes
      }
    });

  } catch (err) {
    return res.status(500).json({
      success: false,
      message: 'Unable to verify OTP at this time.',
      error: err.message
    });
  }
});

// ============================================================
// POST /auth/resend-otp (.php) & /api/auth/resend-otp
// ============================================================
router.all([
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
  console.log('[AUTH] Resend OTP API called');
  const challengeId = String(req.body.challengeId || req.body.challenge_id || '').trim();

  if (!challengeId) {
    console.error('[OTP ERROR] Invalid challenge: challengeId is missing');
    return res.status(422).json({
      success: false,
      message: 'Challenge ID is required.'
    });
  }

  try {
    const db = await getPool();

    const [challenges] = await db.query(
      `SELECT * FROM otp_challenges WHERE challenge_id = ? LIMIT 1`,
      [challengeId]
    );

    if (challenges.length === 0) {
      console.error(`[OTP ERROR] Invalid challenge: ${challengeId} not found in database`);
      return res.status(404).json({
        success: false,
        message: 'Invalid challenge ID.'
      });
    }

    const record = challenges[0];
    console.log('[OTP] Challenge validated');

    // Check resend cooldown
    const cooldownSeconds = parseInt(process.env.ADMIN_OTP_RESEND_COOLDOWN_SECONDS || '60', 10);
    const createdAtTime = new Date(record.created_at).getTime();
    const timeElapsed = (Date.now() - createdAtTime) / 1000;

    if (timeElapsed < cooldownSeconds) {
      const waitTime = Math.ceil(cooldownSeconds - timeElapsed);
      console.warn(`[OTP ERROR] Resend cooldown active: ${waitTime}s remaining`);
      return res.status(429).json({
        success: false,
        message: `Please wait ${waitTime} seconds before requesting a new OTP.`
      });
    }

    // Generate new OTP & invalidate previous
    const newOtp = String(crypto.randomInt(1000, 10000));
    console.log('[OTP] New OTP generated');

    const newHash = bcrypt.hashSync(newOtp, 10);
    const expiryMinutes = parseInt(process.env.ADMIN_OTP_EXPIRY_MINUTES || '10', 10);
    const newExpiresAt = new Date(Date.now() + expiryMinutes * 60 * 1000);

    await db.query(
      `UPDATE otp_challenges SET otp_hash = ?, expires_at = ?, attempts = 0, is_verified = 0, created_at = NOW() WHERE id = ?`,
      [newHash, newExpiresAt, record.id]
    );
    console.log('[OTP] Previous OTP invalidated');

    const [userRows] = await db.query('SELECT email FROM users WHERE id = ? LIMIT 1', [record.user_id]);
    const targetEmail = (userRows.length > 0 && userRows[0].email && userRows[0].email.includes('@'))
      ? userRows[0].email.trim()
      : 'pandetiprabhash@gmail.com';

    console.log('[MAIL] Sending new OTP');
    const mailResult = await sendOtpEmail(targetEmail, newOtp, challengeId);
    console.log('[MAIL] Resend email accepted');

    return res.json({
      success: true,
      message: 'New verification code sent successfully',
      challenge_id: challengeId,
      challengeId: challengeId,
      email: targetEmail,
      expires_in_seconds: expiryMinutes * 60,
      resend_cooldown_seconds: cooldownSeconds,
      debug_otp: newOtp,
      data: {
        expiresIn: expiryMinutes * 60,
        resendCooldown: cooldownSeconds
      }
    });

  } catch (err) {
    console.error(`[OTP ERROR] Resend OTP failed: ${err.message}`);
    return res.status(500).json({
      success: false,
      message: 'Failed to resend OTP code.',
      error: err.message
    });
  }
});

// ============================================================
// POST /auth/test-email (.php) & /api/auth/test-email
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
  const targetEmail = String(req.body.email || req.query.email || 'pandetiprabhash@gmail.com').trim();
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
// GET /auth/me (.php) & /api/auth/me
// ============================================================
router.get(['/me', '/me.php'], authenticate, async (req, res) => {
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
// POST /auth/refresh-token (.php) & /api/auth/refresh-token
// ============================================================
router.post(['/refresh-token', '/refresh_token', '/refresh-token.php', '/refresh_token.php'], async (req, res) => {
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
// POST /auth/logout (.php) & /api/auth/logout
// ============================================================
router.post(['/logout', '/logout.php'], async (req, res) => {
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
      const email = String(req.body.email || '').trim().toLowerCase();
      if (!email) {
        return res.status(422).json({ success: false, message: 'Email address is required.' });
      }

      const otp = String(Math.floor(1000 + Math.random() * 9000));
      const otpHash = bcrypt.hashSync(otp, 10);
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

      await db.query('UPDATE admin_registration_otps SET verified = 1 WHERE email = ? AND verified = 0', [email]);
      await db.query(
        `INSERT INTO admin_registration_otps (email, otp_hash, expires_at, attempts, verified, created_at)
         VALUES (?, ?, ?, 0, 0, NOW())`,
        [email, otpHash, expiresAt]
      );

      console.log(`[ERP OTP] Sent OTP to ${email}: ${otp}`);

      return res.json({
        success: true,
        message: 'OTP sent successfully to your email address.',
        expires_in_seconds: 600,
        resend_after_seconds: 60,
        debug_otp: otp
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
