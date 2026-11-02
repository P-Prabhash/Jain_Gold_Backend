const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { getPool } = require('../config/database');
const { JWT_SECRET, createAuthToken } = require('../config/auth');
const { requirePermission } = require('../middleware/authMiddleware');

async function ensureSettingsTable(db) {
  await db.query(`
    CREATE TABLE IF NOT EXISTS settings (
      id INT AUTO_INCREMENT PRIMARY KEY,
      setting_key VARCHAR(100) NOT NULL UNIQUE,
      setting_value TEXT NULL,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
}

// ============================================================
// GET /settings/get (.php)
// ============================================================
router.get(['/get', '/get.php'], requirePermission('settings.view'), async (req, res) => {
  try {
    const db = await getPool();
    await ensureSettingsTable(db);

    const [rows] = await db.query('SELECT * FROM settings');

    const settingsMap = {};
    for (const row of rows) {
      settingsMap[row.setting_key] = row.setting_value;
    }

    const payload = {
      shop_name: settingsMap.shop_name || 'GOLD & SILVER PAWN LOAN MANAGEMENT',
      shop_address: settingsMap.shop_address || 'Main Market Road, Commercial Complex',
      shop_phone: settingsMap.shop_phone || '+91 98765 43210',
      default_interest_rate: settingsMap.default_interest_rate || '2.00'
    };

    return res.json({
      success: true,
      data: payload,
      settings: payload
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to fetch settings.', error: err.message });
  }
});

// ============================================================
// POST /settings/save (.php)
// ============================================================
router.post(['/save', '/save.php'], requirePermission('settings.edit'), async (req, res) => {
  const shopName = String(req.body.shop_name || req.body.shopName || '').trim();
  const shopAddress = String(req.body.shop_address || req.body.shopAddress || '').trim();
  const shopPhone = String(req.body.shop_phone || req.body.shopPhone || '').trim();
  const defaultRate = String(req.body.default_interest_rate || req.body.defaultRate || '2.00').trim();

  try {
    const db = await getPool();
    await ensureSettingsTable(db);

    const updates = [
      ['shop_name', shopName],
      ['shop_address', shopAddress],
      ['shop_phone', shopPhone],
      ['default_interest_rate', defaultRate]
    ];

    for (const [key, val] of updates) {
      if (val) {
        await db.query(`
          INSERT INTO settings (setting_key, setting_value)
          VALUES (?, ?)
          ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_at = CURRENT_TIMESTAMP
        `, [key, val]);
      }
    }

    return res.json({
      success: true,
      message: 'Settings saved successfully.'
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to save settings.', error: err.message });
  }
});

// ============================================================
// POST /settings/update_admin_credentials (.php)
// ============================================================
router.post(['/update_admin_credentials', '/update_admin_credentials.php'], requirePermission('settings.edit'), async (req, res) => {
  const currentPassword = String(req.body.current_password || req.body.currentPassword || req.body.old_password || req.body.oldPassword || '').trim();
  const newUsername = String(req.body.new_username || req.body.newUsername || req.body.username || '').trim();
  const newPassword = String(req.body.new_password || req.body.newPassword || req.body.password || '').trim();
  const confirmPassword = String(req.body.confirm_password || req.body.confirmPassword || '').trim();

  if (!currentPassword) {
    return res.status(422).json({ success: false, message: 'Current password is required.' });
  }

  try {
    const db = await getPool();

    const [adminRows] = await db.query('SELECT * FROM users WHERE id = ?', [req.user.id]);
    if (adminRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Admin account not found.' });
    }

    const adminUser = adminRows[0];
    const hash = String(adminUser.password_hash || '').trim();

    let passwordMatch = false;
    if (hash && hash.length > 0) {
      try {
        passwordMatch = bcrypt.compareSync(currentPassword, hash);
      } catch (e) {
        passwordMatch = false;
      }
    }

    if (!passwordMatch) {
      return res.status(401).json({ success: false, message: 'Current password is incorrect.' });
    }

    if (!newUsername && !newPassword) {
      return res.status(422).json({ success: false, message: 'New username or new password is required.' });
    }

    if (newPassword) {
      if (newPassword.length < 6) {
        return res.status(422).json({ success: false, message: 'New password must contain at least 6 characters.' });
      }
      if (confirmPassword && newPassword !== confirmPassword) {
        return res.status(422).json({ success: false, message: 'New password and confirm password do not match.' });
      }
    }

    let updatedUsername = adminUser.username;
    if (newUsername && newUsername.toLowerCase() !== adminUser.username.toLowerCase()) {
      const [dup] = await db.query('SELECT id FROM users WHERE LOWER(username) = LOWER(?) AND id != ?', [newUsername, req.user.id]);
      if (dup.length > 0) {
        return res.status(409).json({ success: false, message: 'Username is already taken by another user.' });
      }
      updatedUsername = newUsername;
    }

    let updatedHash = adminUser.password_hash;
    if (newPassword) {
      updatedHash = bcrypt.hashSync(newPassword, 10);
    }

    const [updateRes] = await db.query(
      'UPDATE users SET username = ?, password_hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [updatedUsername, updatedHash, req.user.id]
    );

    if (updateRes.affectedRows === 0) {
      return res.status(500).json({ success: false, message: 'Failed to update credentials in database.' });
    }

    // Record audit log
    try {
      await db.query(
        `INSERT INTO audit_logs (user_id, username, action, module_name, reference_type, reference_id, description)
         VALUES (?, ?, 'UPDATE_CREDENTIALS', 'Settings', 'USER', ?, 'Admin credentials updated successfully')`,
        [req.user.id, updatedUsername, String(req.user.id)]
      );
    } catch (e) {
      // ignore
    }

    const updatedUserPayload = {
      id: req.user.id,
      username: updatedUsername,
      full_name: adminUser.full_name,
      role: adminUser.role,
      status: adminUser.status
    };

    const newToken = createAuthToken(updatedUserPayload);

    return res.json({
      success: true,
      message: 'ADMIN credentials updated successfully. Please log in with your new credentials.',
      token: newToken,
      user: updatedUserPayload,
      data: {
        token: newToken,
        user: updatedUserPayload
      }
    });

  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to update admin credentials.', error: err.message });
  }
});

module.exports = router;
