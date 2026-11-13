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
// URL NORMALIZER FOR PATH ALIASES & PHP EXTENSIONS
// ============================================================
app.use((req, res, next) => {
  let url = req.url;

  // Remove prefix /gold_pawn_erp/backend or /backend if present
  if (url.startsWith('/gold_pawn_erp/backend')) {
    url = url.substring('/gold_pawn_erp/backend'.length);
  } else if (url.startsWith('/backend')) {
    url = url.substring('/backend'.length);
  }

  // Seamlessly strip trailing .php extension if present in path
  if (url.includes('.php')) {
    url = url.replace(/\.php(\?|$)/, '$1');
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
const defaultAvatarSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><circle cx="64" cy="64" r="64" fill="#F7E7CE"/><text x="50%" y="54%" dominant-baseline="middle" text-anchor="middle" font-family="sans-serif" font-size="52" font-weight="bold" fill="#AA7C11">C</text></svg>`;

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/gold_pawn_erp/backend/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/backend/uploads', express.static(path.join(__dirname, 'uploads')));

// Fallback for missing uploads images (Serve default SVG avatar instead of 404)
app.use(['/uploads', '/gold_pawn_erp/backend/uploads', '/backend/uploads'], (req, res, next) => {
  if (req.method === 'GET') {
    res.setHeader('Content-Type', 'image/svg+xml');
    return res.status(200).send(defaultAvatarSvg);
  }
  next();
});

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
  '/auth/resend-otp.php',
  '/auth/resend_otp.php',
  '/api/auth/resend-otp',
  '/api/auth/resend_otp',
  '/resend-otp',
  '/resend-otp.php'
], (req, res, next) => {
  req.url = '/resend-otp';
  return authRoutes(req, res, next);
});

app.all([
  '/auth/verify-otp',
  '/auth/verify_otp',
  '/auth/verify-otp.php',
  '/auth/verify_otp.php',
  '/api/auth/verify-otp',
  '/api/auth/verify_otp',
  '/verify-otp',
  '/verify-otp.php'
], (req, res, next) => {
  req.url = '/verify-otp';
  return authRoutes(req, res, next);
});

app.all([
  '/auth/login',
  '/auth/login.php',
  '/api/auth/login',
  '/api/auth/login.php',
  '/login',
  '/login.php'
], (req, res, next) => {
  req.url = '/login';
  return authRoutes(req, res, next);
});

app.use(['/api/auth', '/auth', '/auth.php'], authRoutes);
app.use(['/api/central-ledger', '/central-ledger', '/api/central_ledger', '/central_ledger'], centralLedgerRoutes);
app.use(['/api/customers', '/customers', '/customers.php'], customerRoutes);
app.use(['/api/dashboard', '/dashboard', '/dashboard.php'], dashboardRoutes);
app.use(['/api/gold', '/gold', '/gold.php'], goldRoutes);
app.use(['/api/interest', '/interest', '/interest.php'], interestRoutes);
app.use(['/api/loans', '/loans', '/loans.php'], loanRoutes);
app.use(['/api/payments', '/payments', '/payments.php'], paymentRoutes);
app.use(['/api/receipts', '/receipts', '/receipts.php'], receiptRoutes);
app.use(['/api/releases', '/releases', '/releases.php'], releaseRoutes);
app.use(['/api/reports', '/reports', '/reports.php'], reportRoutes);
app.use(['/api/transactions', '/transactions', '/transactions.php'], transactionRoutes);
app.use(['/api/users', '/users', '/users.php'], userRoutes);
app.use(['/api/settings', '/settings', '/settings.php'], settingsRoutes);
app.use(['/api/upload', '/upload', '/upload.php'], uploadRoutes);
app.use(['/api/backup', '/backup', '/backup.php'], backupRoutes);
app.use(['/api/seed', '/seed', '/seed.php'], seedRoutes);
app.use(['/api/test_workflow', '/test_workflow', '/test_workflow.php'], testWorkflowRoutes);
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
app.listen(PORT, '0.0.0.0', async () => {
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
