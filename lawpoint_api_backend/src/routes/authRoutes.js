const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const { v4: uuid } = require('uuid');

const { run, get } = require('../db');
const env = require('../config/env');
const { hashToken, encryptText, lookupHash } = require('../utils/crypto');
const { issueTokens } = require('../utils/tokens');
const { nowIso } = require('../utils/time');
const { authLimiter } = require('../middleware/rateLimiters');
const { authRequired } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const { hydrateUser } = require('../services/userService');
const { writeAudit } = require('../services/auditService');
const {
  sendPasswordResetEmail,
  sendVerificationEmail,
} = require('../services/mailService');
const {
  createPasswordResetCode,
  getLatestValidResetCode,
  markResetCodeUsed,
} = require('../services/passwordResetService');
const {
  createEmailVerificationCode,
  getLatestValidVerificationCode,
  markVerificationCodeUsed,
} = require('../services/emailVerificationService');

const router = express.Router();

function optionalText(max = 255) {
  return z.preprocess((value) => {
    if (value == null) return undefined;
    const next = String(value).trim();
    return next.length ? next : undefined;
  }, z.string().min(1).max(max).optional());
}

function optionalEmail() {
  return z.preprocess((value) => {
    if (value == null) return undefined;
    const next = String(value).trim().toLowerCase();
    return next.length ? next : undefined;
  }, z.string().email().max(120).optional());
}

const registerClientSchema = z
  .object({
    email: optionalEmail(),
    phone: optionalText(20),
    password: z.string().min(8).max(100),
    fullName: optionalText(120),
    district: optionalText(80),
    preferredLanguage: optionalText(40),
  })
  .refine((v) => Boolean(v.email || v.phone), {
    message: 'Either email or phone is required.',
    path: ['email'],
  });

const registerLawyerSchema = z
  .object({
    email: optionalEmail(),
    phone: optionalText(20),
    password: z.string().min(8).max(100),
    fullName: optionalText(120),
    firstName: optionalText(80),
    lastName: optionalText(80),
    district: optionalText(80),
    languages: z.any().optional(),
    specializations: z.any().optional(),
    fees: z.any().optional(),
    feesLkr: z.any().optional(),
    bio: optionalText(1000),
    enrolmentNumber: optionalText(100),
    enrolmentNo: optionalText(100),
    baslId: optionalText(100),
  })
  .refine((v) => Boolean(v.email || v.phone), {
    message: 'Either email or phone is required.',
    path: ['email'],
  })
  .refine((v) => Boolean(v.enrolmentNumber || v.enrolmentNo), {
    message: 'Enrolment number is required.',
    path: ['enrolmentNumber'],
  })
  .refine((v) => Boolean(v.baslId), {
    message: 'baslId is required.',
    path: ['baslId'],
  });

const loginSchema = z
  .object({
    identifier: optionalText(120),
    email: optionalEmail(),
    phone: optionalText(20),
    password: z.string().min(8).max(100),
  })
  .refine((v) => Boolean(v.identifier || v.email || v.phone), {
    message: 'Identifier or email/phone is required.',
    path: ['identifier'],
  });

const verifyEmailSchema = z.object({
  email: z.string().trim().email().max(120),
  code: z.string().trim().min(1).max(20),
});

const verifyOtpSchema = z
  .object({
    email: optionalEmail(),
    phone: optionalText(20),
    otp: optionalText(20),
    code: optionalText(20),
  })
  .refine((v) => Boolean(v.email || v.phone), {
    message: 'Either email or phone is required.',
    path: ['email'],
  })
  .refine((v) => Boolean(v.otp || v.code), {
    message: 'OTP code is required.',
    path: ['otp'],
  });

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

const logoutSchema = z.object({
  refreshToken: z.string().min(1),
});

const forgotPasswordSchema = z
  .object({
    identifier: optionalText(120),
    email: optionalEmail(),
    phone: optionalText(20),
  })
  .refine((v) => Boolean(v.identifier || v.email || v.phone), {
    message: 'Email or phone is required.',
    path: ['identifier'],
  });

const resetPasswordSchema = z
  .object({
    identifier: optionalText(120),
    email: optionalEmail(),
    phone: optionalText(20),
    code: z.string().trim().min(1).max(20),
    newPassword: z.string().min(8).max(100),
  })
  .refine((v) => Boolean(v.identifier || v.email || v.phone), {
    message: 'Email or phone is required.',
    path: ['identifier'],
  });

function normalizeText(value) {
  if (value == null) return null;
  const next = String(value).trim();
  return next.length === 0 ? null : next;
}

function normalizeEmail(value) {
  const next = normalizeText(value);
  return next ? next.toLowerCase() : null;
}

function normalizeStringArray(value) {
  if (value == null) return [];

  if (Array.isArray(value)) {
    return value.map((v) => String(v).trim()).filter(Boolean);
  }

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return [];

    try {
      const parsed = JSON.parse(trimmed);
      if (Array.isArray(parsed)) {
        return parsed.map((v) => String(v).trim()).filter(Boolean);
      }
    } catch (_) {}

    return trimmed
      .split(',')
      .map((v) => v.trim())
      .filter(Boolean);
  }

  return [];
}

const LAWYER_PENDING_STATUS = 'PENDING';

function normalizeRoleForDb(role) {
  switch (String(role || '').toLowerCase()) {
    case 'client':
      return 'CLIENT';
    case 'lawyer':
      return 'LAWYER';
    case 'admin':
      return 'ADMIN';
    default:
      throw new Error(`Unsupported role: ${role}`);
  }
}

function splitIdentifier(identifier) {
  const normalized = normalizeText(identifier);
  if (!normalized) {
    return { email: null, phone: null };
  }

  if (normalized.includes('@')) {
    return { email: normalized.toLowerCase(), phone: null };
  }

  return { email: null, phone: normalized };
}

async function findUserByContacts(email, phone) {
  const normalizedEmail = normalizeEmail(email);
  const normalizedPhone = normalizeText(phone);
  const emailHash = normalizedEmail ? lookupHash(normalizedEmail) : null;
  const phoneHash = normalizedPhone ? lookupHash(normalizedPhone) : null;

  const clauses = [];
  const params = [];

  if (emailHash) {
    clauses.push(`"emailLookupHash" = ?`);
    params.push(emailHash);
    clauses.push(`email = ?`);
    params.push(normalizedEmail);
  }

  if (phoneHash) {
    clauses.push(`"phoneLookupHash" = ?`);
    params.push(phoneHash);
    clauses.push(`phone = ?`);
    params.push(normalizedPhone);
  }

  if (!clauses.length) {
    return null;
  }

  return get(
    `SELECT * FROM public."User"
     WHERE ${clauses.join(' OR ')}
     LIMIT 1`,
    params
  );
}

async function findUserByEmail(email) {
  const normalizedEmail = normalizeEmail(email);
  if (!normalizedEmail) return null;

  return get(
    `SELECT * FROM public."User"
     WHERE "emailLookupHash" = ? OR email = ?
     LIMIT 1`,
    [lookupHash(normalizedEmail), normalizedEmail]
  );
}

async function findUserByPhone(phone) {
  const normalizedPhone = normalizeText(phone);
  if (!normalizedPhone) return null;

  return get(
    `SELECT * FROM public."User"
     WHERE "phoneLookupHash" = ? OR phone = ?
     LIMIT 1`,
    [lookupHash(normalizedPhone), normalizedPhone]
  );
}

async function findLawyerByCredentials(enrolmentNumber, baslId) {
  const normalizedEnrolment = normalizeText(enrolmentNumber);
  const normalizedBaslId = normalizeText(baslId);

  const clauses = [];
  const params = [];

  if (normalizedEnrolment) {
    clauses.push(`"enrolmentNumberLookupHash" = ?`);
    params.push(lookupHash(normalizedEnrolment));
    clauses.push(`"enrolmentNumber" = ?`);
    params.push(normalizedEnrolment);
  }

  if (normalizedBaslId) {
    clauses.push(`"baslIdLookupHash" = ?`);
    params.push(lookupHash(normalizedBaslId));
    clauses.push(`"baslId" = ?`);
    params.push(normalizedBaslId);
  }

  if (!clauses.length) return null;

  return get(
    `SELECT * FROM public."LawyerProfile"
     WHERE ${clauses.join(' OR ')}
     LIMIT 1`,
    params
  );
}

async function findUserByEmail(email) {
  const normalizedEmail = normalizeEmail(email);
  if (!normalizedEmail) return null;

  return get(
    `SELECT * FROM public."User"
     WHERE "emailLookupHash" = ? OR email = ?
     LIMIT 1`,
    [lookupHash(normalizedEmail), normalizedEmail]
  );
}

async function findUserByPhone(phone) {
  const normalizedPhone = normalizeText(phone);
  if (!normalizedPhone) return null;

  return get(
    `SELECT * FROM public."User"
     WHERE "phoneLookupHash" = ? OR phone = ?
     LIMIT 1`,
    [lookupHash(normalizedPhone), normalizedPhone]
  );
}

async function findLawyerByCredentials(enrolmentNumber, baslId) {
  const normalizedEnrolment = normalizeText(enrolmentNumber);
  const normalizedBaslId = normalizeText(baslId);

  const clauses = [];
  const params = [];

  if (normalizedEnrolment) {
    clauses.push(`"enrolmentNumberLookupHash" = ?`);
    params.push(lookupHash(normalizedEnrolment));
    clauses.push(`"enrolmentNumber" = ?`);
    params.push(normalizedEnrolment);
  }

  if (normalizedBaslId) {
    clauses.push(`"baslIdLookupHash" = ?`);
    params.push(lookupHash(normalizedBaslId));
    clauses.push(`"baslId" = ?`);
    params.push(normalizedBaslId);
  }

  if (!clauses.length) return null;

  return get(
    `SELECT * FROM public."LawyerProfile"
     WHERE ${clauses.join(' OR ')}
     LIMIT 1`,
    params
  );
}

async function createUser({
  role,
  email,
  phone,
  password,
  profile = {},
  lawyerCredentials = {},
  ip,
}) {
  const normalizedEmail = normalizeEmail(email);
  const normalizedPhone = normalizeText(phone);

  if (!normalizedEmail && !normalizedPhone) {
    return {
      status: 400,
      body: { error: 'Either email or phone is required.' },
    };
  }

  const existing = await findUserByContacts(normalizedEmail, normalizedPhone);
  if (existing) {
    return {
      status: 409,
      body: { error: 'An account with that email or phone already exists.' },
    };
  }

  const userId = uuid();
  const createdAt = nowIso();
  const passwordHash = await bcrypt.hash(password, 10);
  const dbRole = normalizeRoleForDb(role);

  const emailCiphertext = normalizedEmail ? encryptText(normalizedEmail) : null;
  const phoneCiphertext = normalizedPhone ? encryptText(normalizedPhone) : null;
  const emailLookupHash = normalizedEmail ? lookupHash(normalizedEmail) : null;
  const phoneLookupHash = normalizedPhone ? lookupHash(normalizedPhone) : null;

  const enrolmentValue = normalizeText(
    lawyerCredentials.enrolmentNumber || lawyerCredentials.enrolmentNo
  );
  const baslValue = normalizeText(lawyerCredentials.baslId);

  if (String(role).toLowerCase() === 'lawyer') {
    const existingLawyerCredentials = await findLawyerByCredentials(
      enrolmentValue,
      baslValue
    );

    if (existingLawyerCredentials) {
      return {
        status: 409,
        body: {
          error: 'A lawyer with that enrolment number or BASL ID already exists.',
        },
      };
    }
  }

  try {
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
        userId,
        dbRole,
        normalizedEmail,
        normalizedPhone,
        emailCiphertext,
        emailLookupHash,
        phoneCiphertext,
        phoneLookupHash,
        passwordHash,
        false,
        createdAt,
        createdAt,
      ]
    );

    const { code } = await createEmailVerificationCode(userId);

    if (String(role).toLowerCase() === 'client') {
      const fullName =
        normalizeText(profile.fullName) ||
        [normalizeText(profile.firstName), normalizeText(profile.lastName)]
          .filter(Boolean)
          .join(' ') ||
        'New User';

      const parts = fullName.split(/\s+/);
      const firstName = parts[0] || 'New';
      const lastName = parts.slice(1).join(' ') || 'User';

      await run(
        `INSERT INTO public."ClientProfile"
          (id, "userId", "firstName", "lastName")
         VALUES (?, ?, ?, ?)`,
        [uuid(), userId, firstName, lastName]
      );
    }

    if (String(role).toLowerCase() === 'lawyer') {
      const specializations = normalizeStringArray(profile.specializations);
      const languages = normalizeStringArray(profile.languages);

      const firstName =
        normalizeText(profile.firstName) ||
        normalizeText(profile.fullName)?.split(/\s+/)[0] ||
        'New';

      const lastName =
        normalizeText(profile.lastName) ||
        normalizeText(profile.fullName)?.split(/\s+/).slice(1).join(' ') ||
        'Lawyer';

      await run(
        `INSERT INTO public."LawyerProfile"
          (
            id,
            "userId",
            "firstName",
            "lastName",
            specializations,
            languages,
            district,
            fees,
            bio,
            "verificationStatus",
            "enrolmentNumber",
            "baslId",
            "enrolmentNumberCiphertext",
            "enrolmentNumberLookupHash",
            "baslIdCiphertext",
            "baslIdLookupHash"
          )
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          uuid(),
          userId,
          firstName,
          lastName,
          specializations,
          languages,
          normalizeText(profile.district),
          Number(profile.fees ?? profile.feesLkr ?? 0),
          normalizeText(profile.bio),
          LAWYER_PENDING_STATUS,
          enrolmentValue,
          baslValue,
          enrolmentValue ? encryptText(enrolmentValue) : null,
          enrolmentValue ? lookupHash(enrolmentValue) : null,
          baslValue ? encryptText(baslValue) : null,
          baslValue ? lookupHash(baslValue) : null,
        ]
      );
    }

    await writeAudit({
      actorUserId: userId,
      eventType: `${String(role).toLowerCase()}.registered`,
      targetType: 'user',
      targetId: userId,
      ipAddress: ip,
    });

    const user = await get(
      `SELECT * FROM public."User" WHERE id = ?`,
      [userId]
    );

    const hydratedUser = await hydrateUser(user);

    if (normalizedEmail) {
      sendVerificationEmail({
        to: normalizedEmail,
        code,
      }).catch((error) => {
        console.error('Failed to send verification email:', error);
      });
    }

    return {
      status: 201,
      body: {
        message: 'Registration successful. Please verify your email.',
        otpRequired: true,
        user: hydratedUser,
      },
    };
  } catch (error) {
    await Promise.allSettled([
      run(`DELETE FROM public."EmailVerificationCode" WHERE "userId" = ?`, [
        userId,
      ]),
      run(`DELETE FROM public."ClientProfile" WHERE "userId" = ?`, [userId]),
      run(`DELETE FROM public."LawyerProfile" WHERE "userId" = ?`, [userId]),
      run(`DELETE FROM public."RefreshToken" WHERE "userId" = ?`, [userId]),
      run(`DELETE FROM public."User" WHERE id = ?`, [userId]),
    ]);

    throw error;
  }
}

router.post(
  '/register-client',
  authLimiter,
  validateBody(registerClientSchema),
  async (req, res, next) => {
    try {
      const { email, phone, password, fullName, district, preferredLanguage } =
        req.validatedBody;

      const result = await createUser({
        role: 'client',
        email,
        phone,
        password,
        profile: { fullName, district, preferredLanguage },
        ip: req.ip,
      });

      return res.status(result.status).json(result.body);
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/register-lawyer',
  authLimiter,
  validateBody(registerLawyerSchema),
  async (req, res, next) => {
    try {
      const {
        email,
        phone,
        password,
        fullName,
        firstName,
        lastName,
        district,
        languages,
        specializations,
        fees,
        feesLkr,
        bio,
        enrolmentNumber,
        enrolmentNo,
        baslId,
      } = req.validatedBody;

      const result = await createUser({
        role: 'lawyer',
        email,
        phone,
        password,
        profile: {
          fullName,
          firstName,
          lastName,
          district,
          languages,
          specializations,
          fees,
          feesLkr,
          bio,
        },
        lawyerCredentials: {
          enrolmentNumber,
          enrolmentNo,
          baslId,
        },
        ip: req.ip,
      });

      return res.status(result.status).json(result.body);
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/verify-email',
  authLimiter,
  validateBody(verifyEmailSchema),
  async (req, res, next) => {
    try {
      const { email, code } = req.validatedBody;

      const user = await findUserByEmail(email);
      
      if (!user) {
        return res.status(404).json({ error: 'User not found.' });
      }

      const record = await getLatestValidVerificationCode(
        user.id,
        String(code).trim()
      );

      if (!record) {
        return res.status(400).json({
          error: 'Invalid or expired verification code.',
        });
      }

      await run(
        `UPDATE public."User"
         SET "isVerified" = ?, "updatedAt" = ?
         WHERE id = ?`,
        [true, nowIso(), user.id]
      );

      await markVerificationCodeUsed(record.id);

      await writeAudit({
        actorUserId: user.id,
        eventType: 'auth.email_verified',
        targetType: 'user',
        targetId: user.id,
        ipAddress: req.ip,
      });

      return res.json({
        ok: true,
        message: 'Email verified successfully.',
      });
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/verify-otp',
  authLimiter,
  validateBody(verifyOtpSchema),
  async (req, res, next) => {
    try {
      const { email, phone, otp, code } = req.validatedBody;

      const submittedCode = String(otp || code || '').trim();
      const user = await findUserByContacts(email, phone);

      if (!user) {
        return res.status(404).json({ error: 'User not found.' });
      }

      const record = await getLatestValidVerificationCode(user.id, submittedCode);

      if (!record) {
        return res.status(400).json({
          error: 'Invalid or expired verification code.',
        });
      }

      await run(
        `UPDATE public."User"
         SET "isVerified" = ?, "updatedAt" = ?
         WHERE id = ?`,
        [true, nowIso(), user.id]
      );

      await markVerificationCodeUsed(record.id);

      await writeAudit({
        actorUserId: user.id,
        eventType: 'auth.otp_verified',
        targetType: 'user',
        targetId: user.id,
        ipAddress: req.ip,
      });

      return res.json({
        ok: true,
        message: 'OTP verified successfully.',
      });
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/login',
  authLimiter,
  validateBody(loginSchema),
  async (req, res, next) => {
    try {
      const { identifier, email, phone, password } = req.validatedBody;

      const parsed = splitIdentifier(identifier);
      const loginEmail = normalizeEmail(email || parsed.email);
      const loginPhone = normalizeText(phone || parsed.phone);

      const user = await findUserByContacts(loginEmail, loginPhone);

      if (!user) {
        await writeAudit({
          actorUserId: null,
          eventType: 'auth.login_failed',
          targetType: 'user',
          targetId: null,
          ipAddress: req.ip,
        });

        return res.status(401).json({ error: 'Invalid credentials.' });
      }

      const match = await bcrypt.compare(password, user.passwordHash);

      if (!match) {
        await writeAudit({
          actorUserId: null,
          eventType: 'auth.login_failed',
          targetType: 'user',
          targetId: null,
          ipAddress: req.ip,
        });

        return res.status(401).json({ error: 'Invalid credentials.' });
      }

      if (!user.isVerified) {
        return res.status(403).json({
          error: 'Email verification required.',
        });
      }

      const tokens = await issueTokens(user);
      const hydrated = await hydrateUser(user);

      await writeAudit({
        actorUserId: user.id,
        eventType: 'auth.login_succeeded',
        targetType: 'user',
        targetId: user.id,
        ipAddress: req.ip,
      });

      return res.json({
        ...tokens,
        user: hydrated,
      });
    } catch (error) {
      next(error);
    }
  }
);

router.post('/refresh', validateBody(refreshSchema), async (req, res, next) => {
  try {
    const { refreshToken } = req.validatedBody;

    const payload = jwt.verify(refreshToken, env.jwtRefreshSecret);

    if (payload.type !== 'refresh') {
      return res.status(401).json({
        error: 'Invalid refresh token type.',
      });
    }

    const tokenHash = hashToken(refreshToken);

    const stored = await get(
      `SELECT *
       FROM public."RefreshToken"
       WHERE "userId" = ?
         AND "tokenHash" = ?
         AND "revokedAt" IS NULL
         AND "expiresAt" > NOW()`,
      [payload.sub, tokenHash]
    );

    if (!stored) {
      return res.status(401).json({
        error: 'Refresh token not recognized.',
      });
    }

    await run(
      `UPDATE public."RefreshToken"
       SET "revokedAt" = ?
       WHERE id = ?`,
      [nowIso(), stored.id]
    );

    const user = await get(
      `SELECT * FROM public."User" WHERE id = ?`,
      [payload.sub]
    );

    if (!user) {
      return res.status(401).json({ error: 'User not found.' });
    }

    const tokens = await issueTokens(user);
    return res.json(tokens);
  } catch (error) {
    return res.status(401).json({
      error: 'Invalid or expired refresh token.',
    });
  }
});

router.post(
  '/logout',
  authRequired,
  validateBody(logoutSchema),
  async (req, res, next) => {
    try {
      const { refreshToken } = req.validatedBody;

      await run(
        `UPDATE public."RefreshToken"
         SET "revokedAt" = ?
         WHERE "tokenHash" = ?`,
        [nowIso(), hashToken(refreshToken)]
      );

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'auth.logout',
        targetType: 'user',
        targetId: req.user.id,
        ipAddress: req.ip,
      });

      return res.json({ message: 'Logged out successfully.' });
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/forgot-password',
  authLimiter,
  validateBody(forgotPasswordSchema),
  async (req, res, next) => {
    try {
      const { identifier, email, phone } = req.validatedBody;

      const parsed = splitIdentifier(identifier);
      const lookupEmail = normalizeEmail(email || parsed.email);
      const lookupPhone = normalizeText(phone || parsed.phone);

      let user = null;

      if (lookupEmail) {
  user = await findUserByEmail(lookupEmail);
}

if (!user && lookupPhone) {
  user = await findUserByPhone(lookupPhone);
}

      if (!user) {
        return res.json({
          ok: true,
          message: 'If an account exists, a reset code has been sent.',
        });
      }

      const { code, expiresAt } = await createPasswordResetCode(user.id);

      if (lookupEmail) {
        sendPasswordResetEmail({
          to: lookupEmail,
          code,
        }).catch((error) => {
          console.error('Failed to send password reset email:', error);
        });
      }

      return res.json({
        ok: true,
        message: 'If an account exists, a reset code has been sent.',
        expiresAt,
      });
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/reset-password',
  authLimiter,
  validateBody(resetPasswordSchema),
  async (req, res, next) => {
    try {
      const { identifier, email, phone, code, newPassword } = req.validatedBody;

      const parsed = splitIdentifier(identifier);
      const lookupEmail = normalizeEmail(email || parsed.email);
      const lookupPhone = normalizeText(phone || parsed.phone);

      let user = null;

      if (lookupEmail) {
  user = await findUserByEmail(lookupEmail);
}

if (!user && lookupPhone) {
  user = await findUserByPhone(lookupPhone);
}

      if (!user) {
        return res.status(400).json({ error: 'Invalid reset request.' });
      }

      const resetRecord = await getLatestValidResetCode(
        user.id,
        String(code).trim()
      );

      if (!resetRecord) {
        return res.status(400).json({
          error: 'Invalid or expired reset code.',
        });
      }

      const newPasswordHash = await bcrypt.hash(newPassword, 10);

      await run(
        `UPDATE public."User"
         SET "passwordHash" = ?, "updatedAt" = ?
         WHERE id = ?`,
        [newPasswordHash, nowIso(), user.id]
      );

      await markResetCodeUsed(resetRecord.id);

      return res.json({
        ok: true,
        message: 'Password has been reset successfully.',
      });
    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;