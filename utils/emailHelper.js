const nodemailer = require('nodemailer');
require('dotenv').config();

const SMTP_USER = process.env.SMTP_USER || 'pandetiprabhash@gmail.com';
const SMTP_HOST = process.env.SMTP_HOST || 'smtp.gmail.com';
const SMTP_PORT = parseInt(process.env.SMTP_PORT || '587', 10);
const SMTP_SECURE = process.env.SMTP_SECURE === 'true' || process.env.SMTP_SECURE === '1';
const SMTP_PASS = process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD || '';

async function sendOtpEmail(toEmail, otp, challengeId) {
  const targetEmail = (toEmail && toEmail.trim()) ? toEmail.trim() : 'pandetiprabhash@gmail.com';
  console.log(`[GMAIL OTP GENERATED] OTP for ${targetEmail}: ${otp} (Challenge ID: ${challengeId})`);

  if (!SMTP_PASS || SMTP_PASS.trim() === '') {
    console.warn(`[GMAIL SMTP NOTICE] SMTP_PASS / GMAIL_APP_PASSWORD is not set. OTP logged above for dev/testing.`);
    return { success: false, message: 'SMTP Password not configured, logged OTP for dev/testing.' };
  }

  try {
    const transporter = nodemailer.createTransport({
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

    const mailOptions = {
      from: `"Jain Gold & Pawn Shop ERP" <${SMTP_USER}>`,
      to: targetEmail,
      subject: `Your Login Verification Code - ${otp}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px; border: 1px solid #e0e0e0; border-radius: 12px; background-color: #ffffff;">
          <div style="text-align: center; margin-bottom: 20px;">
            <h2 style="color: #0c101b; margin: 0; font-size: 22px;">Jain Gold & Pawn Shop ERP</h2>
            <p style="color: #c5a059; font-weight: bold; margin-top: 4px; font-size: 13px; text-transform: uppercase;">Enterprise Collateral Management</p>
          </div>
          <hr style="border: 0; border-top: 1px solid #eaeaea; margin: 16px 0;" />
          <h3 style="color: #333333; font-size: 16px; margin-bottom: 8px;">Email Verification Code</h3>
          <p style="color: #555555; font-size: 14px; line-height: 1.5;">A 4-digit verification code has been generated for your Admin login session.</p>

          <div style="background-color: #f8fafc; padding: 20px; text-align: center; border-radius: 8px; margin: 24px 0; border: 1px dashed #cbd5e1;">
            <span style="font-size: 36px; font-weight: 900; letter-spacing: 12px; color: #0c101b;">${otp}</span>
          </div>

          <p style="color: #64748b; font-size: 13px; line-height: 1.4;">
            This OTP will expire in <strong>5 minutes</strong>. If you did not request this login attempt, please contact system administration immediately.
          </p>
          <div style="margin-top: 24px; padding-top: 16px; border-top: 1px solid #f1f5f9; text-align: center; color: #94a3b8; font-size: 11px;">
            Authorized Admin Access Only • Ref: ${challengeId}
          </div>
        </div>
      `,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`[GMAIL SMTP SUCCESS] Sent OTP email to ${targetEmail}. MessageID: ${info.messageId}`);
    return { success: true, messageId: info.messageId };
  } catch (err) {
    console.error(`[GMAIL SMTP ERROR] Failed to send email to ${targetEmail}: ${err.message}`);
    return { success: false, error: err.message };
  }
}

module.exports = {
  sendOtpEmail
};
