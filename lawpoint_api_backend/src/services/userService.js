const { get } = require('../db');
const { decryptText } = require('../utils/crypto');

function toArray(value) {
  if (value == null) return [];

  if (Array.isArray(value)) return value;

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return [];

    try {
      const parsed = JSON.parse(trimmed);
      return Array.isArray(parsed) ? parsed : [parsed];
    } catch {
      return trimmed
        .split(',')
        .map((v) => v.trim())
        .filter(Boolean);
    }
  }

  return [];
}

function normalizeRole(role) {
  return String(role || '').trim().toLowerCase();
}

function normalizeStoredPlainText(value) {
  if (value == null) return null;
  const next = String(value).trim();
  return next.length ? next : null;
}

function decryptField(ciphertext, fallbackPlaintext = null) {
  if (ciphertext) {
    try {
      return decryptText(ciphertext);
    } catch (error) {
      console.error('Failed to decrypt sensitive field:', error.message);
    }
  }

  return normalizeStoredPlainText(fallbackPlaintext);
}

function readUserPrivateFields(user) {
  if (!user) {
    return {
      email: '',
      phone: '',
    };
  }

  const email = decryptField(user.emailCiphertext, user.email) || '';
  const phone = decryptField(user.phoneCiphertext, user.phone) || '';

  return { email, phone };
}

function readLawyerPrivateFields(profile) {
  if (!profile) {
    return {
      enrolmentNumber: null,
      baslId: null,
    };
  }

  const enrolmentNumber =
    decryptField(profile.enrolmentNumberCiphertext, profile.enrolmentNumber) || null;
  const baslId = decryptField(profile.baslIdCiphertext, profile.baslId) || null;

  return { enrolmentNumber, baslId };
}

async function hydrateUser(user) {
  if (!user) return null;

  const role = normalizeRole(user.role);
  const { email, phone } = readUserPrivateFields(user);

  const base = {
    id: user.id,
    role,
    status: user.status ?? null,
    isVerified: Boolean(user.isVerified),
    verified: Boolean(user.isVerified),
    email,
    phone,
    createdAt: user.createdAt ?? null,
  };

  if (role === 'client') {
    const profile = await get(
      `SELECT * FROM public."ClientProfile" WHERE "userId" = ?`,
      [user.id]
    );

    const firstName = profile?.firstName ?? '';
    const lastName = profile?.lastName ?? '';
    const fullName = [firstName, lastName].filter(Boolean).join(' ').trim();

    return {
      ...base,
      profile: profile
        ? {
            id: profile.id,
            firstName,
            lastName,
            fullName,
          }
        : null,
    };
  }

  if (role === 'lawyer') {
    const profile = await get(
      `SELECT * FROM public."LawyerProfile" WHERE "userId" = ?`,
      [user.id]
    );

    const firstName = profile?.firstName ?? '';
    const lastName = profile?.lastName ?? '';
    const fullName = [firstName, lastName].filter(Boolean).join(' ').trim();
    const privateFields = readLawyerPrivateFields(profile);

    return {
      ...base,
      profile: profile
        ? {
            id: profile.id,
            firstName,
            lastName,
            fullName,
            bio: profile.bio ?? null,
            district: profile.district ?? null,
            languages: toArray(profile.languages),
            specializations: toArray(profile.specializations),
            fees: profile.fees ?? 0,
            verificationStatus: profile.verificationStatus ?? null,
            enrolmentNumber: privateFields.enrolmentNumber,
            baslId: privateFields.baslId,
          }
        : null,
    };
  }

  return base;
}

module.exports = {
  hydrateUser,
  readUserPrivateFields,
  readLawyerPrivateFields,
};