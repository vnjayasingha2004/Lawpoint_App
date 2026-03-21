const express = require('express');

const { readLawyerPrivateFields, readUserPrivateFields } = require('../services/userService');
const { all, get, run } = require('../db');
const { authRequired, requireRole } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const { nowIso } = require('../utils/time');
const { writeAudit } = require('../services/auditService');
const { createNotification } = require('../services/notificationService');
const { rejectVerificationSchema } = require('../validation/schemas');

const router = express.Router();

router.use(authRequired, requireRole('admin'));

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
        .map((item) => item.trim())
        .filter(Boolean);
    }
  }

  return [];
}

function mapQueueItem(row) {
  const userFields = readUserPrivateFields({
    email: row.email,
    phone: row.phone,
    emailCiphertext: row.emailCiphertext,
    phoneCiphertext: row.phoneCiphertext,
  });
  const lawyerFields = readLawyerPrivateFields(row);

  return {
    id: row.id,
    userId: row.userId,
    firstName: row.firstName,
    lastName: row.lastName,
    fullName: [row.firstName, row.lastName].filter(Boolean).join(' ').trim(),
    email: userFields.email,
    phone: userFields.phone,
    district: row.district ?? '',
    languages: toArray(row.languages),
    specializations: toArray(row.specializations),
    feesLkr: Number(row.fees ?? 0),
    bio: row.bio ?? '',
    verificationStatus: row.verificationStatus ?? 'PENDING',
    enrolmentNumber: lawyerFields.enrolmentNumber ?? '',
    baslId: lawyerFields.baslId ?? '',
    submittedAt: row.submittedAt ?? null,
    verificationReason: row.verificationReason ?? null,
    verificationDecidedAt: row.verificationDecidedAt ?? null,
    verificationDecidedBy: row.verificationDecidedBy ?? null,
  };
}

async function getLawyerQueueItem(lawyerId) {
  return get(
    `SELECT
       lp.*,
       u.email,
       u.phone,
       u."emailCiphertext",
       u."phoneCiphertext"
     FROM public."LawyerProfile" lp
     JOIN public."User" u ON u.id = lp."userId"
     WHERE lp.id = ?`,
    [lawyerId]
  );
}

router.get('/ping', (req, res) => {
  res.json({ ok: true, area: 'admin' });
});

router.get('/verification-queue', async (req, res, next) => {
  try {
    const items = await all(
  `SELECT
     lp.*,
     u.email,
     u.phone,
     u."emailCiphertext",
     u."phoneCiphertext"
   FROM public."LawyerProfile" lp
   JOIN public."User" u ON u.id = lp."userId"
   WHERE lp."verificationStatus" = ?
   ORDER BY lp."submittedAt" ASC, lp."firstName" ASC, lp."lastName" ASC`,
  ['PENDING']
);

    res.json({ items: items.map(mapQueueItem) });
  } catch (error) {
    next(error);
  }
});

router.get('/lawyers/:lawyerId', async (req, res, next) => {
  try {
    const row = await getLawyerQueueItem(req.params.lawyerId);

    if (!row) {
      return res.status(404).json({ error: 'Lawyer profile not found.' });
    }

    res.json({ item: mapQueueItem(row) });
  } catch (error) {
    next(error);
  }
});

router.post('/verification-queue/:lawyerId/approve', async (req, res, next) => {
  try {
    const profile = await get(
      `SELECT *
       FROM public."LawyerProfile"
       WHERE id = ?`,
      [req.params.lawyerId]
    );

    if (!profile) {
      return res.status(404).json({ error: 'Lawyer profile not found.' });
    }

    const now = nowIso();

    await run(
      `UPDATE public."LawyerProfile"
       SET "verificationStatus" = ?,
           "verificationReason" = ?,
           "verificationDecidedAt" = ?,
           "verificationDecidedBy" = ?
       WHERE id = ?`,
      ['APPROVED', null, now, req.user.id, profile.id]
    );

    await createNotification({
      userId: profile.userId,
      type: 'verification.approved',
      title: 'Verification approved',
      body: 'Your lawyer profile is now approved and publicly searchable.',
      data: {
        lawyerId: profile.id,
        screen: 'profile',
      },
    });

    await writeAudit({
      actorUserId: req.user.id,
      eventType: 'verification.approved',
      targetType: 'lawyer_profile',
      targetId: profile.id,
      ipAddress: req.ip,
    });

    const updated = await getLawyerQueueItem(profile.id);
    res.json({ item: mapQueueItem(updated) });
  } catch (error) {
    next(error);
  }
});

router.post(
  '/verification-queue/:lawyerId/reject',
  validateBody(rejectVerificationSchema),
  async (req, res, next) => {
    try {
      const { reason } = req.validatedBody;

      const profile = await get(
        `SELECT *
         FROM public."LawyerProfile"
         WHERE id = ?`,
        [req.params.lawyerId]
      );

      if (!profile) {
        return res.status(404).json({ error: 'Lawyer profile not found.' });
      }

      const now = nowIso();

      await run(
        `UPDATE public."LawyerProfile"
         SET "verificationStatus" = ?,
             "verificationReason" = ?,
             "verificationDecidedAt" = ?,
             "verificationDecidedBy" = ?
         WHERE id = ?`,
        ['REJECTED', reason, now, req.user.id, profile.id]
      );

      await createNotification({
        userId: profile.userId,
        type: 'verification.rejected',
        title: 'Verification rejected',
        body: reason,
        data: {
          lawyerId: profile.id,
          screen: 'profile',
        },
      });

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'verification.rejected',
        targetType: 'lawyer_profile',
        targetId: profile.id,
        ipAddress: req.ip,
      });

      const updated = await getLawyerQueueItem(profile.id);
      res.json({ item: mapQueueItem(updated) });
    } catch (error) {
      next(error);
    }
  }
);

router.get('/analytics', async (req, res, next) => {
  try {
    const [
      totalUsersRow,
      totalClientsRow,
      activeLawyersRow,
      pendingVerificationsRow,
      totalBookingsRow,
      scheduledBookingsRow,
      activeUsersRow,
    ] = await Promise.all([
      get(`SELECT COUNT(*)::int AS count FROM public."User"`),
      get(`SELECT COUNT(*)::int AS count FROM public."User" WHERE role = 'CLIENT'`),
      get(
        `SELECT COUNT(*)::int AS count
         FROM public."LawyerProfile"
         WHERE "verificationStatus" = ?`,
        ['APPROVED']
      ),
      get(
        `SELECT COUNT(*)::int AS count
         FROM public."LawyerProfile"
         WHERE "verificationStatus" = ?`,
        ['PENDING']
      ),
      get(`SELECT COUNT(*)::int AS count FROM public."Appointment"`),
      get(
        `SELECT COUNT(*)::int AS count
         FROM public."Appointment"
         WHERE status = 'SCHEDULED'`
      ),
      get(
        `SELECT COUNT(DISTINCT "userId")::int AS count
         FROM public."RefreshToken"
         WHERE "revokedAt" IS NULL
           AND "expiresAt" > NOW()`
      ),
    ]);

    res.json({
      totalUsers: Number(totalUsersRow?.count || 0),
      totalClients: Number(totalClientsRow?.count || 0),
      activeLawyers: Number(activeLawyersRow?.count || 0),
      pendingVerifications: Number(pendingVerificationsRow?.count || 0),
      totalBookings: Number(totalBookingsRow?.count || 0),
      scheduledBookings: Number(scheduledBookingsRow?.count || 0),
      activeUsers: Number(activeUsersRow?.count || 0),
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;