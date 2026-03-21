const { all, run } = require('../db');
const { hashOtpCode } = require('../utils/crypto');

function isPlainOtp(value) {
  const text = String(value || '').trim();
  return /^\d{4,10}$/.test(text);
}

async function migrateTable(tableName) {
  const rows = await all(
    `SELECT id, code
     FROM public."${tableName}"
     ORDER BY "createdAt" ASC`
  );

  let migrated = 0;
  let skipped = 0;

  for (const row of rows) {
    const current = String(row.code || '').trim();

    if (!current || !isPlainOtp(current)) {
      skipped += 1;
      continue;
    }

    await run(
      `UPDATE public."${tableName}"
       SET code = ?
       WHERE id = ?`,
      [hashOtpCode(current), row.id]
    );

    migrated += 1;
  }

  return { migrated, skipped };
}

(async () => {
  try {
    const emailVerification = await migrateTable('EmailVerificationCode');
    const passwordReset = await migrateTable('PasswordResetCode');

    console.log(
      `EmailVerificationCode migrated: ${emailVerification.migrated}, skipped: ${emailVerification.skipped}`
    );
    console.log(
      `PasswordResetCode migrated: ${passwordReset.migrated}, skipped: ${passwordReset.skipped}`
    );
    console.log('OTP hash migration completed successfully.');
    process.exit(0);
  } catch (error) {
    console.error('OTP hash migration failed:', error.message);
    process.exit(1);
  }
})();