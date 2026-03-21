const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
});

async function sendPasswordResetEmail({ to, code }) {
  const mail = {
    from: process.env.MAIL_FROM || process.env.GMAIL_USER,
    to,
    subject: 'LawPoint password reset code',
    text: `Your LawPoint password reset code is: ${code}. This code expires in 10 minutes.`,
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.6;">
        <h2>LawPoint Password Reset</h2>
        <p>Your password reset code is:</p>
        <div style="font-size: 28px; font-weight: bold; letter-spacing: 4px;">${code}</div>
        <p>This code expires in 10 minutes.</p>
        <p>If you did not request this, you can ignore this email.</p>
      </div>
    `,
  };

  return transporter.sendMail(mail);
}

async function sendVerificationEmail({ to, code }) {
  const mail = {
    from: process.env.MAIL_FROM || process.env.GMAIL_USER,
    to,
    subject: 'LawPoint email verification code',
    text: `Your LawPoint verification code is: ${code}. This code expires in 10 minutes.`,
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.6;">
        <h2>LawPoint Email Verification</h2>
        <p>Your verification code is:</p>
        <div style="font-size: 28px; font-weight: bold; letter-spacing: 4px;">${code}</div>
        <p>This code expires in 10 minutes.</p>
      </div>
    `,
  };

  return transporter.sendMail(mail);
}

module.exports = {
  transporter,
  sendPasswordResetEmail,
  sendVerificationEmail,
};