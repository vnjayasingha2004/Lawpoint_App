const bcrypt = require('bcryptjs');
const { v4: uuid } = require('uuid');
const { get, run } = require('../db');
const { encryptText, lookupHash } = require('../utils/crypto');
const { nowIso } = require('../utils/time');

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizePhone(value) {
  const v = String(value || '').trim();
  return v.length ? v : null;
}

async function createAdmin({ email, phone, password }) {
  const normalizedEmail = normalizeEmail(email);
  const normalizedPhone = normalizePhone(phone);

  if (!normalizedEmail || !password) {
    throw new Error('email and password are required.');
  }

  let existing;

  if (normalizedPhone) {
    existing = await get(
      `SELECT * FROM public."User"
       WHERE "emailLookupHash" = ?
          OR email = ?
          OR "phoneLookupHash" = ?
          OR phone = ?`,
      [
        lookupHash(normalizedEmail),
        normalizedEmail,
        lookupHash(normalizedPhone),
        normalizedPhone,
      ]
    );
  } else {
    existing = await get(
      `SELECT * FROM public."User"
       WHERE "emailLookupHash" = ?
          OR email = ?`,
      [lookupHash(normalizedEmail), normalizedEmail]
    );
  }

  if (existing) {
    throw new Error('A user with this email or phone already exists.');
  }

  const id = uuid();
  const ts = nowIso();
  const passwordHash = await bcrypt.hash(password, 10);

  await run(
    `INSERT INTO public."User"
      (
        id,
        role,
        email,
        phone,
        "emailCiphertext",
        "emailLookupHash",
        "phoneCiphertext",
        "phoneLookupHash",
        "passwordHash",
        "isVerified",
        "createdAt",
        "updatedAt"
      )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      'ADMIN',
      normalizedEmail,
      normalizedPhone,
      encryptText(normalizedEmail),
      lookupHash(normalizedEmail),
      normalizedPhone ? encryptText(normalizedPhone) : null,
      normalizedPhone ? lookupHash(normalizedPhone) : null,
      passwordHash,
      true,
      ts,
      ts,
    ]
  );

  console.log('Admin created successfully');
  console.log('User ID:', id);
  console.log('Email:', normalizedEmail);
  console.log('Phone:', normalizedPhone || '(none)');
}

(async () => {
  try {
    const email = process.argv[2];
    const phone = process.argv[3] === 'null' ? null : process.argv[3];
    const password = process.argv[4];

    if (!email || !password) {
      console.log(
        'Usage: node src/scripts/createAdminReal.js <email> <phone-or-null> <password>'
      );
      process.exit(1);
    }

    await createAdmin({ email, phone, password });
    process.exit(0);
  } catch (error) {
    console.error('Create admin failed:', error.message);
    process.exit(1);
  }
})();