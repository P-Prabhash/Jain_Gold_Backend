const nodemailer = require('nodemailer');
require('dotenv').config();

function getTransporter() {
  const SMTP_USER = (process.env.SMTP_USER || 'pandetiprabhash@gmail.com').trim();
  const SMTP_HOST = (process.env.SMTP_HOST || 'smtp.gmail.com').trim();
  const SMTP_PASS = (process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD || '').trim();

  if (SMTP_HOST === 'smtp.gmail.com' || SMTP_HOST === 'gmail') {
    return nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: SMTP_USER,
        pass: SMTP_PASS,
      },
      tls: {
        rejectUnauthorized: false
      }
    });
  }

  const SMTP_PORT = parseInt(process.env.SMTP_PORT || '587', 10);
  const SMTP_SECURE = process.env.SMTP_SECURE === 'true' || process.env.SMTP_SECURE === '1';

  return nodemailer.createTransport({
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_SECURE,
    auth: {
      user: SMTP_USER,
      pass: SMTP_PASS,
    },
    tls: {
      rejectUnauthorized: false
    }
  });
}

async function verifySmtpConnection() {
  console.log('[MAIL] Gmail SMTP configuration loaded');
  console.log('[MAIL] Verifying SMTP connection');

  const SMTP_PASS = (process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD || '').trim();
  if (!SMTP_PASS) {
    console.warn('[MAIL ERROR] SMTP_PASS / GMAIL_APP_PASSWORD is not set in environment.');
    return { success: false, error: 'SMTP_PASS not set' };
  }

  try {
    const transporter = getTransporter();
    await transporter.verify();
    console.log('[MAIL] SMTP connection successful');
    return { success: true };
  } catch (err) {
    if (err.message.includes('Username and Password not accepted') || err.code === 'EAUTH') {
      console.error('[MAIL ERROR] SMTP authentication failed');
    } else if (err.code === 'ETIMEDOUT' || err.code === 'ESOCKET') {
      console.error('[MAIL ERROR] SMTP connection timeout');
    } else {
      console.error(`[MAIL ERROR] Gmail rejected connection: ${err.message}`);
    }
    return { success: false, error: err.message };
  }
}

async function sendOtpEmail(toEmail, otp, challengeId) {
  const targetEmail = (toEmail && toEmail.trim()) ? toEmail.trim() : 'pandetiprabhash@gmail.com';
  console.log(`[MAIL] Sending OTP email to ${targetEmail}`);

  const SMTP_USER = (process.env.SMTP_USER || 'pandetiprabhash@gmail.com').trim();
  const SMTP_PASS = (process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD || '').trim();

  if (!SMTP_PASS) {
    console.warn(`[MAIL ERROR] SMTP authentication failed: SMTP_PASS not set (Challenge ID: ${challengeId})`);
    return { success: false, error: 'SMTP Password not configured in .env' };
  }

  try {
    const transporter = getTransporter();

    const mailOptions = {
      from: `"Gold & Silver ERP" <${SMTP_USER}>`,
      to: targetEmail,
      subject: 'Gold & Silver ERP – Admin Login Verification Code',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px; border: 1px solid #e0e0e0; border-radius: 12px; background-color: #ffffff;">
          <div style="text-align: center; margin-bottom: 20px;">
            <h2 style="color: #0c101b; margin: 0; font-size: 22px;">Gold & Silver ERP</h2>
            <p style="color: #c5a059; font-weight: bold; margin-top: 4px; font-size: 13px; text-transform: uppercase;">Jain Gold & Pawn Shop ERP</p>
          </div>
          <hr style="border: 0; border-top: 1px solid #eaeaea; margin: 16px 0;" />
          <p style="color: #333333; font-size: 15px; margin-bottom: 12px;">Dear Admin,</p>
          <p style="color: #555555; font-size: 14px; line-height: 1.5;">Your Gold & Silver ERP login verification code is:</p>

          <div style="background-color: #f8fafc; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0; border: 1px dashed #cbd5e1;">
            <span style="font-size: 36px; font-weight: 900; letter-spacing: 12px; color: #0c101b;">${otp}</span>
          </div>

          <p style="color: #555555; font-size: 13px;">This verification code is valid for 5 minutes.</p>
          <p style="color: #d32f2f; font-size: 13px; font-weight: bold;">Do not share this code with anyone.</p>

          <div style="margin-top: 24px; padding-top: 16px; border-top: 1px solid #eaeaea; color: #0c101b; font-weight: bold; font-size: 13px;">
            Gold & Silver – Jain Gold & Pawn Shop ERP
          </div>
        </div>
      `,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`[MAIL] Email accepted by SMTP server. MessageId: ${info.messageId}`);
    return { success: true, messageId: info.messageId, response: info.response };
  } catch (err) {
    if (err.message.includes('No recipients defined') || err.code === 'EENVELOPE') {
      console.error(`[MAIL ERROR] Invalid recipient: ${targetEmail}`);
    } else if (err.message.includes('Username and Password not accepted') || err.code === 'EAUTH') {
      console.error(`[MAIL ERROR] SMTP authentication failed: ${err.message}`);
    } else if (err.code === 'ETIMEDOUT') {
      console.error(`[MAIL ERROR] SMTP connection timeout`);
    } else {
      console.error(`[MAIL ERROR] Gmail rejected email: ${err.message}`);
    }
    return { success: false, error: err.message };
  }
}

async function sendTestEmail(toEmail) {
  const targetEmail = (toEmail && toEmail.trim()) ? toEmail.trim() : 'pandetiprabhash@gmail.com';
  console.log(`[MAIL] Sending test email to ${targetEmail}`);

  const SMTP_USER = (process.env.SMTP_USER || 'pandetiprabhash@gmail.com').trim();
  const SMTP_PASS = (process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD || '').trim();

  if (!SMTP_PASS) {
    console.error('[MAIL ERROR] SMTP authentication failed: SMTP_PASS not set');
    return { success: false, error: 'SMTP_PASS / GMAIL_APP_PASSWORD is not configured in .env' };
  }

  try {
    const transporter = getTransporter();

    const mailOptions = {
      from: `"Gold & Silver ERP" <${SMTP_USER}>`,
      to: targetEmail,
      subject: 'Gold & Silver ERP – Gmail SMTP Connectivity Test',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px; border: 1px solid #e0e0e0; border-radius: 12px; background-color: #ffffff;">
          <div style="text-align: center; margin-bottom: 20px;">
            <h2 style="color: #0c101b; margin: 0; font-size: 22px;">Gold & Silver ERP</h2>
            <p style="color: #c5a059; font-weight: bold; margin-top: 4px; font-size: 13px; text-transform: uppercase;">Gmail SMTP Connectivity Test</p>
          </div>
          <hr style="border: 0; border-top: 1px solid #eaeaea; margin: 16px 0;" />
          <p style="color: #333333; font-size: 15px;">This is an automated SMTP test email from Gold & Silver ERP.</p>
          <p style="color: #2e7d32; font-weight: bold; font-size: 14px;">✔ Gmail SMTP Connection & Email Delivery Working Successfully!</p>
          <div style="margin-top: 24px; padding-top: 16px; border-top: 1px solid #f1f5f9; text-align: center; color: #94a3b8; font-size: 11px;">
            Target: ${targetEmail} • Sent At: ${new Date().toISOString()}
          </div>
        </div>
      `
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`[MAIL] Email accepted by SMTP server. MessageId: ${info.messageId}`);
    return { success: true, messageId: info.messageId, response: info.response };
  } catch (err) {
    if (err.message.includes('No recipients defined') || err.code === 'EENVELOPE') {
      console.error(`[MAIL ERROR] Invalid recipient: ${targetEmail}`);
    } else if (err.message.includes('Username and Password not accepted') || err.code === 'EAUTH') {
      console.error(`[MAIL ERROR] SMTP authentication failed: ${err.message}`);
    } else if (err.code === 'ETIMEDOUT') {
      console.error(`[MAIL ERROR] SMTP connection timeout`);
    } else {
      console.error(`[MAIL ERROR] Gmail rejected email: ${err.message}`);
    }
    return { success: false, error: err.message };
  }
}

module.exports = {
  verifySmtpConnection,
  sendOtpEmail,
  sendTestEmail
};
