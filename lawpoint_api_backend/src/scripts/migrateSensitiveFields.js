const { all, run } = require('../db');
const { encryptText, lookupHash } = require('../utils/crypto');

function normalizeText(value) {
  if (value == null) return null;
  const next = String(value).trim();
  return next.length ? next : null;
}

function normalizeEmail(value) {
  const next = normalizeText(value);
  return next ? next.toLowerCase() : null;
}

async function migrateUsers() {
  const users = await all(`SELECT * FROM public."User" ORDER BY "createdAt" ASC`);

  let migrated = 0;
  let skipped = 0;

  for (const user of users) {
    const plainEmail = normalizeEmail(user.email);
    const plainPhone = normalizeText(user.phone);

    const updates = [];
    const params = [];

    if (!user.emailCiphertext && plainEmail) {
      updates.push(`"emailCiphertext" = ?`);
      params.push(encryptText(plainEmail));
    }

    if (!user.emailLookupHash && plainEmail) {
      updates.push(`"emailLookupHash" = ?`);
      params.push(lookupHash(plainEmail));
    }

    if (!user.phoneCiphertext && plainPhone) {
      updates.push(`"phoneCiphertext" = ?`);
      params.push(encryptText(plainPhone));
    }

    if (!user.phoneLookupHash && plainPhone) {
      updates.push(`"phoneLookupHash" = ?`);
      params.push(lookupHash(plainPhone));
    }

    if (!updates.length) {
      skipped += 1;
      continue;
    }

    params.push(user.id);

    await run(
      `UPDATE public."User"
       SET ${updates.join(', ')}
       WHERE id = ?`,
      params
    );

    migrated += 1;
  }

  return { migrated, skipped };
}

async function migrateLawyerProfiles() {
  const profiles = await all(
    `SELECT * FROM public."LawyerProfile" ORDER BY "submittedAt" ASC`
  );

  let migrated = 0;
  let skipped = 0;

  for (const profile of profiles) {
    const plainEnrolment = normalizeText(profile.enrolmentNumber);
    const plainBaslId = normalizeText(profile.baslId);

    const updates = [];
    const params = [];

    if (!profile.enrolmentNumberCiphertext && plainEnrolment) {
      updates.push(`"enrolmentNumberCiphertext" = ?`);
      params.push(encryptText(plainEnrolment));
    }

    if (!profile.enrolmentNumberLookupHash && plainEnrolment) {
      updates.push(`"enrolmentNumberLookupHash" = ?`);
      params.push(lookupHash(plainEnrolment));
    }

    if (!profile.baslIdCiphertext && plainBaslId) {
      updates.push(`"baslIdCiphertext" = ?`);
      params.push(encryptText(plainBaslId));
    }

    if (!profile.baslIdLookupHash && plainBaslId) {
      updates.push(`"baslIdLookupHash" = ?`);
      params.push(lookupHash(plainBaslId));
    }

    if (!updates.length) {
      skipped += 1;
      continue;
    }

    params.push(profile.id);

    await run(
      `UPDATE public."LawyerProfile"
       SET ${updates.join(', ')}
       WHERE id = ?`,
      params
    );

    migrated += 1;
  }

  return { migrated, skipped };
}

(async () => {
  try {
    const userResult = await migrateUsers();
    const lawyerResult = await migrateLawyerProfiles();

    console.log(`Users migrated: ${userResult.migrated}`);
    console.log(`Users skipped: ${userResult.skipped}`);
    console.log(`Lawyer profiles migrated: ${lawyerResult.migrated}`);
    console.log(`Lawyer profiles skipped: ${lawyerResult.skipped}`);
    console.log('Sensitive field migration completed successfully.');
    process.exit(0);
  } catch (error) {
    console.error('Sensitive field migration failed:', error.message);
    process.exit(1);
  }
})();