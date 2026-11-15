const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { getPool } = require('./database');
require('dotenv').config();

const JWT_SECRET = process.env.JWT_SECRET || 'gold_pawn_erp_secure_auth_secret_2026_change_this';
const JWT_EXPIRES_IN = parseInt(process.env.JWT_EXPIRES_IN || '86400', 10);

function normalizeRole(role) {
  if (!role) return '';
  return String(role).trim().replace(/[- ]/g, '_').toUpperCase();
}

function hashToken(token) {
  return crypto.createHash('sha256').update(String(token)).digest('hex');
}

function isSameOrLocalIp(ip1, ip2) {
  if (!ip1 || !ip2) return true;
  const clean1 = String(ip1).trim().replace('::ffff:', '');
  const clean2 = String(ip2).trim().replace('::ffff:', '');

  if (clean1 === clean2) return true;

  const localIps = ['127.0.0.1', '::1', 'localhost', '0.0.0.0'];
  if (localIps.includes(clean1) && localIps.includes(clean2)) return true;

  return false;
}

function createAuthToken(user) {
  const payload = {
    sub: parseInt(user.id || 0, 10),
    username: String(user.username || ''),
    role: normalizeRole(user.role || ''),
  };
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

function createRefreshToken(user) {
  const payload = {
    sub: parseInt(user.id || 0, 10),
    username: String(user.username || ''),
    role: normalizeRole(user.role || ''),
    token_type: 'refresh'
  };
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
}

function verifyAuthToken(token) {
  try {
    if (!token || typeof token !== 'string') return null;
    const trimmed = token.trim();
    if (!trimmed) return null;
    return jwt.verify(trimmed, JWT_SECRET);
  } catch (err) {
    return null;
  }
}

async function getAuthenticatedUserById(userId) {
  if (!userId || userId <= 0) return null;
  const db = await getPool();
  const [rows] = await db.query('SELECT * FROM users WHERE id = ? LIMIT 1', [userId]);
  if (!rows || rows.length === 0) return null;
  return rows[0];
}

async function getAllPermissionCodes() {
  const db = await getPool();
  const [rows] = await db.query('SELECT permission_code FROM permissions ORDER BY id ASC');
  const codes = [];
  for (const r of rows) {
    const code = String(r.permission_code || '').trim().toLowerCase();
    if (code && !codes.includes(code)) {
      codes.push(code);
    }
  }
  return codes;
}

async function getDirectUserPermissionCodes(userId) {
  if (!userId || userId <= 0) return [];
  const db = await getPool();
  const [rows] = await db.query(`
    SELECT DISTINCT p.permission_code, p.id
    FROM user_permissions up
    INNER JOIN permissions p ON p.id = up.permission_id
    WHERE up.user_id = ?
    ORDER BY p.id ASC
  `, [userId]);

  const codes = [];
  for (const r of rows) {
    const code = String(r.permission_code || '').trim().toLowerCase();
    if (code && !codes.includes(code)) {
      codes.push(code);
    }
  }
  return codes;
}

async function getUserPermissionCodes(user) {
  if (!user || !user.id) return [];
  const role = normalizeRole(user.role);
  if (role === 'ADMIN') {
    return await getAllPermissionCodes();
  }
  return await getDirectUserPermissionCodes(user.id);
}

function isAdminUser(user) {
  const role = normalizeRole(user ? user.role : '');
  return role === 'ADMIN' || role === 'SUPER_ADMIN';
}

/**
 * Checks if the Admin account currently has an active, unexpired session on another device.
 * Automatically allows re-login from the SAME device / IP or if inactive > 30 minutes.
 */
async function hasActiveAdminSession(connOrDb, adminUserId, reqInfo = {}) {
  if (!adminUserId) return false;
  const db = connOrDb || await getPool();

  await db.query(
    `UPDATE user_sessions SET status = 'EXPIRED' WHERE user_id = ? AND status = 'ACTIVE' AND expires_at <= NOW()`,
    [adminUserId]
  );

  const [activeRows] = await db.query(
    `SELECT id, created_at, expires_at, device_info, ip_address, UNIX_TIMESTAMP(last_activity_at) AS last_activity_unix, UNIX_TIMESTAMP(NOW()) AS now_unix
     FROM user_sessions
     WHERE user_id = ? AND status = 'ACTIVE' AND expires_at > NOW() LIMIT 1`,
    [adminUserId]
  );

  if (activeRows.length === 0) return false;

  const active = activeRows[0];
  const nowUnix = parseInt(active.now_unix || Math.floor(Date.now() / 1000), 10);
  const lastActUnix = parseInt(active.last_activity_unix || 0, 10);
  const inactivitySec = nowUnix - lastActUnix;

  const currentIp = reqInfo.ipAddress || reqInfo.ip;
  const isSameIp = isSameOrLocalIp(active.ip_address, currentIp);

  if (reqInfo.forceLogin || isSameIp || inactivitySec > 1800) {
    await db.query(
      `UPDATE user_sessions SET status = 'REPLACED', revoked_at = NOW() WHERE user_id = ? AND status = 'ACTIVE'`,
      [adminUserId]
    );
    return false;
  }

  return true;
}

/**
 * Creates a new active session for Admin within a MySQL transaction with row-level locking.
 * Allows seamless takeover/replacement if from the same device / IP or forceLogin is requested.
 */
async function createAdminSession(connOrDb, { userId, token, deviceInfo, ipAddress, userAgent, forceLogin = false, expiresInSeconds = JWT_EXPIRES_IN }) {
  const db = connOrDb;
  const tokenHash = hashToken(token);
  const expiresAt = new Date(Date.now() + expiresInSeconds * 1000);
  const ip = String(ipAddress || '127.0.0.1').substring(0, 45);
  const info = String(deviceInfo || userAgent || 'Unknown Device').substring(0, 255);

  await db.query(
    `UPDATE user_sessions SET status = 'EXPIRED' WHERE user_id = ? AND status = 'ACTIVE' AND expires_at <= NOW()`,
    [userId]
  );

  // Lock active sessions FOR UPDATE to prevent concurrent race conditions
  const [activeRows] = await db.query(
    `SELECT id, ip_address, device_info, UNIX_TIMESTAMP(last_activity_at) AS last_activity_unix, UNIX_TIMESTAMP(NOW()) AS now_unix
     FROM user_sessions
     WHERE user_id = ? AND status = 'ACTIVE' AND expires_at > NOW() FOR UPDATE`,
    [userId]
  );

  if (activeRows.length > 0) {
    const active = activeRows[0];
    const nowUnix = parseInt(active.now_unix || Math.floor(Date.now() / 1000), 10);
    const lastActUnix = parseInt(active.last_activity_unix || 0, 10);
    const inactivitySec = nowUnix - lastActUnix;

    const isSameIp = isSameOrLocalIp(active.ip_address, ip);

    if (forceLogin || isSameIp || inactivitySec > 1800) {
      // Invalidate previous session and allow login on same device
      await db.query(
        `UPDATE user_sessions SET status = 'REPLACED', revoked_at = NOW() WHERE user_id = ? AND status = 'ACTIVE'`,
        [userId]
      );
    } else {
      const err = new Error('Your Admin account is currently active on another device. Please log out from the existing device before attempting to log in again.');
      err.code = 'ADMIN_ALREADY_LOGGED_IN';
      throw err;
    }
  }

  const [insertRes] = await db.query(
    `INSERT INTO user_sessions (user_id, session_token, device_info, ip_address, created_at, last_activity_at, expires_at, status)
     VALUES (?, ?, ?, ?, NOW(), NOW(), ?, 'ACTIVE')`,
    [userId, tokenHash, info, ip, expiresAt]
  );

  return insertRes.insertId;
}

/**
 * Creates a session for Staff or non-Admin users in user_sessions.
 */
async function createUserSession(connOrDb, { userId, token, deviceInfo, ipAddress, expiresInSeconds = JWT_EXPIRES_IN }) {
  const db = connOrDb || await getPool();
  const tokenHash = hashToken(token);
  const expiresAt = new Date(Date.now() + expiresInSeconds * 1000);
  const ip = String(ipAddress || '127.0.0.1').substring(0, 45);
  const info = String(deviceInfo || 'Staff Device').substring(0, 255);

  const [insertRes] = await db.query(
    `INSERT INTO user_sessions (user_id, session_token, device_info, ip_address, created_at, last_activity_at, expires_at, status)
     VALUES (?, ?, ?, ?, NOW(), NOW(), ?, 'ACTIVE')`,
    [userId, tokenHash, info, ip, expiresAt]
  );

  return insertRes.insertId;
}

/**
 * Verifies if a user's current session token is ACTIVE and NOT expired in MySQL database.
 */
async function verifyActiveSession(connOrDb, userId, token) {
  if (!userId || !token) return false;
  const db = connOrDb || await getPool();
  const tokenHash = hashToken(token);

  const [rows] = await db.query(
    `SELECT id, status, UNIX_TIMESTAMP(expires_at) AS expires_unix, UNIX_TIMESTAMP(NOW()) AS now_unix
     FROM user_sessions
     WHERE user_id = ? AND session_token = ? LIMIT 1`,
    [userId, tokenHash]
  );

  if (rows.length === 0) return false;
  const session = rows[0];

  if (session.status !== 'ACTIVE') return false;

  const nowUnix = parseInt(session.now_unix || Math.floor(Date.now() / 1000), 10);
  const expiresUnix = parseInt(session.expires_unix || 0, 10);

  if (expiresUnix > 0 && nowUnix >= expiresUnix) {
    await db.query(`UPDATE user_sessions SET status = 'EXPIRED' WHERE id = ?`, [session.id]);
    return false;
  }

  // Update last activity timestamp
  try {
    await db.query(`UPDATE user_sessions SET last_activity_at = NOW() WHERE id = ?`, [session.id]);
  } catch (e) {}

  return true;
}

/**
 * Marks the current session as LOGGED_OUT upon logout.
 */
async function logoutSession(connOrDb, userId, token) {
  const db = connOrDb || await getPool();

  if (token) {
    const tokenHash = hashToken(token);
    await db.query(
      `UPDATE user_sessions SET status = 'LOGGED_OUT', revoked_at = NOW() WHERE session_token = ? AND status = 'ACTIVE'`,
      [tokenHash]
    );
  }

  if (userId) {
    await db.query(
      `UPDATE user_sessions SET status = 'LOGGED_OUT', revoked_at = NOW() WHERE user_id = ? AND status = 'ACTIVE'`,
      [userId]
    );
  }
  return true;
}

module.exports = {
  JWT_SECRET,
  normalizeRole,
  hashToken,
  isSameOrLocalIp,
  createAuthToken,
  createRefreshToken,
  verifyAuthToken,
  getAuthenticatedUserById,
  getAllPermissionCodes,
  getDirectUserPermissionCodes,
  getUserPermissionCodes,
  isAdminUser,
  hasActiveAdminSession,
  createAdminSession,
  createUserSession,
  verifyActiveSession,
  logoutSession,
};
