const express = require('express');
const router = express.Router();
const { getPool } = require('../config/database');

// ============================================================
// GET /test_workflow
// ============================================================
router.get(['/', '/test_workflow'], async (req, res) => {
  try {
    const db = await getPool();
    const [tables] = await db.query('SHOW TABLES');

    return res.json({
      success: true,
      message: 'Node.js Backend Workflow Operational Test Passed.',
      tables_count: tables.length
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Workflow Test Failed.', error: err.message });
  }
});

module.exports = router;
