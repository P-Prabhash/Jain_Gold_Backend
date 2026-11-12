const express = require('express');
const cors = require('cors');
const path = require('path');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 80;

// ============================================================
// CORS CONFIGURATION
// ============================================================
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Authorization', 'Content-Type', 'Accept', 'Origin', 'X-Requested-With'],
  exposedHeaders: ['Content-Type'],
  maxAge: 86400
}));
app.options('*', cors());

// ============================================================
// BODY PARSER
// ============================================================
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// ============================================================
// URL NORMALIZER FOR PATH ALIASES
// ============================================================
app.use((req, res, next) => {
  let url = req.url;

  // Remove prefix /gold_pawn_erp/backend or /backend if present
  if (url.startsWith('/gold_pawn_erp/backend')) {
    url = url.substring('/gold_pawn_erp/backend'.length);
  } else if (url.startsWith('/backend')) {
    url = url.substring('/backend'.length);
  }

  // Handle empty or root
  if (!url || url === '') {
    url = '/';
  }

  req.url = url;
  next();
});

// ============================================================
// STATIC FILE SERVING FOR UPLOADS
// ============================================================
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/gold_pawn_erp/backend/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/backend/uploads', express.static(path.join(__dirname, 'uploads')));

// ============================================================
// IMPORT ROUTES
// ============================================================
const authRoutes = require('./routes/auth');
const customerRoutes = require('./routes/customers');
const dashboardRoutes = require('./routes/dashboard');
const goldRoutes = require('./routes/gold');
const interestRoutes = require('./routes/interest');
const loanRoutes = require('./routes/loans');
const paymentRoutes = require('./routes/payments');
const receiptRoutes = require('./routes/receipts');
const releaseRoutes = require('./routes/releases');
const reportRoutes = require('./routes/reports');
const transactionRoutes = require('./routes/transactions');
const userRoutes = require('./routes/users');
const settingsRoutes = require('./routes/settings');
const uploadRoutes = require('./routes/upload');
const backupRoutes = require('./routes/backup');
const seedRoutes = require('./routes/seed');
const testWorkflowRoutes = require('./routes/test_workflow');
const docsRoutes = require('./routes/docs');
const centralLedgerRoutes = require('./routes/centralLedger');

// ============================================================
// MOUNT ROUTERS & TOP-LEVEL ROUTE ALIASES
// ============================================================
app.all([
  '/auth/resend-otp',
  '/auth/resend_otp',
  '/api/auth/resend-otp',
  '/api/auth/resend_otp',
  '/resend-otp'
], (req, res, next) => {
  req.url = '/resend-otp';
  return authRoutes(req, res, next);
});

app.all([
  '/auth/verify-otp',
  '/auth/verify_otp',
  '/api/auth/verify-otp',
  '/api/auth/verify_otp',
  '/verify-otp'
], (req, res, next) => {
  req.url = '/verify-otp';
  return authRoutes(req, res, next);
});

app.all([
  '/auth/login',
  '/api/auth/login',
  '/login'
], (req, res, next) => {
  req.url = '/login';
  return authRoutes(req, res, next);
});

app.use(['/api/auth', '/auth'], authRoutes);
app.use(['/api/central-ledger', '/central-ledger', '/api/central_ledger', '/central_ledger'], centralLedgerRoutes);
app.use('/customers', customerRoutes);
app.use('/dashboard', dashboardRoutes);
app.use('/gold', goldRoutes);
app.use('/interest', interestRoutes);
app.use('/loans', loanRoutes);
app.use('/payments', paymentRoutes);
app.use('/receipts', receiptRoutes);
app.use('/releases', releaseRoutes);
app.use('/reports', reportRoutes);
app.use('/transactions', transactionRoutes);
app.use('/users', userRoutes);
app.use('/settings', settingsRoutes);
app.use('/upload', uploadRoutes);
app.use('/backup', backupRoutes);
app.use('/seed', seedRoutes);
app.use('/test_workflow', testWorkflowRoutes);
app.use(['/api-docs', '/docs', '/swagger.json'], docsRoutes);

// Health check endpoint
app.get(['/', '/health'], (req, res) => {
  res.json({
    success: true,
    message: 'Gold Pawn ERP Node.js Backend is running.',
    timestamp: new Date().toISOString()
  });
});

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('Unhandled Error:', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error.',
    error: err.message
  });
});

// Process Exception Safety
process.on('uncaughtException', (err) => {
  console.error('[SERVER UNCAUGHT EXCEPTION]', err.stack || err);
});

process.on('unhandledRejection', (reason) => {
  console.error('[SERVER UNHANDLED REJECTION]', reason);
});

// Start Server
app.listen(PORT, async () => {
  console.log(`============================================================`);
  console.log(` Gold Pawn ERP Node.js Backend Server Running `);
  console.log(` Port: ${PORT}`);
  console.log(` Base URL: http://localhost:${PORT}`);
  console.log(`============================================================`);

  // Auto-initialize Database Connection & Tables Schema on Server Startup
  try {
    const { getPool } = require('./config/database');
    await getPool();
    console.log(`[DATABASE SUCCESS] Connected to MySQL and all tables verified/created.`);

    // Verify Gmail SMTP Connection
    const { verifySmtpConnection } = require('./utils/emailHelper');
    await verifySmtpConnection();
  } catch (err) {
    console.error(`[DATABASE ERROR] Initialization failed: ${err.message}`);
  }
});
