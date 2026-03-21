const express = require('express');
const { z } = require('zod');
const { v4: uuid } = require('uuid');

const { readLawyerPrivateFields } = require('../services/userService');
const { all, get, run } = require('../db');
const { authRequired, requireRole } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const { writeAudit } = require('../services/auditService');

const router = express.Router();

function parseArrayValue(value) {
  if (value == null) return undefined;
  if (Array.isArray(value)) {
    return value.map((item) => String(item).trim()).filter(Boolean);
  }

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return [];

    try {
      const parsed = JSON.parse(trimmed);
      if (Array.isArray(parsed)) {
        return parsed.map((item) => String(item).trim()).filter(Boolean);
      }
    } catch (_) {}

    return trimmed
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
  }

  return undefined;
}

const optionalTrimmedString = (max) =>
  z.preprocess((value) => {
    if (value == null) return undefined;
    const next = String(value).trim();
    return next.length ? next : undefined;
  }, z.string().min(1).max(max).optional());

const timeRegex = /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/;

const updateLawyerProfileSchema = z
  .object({
    firstName: optionalTrimmedString(80),
    lastName: optionalTrimmedString(80),
    bio: optionalTrimmedString(1000),
    district: optionalTrimmedString(80),
    languages: z.preprocess(parseArrayValue, z.array(z.string().min(1).max(80)).optional()),
    specializations: z.preprocess(
      parseArrayValue,
      z.array(z.string().min(1).max(120)).optional()
    ),
    fees: z.coerce.number().nonnegative().optional(),
    feesLkr: z.coerce.number().nonnegative().optional(),
  })
  .refine(
    (value) =>
      value.firstName !== undefined ||
      value.lastName !== undefined ||
      value.bio !== undefined ||
      value.district !== undefined ||
      value.languages !== undefined ||
      value.specializations !== undefined ||
      value.fees !== undefined ||
      value.feesLkr !== undefined,
    {
      message: 'At least one profile field is required.',
      path: ['firstName'],
    }
  );

const availabilitySlotSchema = z
  .object({
    dayOfWeek: z.coerce.number().int().min(0).max(6),
    startTime: z.string().regex(timeRegex, 'startTime must be HH:MM or HH:MM:SS.'),
    endTime: z.string().regex(timeRegex, 'endTime must be HH:MM or HH:MM:SS.'),
  })
  .refine((value) => value.startTime < value.endTime, {
    message: 'endTime must be after startTime.',
    path: ['endTime'],
  });

const updateAvailabilitySchema = z.object({
  slots: z.array(availabilitySlotSchema).max(100),
});

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
      return trimmed.split(',').map((item) => item.trim()).filter(Boolean);
    }
  }

  return [];
}

function mapLawyer(profile, options = {}) {
  const { includePrivate = false } = options;
  const firstName = profile?.firstName ?? '';
  const lastName = profile?.lastName ?? '';
  const fullName = [firstName, lastName].filter(Boolean).join(' ').trim();
  const privateFields = readLawyerPrivateFields(profile);

  return {
    id: profile.id,
    userId: profile.userId,
    firstName,
    lastName,
    fullName,
    bio: profile.bio ?? null,
    district: profile.district ?? '',
    languages: toArray(profile.languages),
    specializations: toArray(profile.specializations),
    feesLkr: Number(profile.fees ?? 0),
    verifiedStatus: profile.verificationStatus ?? 'PENDING',
    verified: String(profile.verificationStatus ?? '').toUpperCase() === 'APPROVED',
    ...(includePrivate
      ? {
          enrolmentNumber: privateFields.enrolmentNumber,
          baslId: privateFields.baslId,
        }
      : {}),
  };
}

router.get('/', async (req, res, next) => {
  try {
    const { specialization, district, language, q } = req.query;

    const rows = await all(
      `SELECT * FROM public."LawyerProfile"
       WHERE "verificationStatus" = ?
       ORDER BY "firstName" ASC, "lastName" ASC`,
      ['APPROVED']
    );

    const filtered = rows
      .filter((row) => {
        const specs = toArray(row.specializations);
        const langs = toArray(row.languages);
        const fullName = [row.firstName || '', row.lastName || ''].join(' ').trim();
        const text = `${fullName} ${row.bio || ''} ${specs.join(' ')} ${langs.join(' ')}`.toLowerCase();

        if (
          specialization &&
          !specs.some((item) =>
            item.toLowerCase().includes(String(specialization).toLowerCase())
          )
        ) {
          return false;
        }

        if (
          district &&
          String(row.district || '').toLowerCase() !== String(district).toLowerCase()
        ) {
          return false;
        }

        if (
          language &&
          !langs.some((item) =>
            item.toLowerCase().includes(String(language).toLowerCase())
          )
        ) {
          return false;
        }

        if (q && !text.includes(String(q).toLowerCase())) {
          return false;
        }

        return true;
      })
      .map((row) => mapLawyer(row, { includePrivate: false }));

    res.json({ items: filtered });
  } catch (error) {
    next(error);
  }
});

router.get('/me', authRequired, requireRole('lawyer'), async (req, res, next) => {
  try {
    const lawyer = await get(
      `SELECT * FROM public."LawyerProfile" WHERE "userId" = ?`,
      [req.user.id]
    );

    if (!lawyer) {
      return res.status(404).json({ error: 'Lawyer profile not found.' });
    }

    res.json({ item: mapLawyer(lawyer, { includePrivate: true }) });
  } catch (error) {
    next(error);
  }
});

router.patch(
  '/me',
  authRequired,
  requireRole('lawyer'),
  validateBody(updateLawyerProfileSchema),
  async (req, res, next) => {
    try {
      const lawyer = await get(
        `SELECT * FROM public."LawyerProfile" WHERE "userId" = ?`,
        [req.user.id]
      );

      if (!lawyer) {
        return res.status(404).json({ error: 'Lawyer profile not found.' });
      }

      const nextData = {
        firstName: req.validatedBody.firstName ?? lawyer.firstName,
        lastName: req.validatedBody.lastName ?? lawyer.lastName,
        bio: req.validatedBody.bio ?? lawyer.bio,
        district: req.validatedBody.district ?? lawyer.district,
        languages: req.validatedBody.languages ?? toArray(lawyer.languages),
        specializations:
          req.validatedBody.specializations ?? toArray(lawyer.specializations),
        fees:
          req.validatedBody.feesLkr ?? req.validatedBody.fees ?? lawyer.fees,
      };

      await run(
        `UPDATE public."LawyerProfile"
         SET "firstName" = ?, "lastName" = ?, bio = ?, district = ?, languages = ?, specializations = ?, fees = ?
         WHERE id = ?`,
        [
          nextData.firstName,
          nextData.lastName,
          nextData.bio,
          nextData.district,
          nextData.languages,
          nextData.specializations,
          Number(nextData.fees ?? 0),
          lawyer.id,
        ]
      );

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'lawyer.profile.updated',
        targetType: 'lawyer_profile',
        targetId: lawyer.id,
        ipAddress: req.ip,
      });

      const updated = await get(
        `SELECT * FROM public."LawyerProfile" WHERE id = ?`,
        [lawyer.id]
      );

      res.json({ item: mapLawyer(updated, { includePrivate: true }) });
    } catch (error) {
      next(error);
    }
  }
);

router.get('/:id', async (req, res, next) => {
  try {
    const profile = await get(
      `SELECT * FROM public."LawyerProfile" WHERE id = ?`,
      [req.params.id]
    );

    if (!profile) {
      return res.status(404).json({ error: 'Lawyer not found.' });
    }

    if (String(profile.verificationStatus || '').toUpperCase() !== 'APPROVED') {
      return res.status(404).json({ error: 'Lawyer not found.' });
    }

    res.json({ item: mapLawyer(profile, { includePrivate: false }) });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/availability', async (req, res, next) => {
  try {
    const rows = await all(
      `SELECT * FROM public."AvailabilitySlot"
       WHERE "lawyerId" = ?
       ORDER BY "dayOfWeek", "startTime"`,
      [req.params.id]
    );

    res.json({
      items: rows.map((slot) => ({
        id: slot.id,
        dayOfWeek: slot.dayOfWeek,
        startTime: slot.startTime,
        endTime: slot.endTime,
      })),
    });
  } catch (error) {
    next(error);
  }
});

router.put(
  '/me/availability',
  authRequired,
  requireRole('lawyer'),
  validateBody(updateAvailabilitySchema),
  async (req, res, next) => {
    try {
      const lawyer = await get(
        `SELECT * FROM public."LawyerProfile" WHERE "userId" = ?`,
        [req.user.id]
      );

      if (!lawyer) {
        return res.status(404).json({ error: 'Lawyer profile not found.' });
      }

      const { slots } = req.validatedBody;

      await run(
        `DELETE FROM public."AvailabilitySlot" WHERE "lawyerId" = ?`,
        [lawyer.id]
      );

      for (const slot of slots) {
        await run(
          `INSERT INTO public."AvailabilitySlot"
            (id, "lawyerId", "dayOfWeek", "startTime", "endTime", "isBooked")
           VALUES (?, ?, ?, ?, ?, FALSE)`,
          [uuid(), lawyer.id, slot.dayOfWeek, slot.startTime, slot.endTime]
        );
      }

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'lawyer.availability.updated',
        targetType: 'lawyer_profile',
        targetId: lawyer.id,
        ipAddress: req.ip,
        meta: { slotCount: slots.length },
      });

      const rows = await all(
        `SELECT * FROM public."AvailabilitySlot"
         WHERE "lawyerId" = ?
         ORDER BY "dayOfWeek", "startTime"`,
        [lawyer.id]
      );

      res.json({
        items: rows.map((slot) => ({
          id: slot.id,
          dayOfWeek: slot.dayOfWeek,
          startTime: slot.startTime,
          endTime: slot.endTime,
        })),
      });
    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;