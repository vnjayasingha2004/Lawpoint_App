const { v4: uuid } = require('uuid');
const { run, get } = require('../db');
const { nowIso } = require('../utils/time');
const { hashOtpCode } = require('../utils/crypto');

function generateVerificationCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

async function createEmailVerificationCode(userId) {
  const code = generateVerificationCode();
  const codeHash = hashOtpCode(code);
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  await run(
    `INSERT INTO public."EmailVerificationCode" (id, "userId", code, "expiresAt", "usedAt", "createdAt")
     VALUES (?, ?, ?, ?, ?, ?)`,
    [uuid(), userId, codeHash, expiresAt, null, nowIso()]
  );

  return { code, expiresAt };
}

async function getLatestValidVerificationCode(userId, submittedCode) {
  const codeHash = hashOtpCode(submittedCode);

  return get(
    `SELECT *
     FROM public."EmailVerificationCode"
     WHERE "userId" = ?
       AND code = ?
       AND "usedAt" IS NULL
       AND "expiresAt" > NOW()
     ORDER BY "createdAt" DESC
     LIMIT 1`,
    [userId, codeHash]
  );
}

async function markVerificationCodeUsed(id) {
  await run(
    `UPDATE public."EmailVerificationCode"
     SET "usedAt" = ?
     WHERE id = ?`,
    [nowIso(), id]
  );
}

module.exports = {
  createEmailVerificationCode,
  getLatestValidVerificationCode,
  markVerificationCodeUsed,
};