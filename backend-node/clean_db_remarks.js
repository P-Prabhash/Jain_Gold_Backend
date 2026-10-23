const { getPool } = require('./config/database');

async function cleanDBRemarks() {
  try {
    const db = await getPool();
    console.log('Connected to MySQL. Cleaning transaction remarks...');

    const [result1] = await db.query(`
      UPDATE loan_transactions
      SET remarks = REPLACE(REPLACE(REPLACE(remarks, '₹', 'Rs '), '?', 'Rs '), 'Rs. ', 'Rs ')
      WHERE remarks LIKE '%₹%' OR remarks LIKE '%?%' OR remarks LIKE '%Rs. %'
    `);
    console.log('Updated loan_transactions rows:', result1.affectedRows);

    process.exit(0);
  } catch (err) {
    console.error('Error cleaning remarks:', err);
    process.exit(1);
  }
}

cleanDBRemarks();
