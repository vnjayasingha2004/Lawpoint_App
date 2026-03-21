const { v4: uuid } = require('uuid');
const { run, get } = require('../db');
const { nowIso } = require('../utils/time');
const { hashOtpCode } = require('../utils/crypto');

function generateResetCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

async function createPasswordResetCode(userId) {
  const code = generateResetCode();
  const codeHash = hashOtpCode(code);
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
  const id = uuid();

  await run(
    `INSERT INTO public."PasswordResetCode" (id, "userId", code, "expiresAt", "usedAt", "createdAt")
     VALUES (?, ?, ?, ?, ?, ?)`,
    [id, userId, codeHash, expiresAt, null, nowIso()]
  );

  return { id, code, expiresAt };
}

async function getLatestValidResetCode(userId, submittedCode) {
  const codeHash = hashOtpCode(submittedCode);

  return get(
    `SELECT *
     FROM public."PasswordResetCode"
     WHERE "userId" = ?
       AND code = ?
       AND "usedAt" IS NULL
       AND "expiresAt" > NOW()
     ORDER BY "createdAt" DESC
     LIMIT 1`,
    [userId, codeHash]
  );
}

async function markResetCodeUsed(id) {
  await run(
    `UPDATE public."PasswordResetCode"
     SET "usedAt" = ?
     WHERE id = ?`,
    [nowIso(), id]
  );
}

module.exports = {
  createPasswordResetCode,
  getLatestValidResetCode,
  markResetCodeUsed,
};