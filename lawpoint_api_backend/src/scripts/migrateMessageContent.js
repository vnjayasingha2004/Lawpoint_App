const { all, run } = require('../db');
const { encryptText } = require('../utils/crypto');

function normalizeText(value) {
  if (value == null) return '';
  return String(value);
}

async function migrateMessages() {
  const rows = await all(
    `SELECT id, content, "contentCiphertext"
     FROM public."Message"
     ORDER BY "createdAt" ASC`
  );

  let migrated = 0;
  let skipped = 0;

  for (const row of rows) {
    const plainContent = normalizeText(row.content);

    if (row.contentCiphertext || !plainContent.trim()) {
      skipped += 1;
      continue;
    }

    await run(
      `UPDATE public."Message"
       SET content = ?,
           "contentCiphertext" = ?,
           "contentEncryptionVersion" = ?
       WHERE id = ?`,
      [
        '',
        encryptText(plainContent),
        1,
        row.id,
      ]
    );

    migrated += 1;
  }

  return { migrated, skipped };
}

(async () => {
  try {
    const result = await migrateMessages();
    console.log(`Messages migrated: ${result.migrated}`);
    console.log(`Messages skipped: ${result.skipped}`);
    console.log('Message encryption migration completed successfully.');
    process.exit(0);
  } catch (error) {
    console.error('Message encryption migration failed:', error.message);
    process.exit(1);
  }
})();