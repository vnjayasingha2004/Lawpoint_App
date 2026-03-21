const express = require('express');
const { z } = require('zod');
const { v4: uuid } = require('uuid');

const { all, get, run } = require('../db');
const { authRequired, requireRole } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const { createAppointmentSchema } = require('../validation/schemas');
const { nowIso } = require('../utils/time');
const { writeAudit } = require('../services/auditService');
const { createNotification } = require('../services/notificationService');

const router = express.Router();

const updateAppointmentSchema = z
  .object({
    status: z.enum(['SCHEDULED', 'COMPLETED', 'CANCELLED']).optional(),
    startAt: z.string().datetime().optional(),
    endAt: z.string().datetime().optional(),
  })
  .refine(
    (value) =>
      value.status !== undefined ||
      value.startAt !== undefined ||
      value.endAt !== undefined,
    {
      message: 'At least one of status, startAt, or endAt is required.',
      path: ['status'],
    }
  );

async function getClientProfileId(userId) {
  const profile = await get(
    `SELECT * FROM public."ClientProfile" WHERE "userId" = ?`,
    [userId]
  );
  return profile ? profile.id : null;
}

async function getLawyerProfileId(userId) {
  const profile = await get(
    `SELECT * FROM public."LawyerProfile" WHERE "userId" = ?`,
    [userId]
  );
  return profile ? profile.id : null;
}

function mapAppointment(row) {
  return {
    id: row.id,
    clientId: row.clientId,
    lawyerId: row.lawyerId,
    startAt: row.startTime,
    endAt: row.endTime,
    status: row.status,
    videoSessionId: row.videoSessionId,
    paymentStatus: row.paymentStatus,
    amount: row.amount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

function sameCalendarDay(a, b) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

function toMinutes(date) {
  return date.getHours() * 60 + date.getMinutes();
}

function parseTimeToMinutes(value) {
  const parts = String(value || '').split(':');
  if (parts.length < 2) return null;

  const hours = Number(parts[0]);
  const minutes = Number(parts[1]);

  if (Number.isNaN(hours) || Number.isNaN(minutes)) return null;
  return hours * 60 + minutes;
}

async function validateAppointmentWindow({
  lawyerId,
  startAt,
  endAt,
  excludeAppointmentId = null,
}) {
  const start = new Date(startAt);
  const end = new Date(endAt);
  const now = new Date();

  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    return {
      ok: false,
      status: 400,
      error: 'Valid startAt and endAt are required.',
    };
  }

  if (end <= start) {
    return { ok: false, status: 400, error: 'endAt must be after startAt.' };
  }

  if (start <= now) {
    return {
      ok: false,
      status: 400,
      error: 'Appointments must be booked in the future.',
    };
  }

  if (!sameCalendarDay(start, end)) {
    return {
      ok: false,
      status: 400,
      error: 'Appointment must start and end on the same day.',
    };
  }

  const dayOfWeek = start.getDay();

  const slots = await all(
    `SELECT *
     FROM public."AvailabilitySlot"
     WHERE "lawyerId" = ?
       AND "dayOfWeek" = ?
     ORDER BY "startTime"`,
    [lawyerId, dayOfWeek]
  );

  if (!slots.length) {
    return {
      ok: false,
      status: 409,
      error: 'The lawyer has no availability on that day.',
    };
  }

  const startMinutes = toMinutes(start);
  const endMinutes = toMinutes(end);

  const withinAvailability = slots.some((slot) => {
    const slotStart = parseTimeToMinutes(slot.startTime);
    const slotEnd = parseTimeToMinutes(slot.endTime);

    if (slotStart == null || slotEnd == null) return false;

    return startMinutes >= slotStart && endMinutes <= slotEnd;
  });

  if (!withinAvailability) {
    return {
      ok: false,
      status: 409,
      error: 'Selected slot is outside the lawyer availability.',
    };
  }

  const conflict = excludeAppointmentId
    ? await get(
        `SELECT *
         FROM public."Appointment"
         WHERE "lawyerId" = ?
           AND status = 'SCHEDULED'
           AND id != ?
           AND NOT ("endTime" <= ? OR "startTime" >= ?)`,
        [lawyerId, excludeAppointmentId, startAt, endAt]
      )
    : await get(
        `SELECT *
         FROM public."Appointment"
         WHERE "lawyerId" = ?
           AND status = 'SCHEDULED'
           AND NOT ("endTime" <= ? OR "startTime" >= ?)`,
        [lawyerId, startAt, endAt]
      );

  if (conflict) {
    return {
      ok: false,
      status: 409,
      error: 'Selected slot is already booked.',
    };
  }

  return { ok: true };
}

router.get('/', authRequired, async (req, res, next) => {
  try {
    let rows = [];

    if (req.user.role === 'client') {
      const clientId = await getClientProfileId(req.user.id);
      rows = await all(
        `SELECT * FROM public."Appointment"
         WHERE "clientId" = ?
         ORDER BY "startTime" DESC`,
        [clientId]
      );
    } else if (req.user.role === 'lawyer') {
      const lawyerId = await getLawyerProfileId(req.user.id);
      rows = await all(
        `SELECT * FROM public."Appointment"
         WHERE "lawyerId" = ?
         ORDER BY "startTime" DESC`,
        [lawyerId]
      );
    } else {
      rows = await all(
        `SELECT * FROM public."Appointment"
         ORDER BY "startTime" DESC`
      );
    }

    res.json({ items: rows.map(mapAppointment) });
  } catch (error) {
    next(error);
  }
});

router.post(
  '/',
  authRequired,
  requireRole('client'),
  validateBody(createAppointmentSchema),
  async (req, res, next) => {
    try {
      const clientId = await getClientProfileId(req.user.id);
      const { lawyerId, startAt, endAt } = req.validatedBody;

      if (!clientId) {
        return res.status(400).json({ error: 'Client profile not found.' });
      }

      const lawyer = await get(
        `SELECT * FROM public."LawyerProfile" WHERE id = ?`,
        [lawyerId]
      );

      if (
        !lawyer ||
        String(lawyer.verificationStatus || '').toUpperCase() !== 'APPROVED'
      ) {
        return res.status(400).json({
          error: 'Lawyer is not available for booking.',
        });
      }

      const validation = await validateAppointmentWindow({
        lawyerId,
        startAt,
        endAt,
      });

      if (!validation.ok) {
        return res.status(validation.status).json({ error: validation.error });
      }

      const id = uuid();
      const createdAt = nowIso();

      await run(
        `INSERT INTO public."Appointment"
          (id, "clientId", "lawyerId", "startTime", "endTime", status, "videoSessionId", "paymentStatus", amount, "createdAt", "updatedAt")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          id,
          clientId,
          lawyerId,
          startAt,
          endAt,
          'SCHEDULED',
          null,
          'PENDING',
          Number(lawyer.fees || 0),
          createdAt,
          createdAt,
        ]
      );

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'appointment.booked',
        targetType: 'appointment',
        targetId: id,
        ipAddress: req.ip,
      });

      const appointment = await get(
        `SELECT * FROM public."Appointment" WHERE id = ?`,
        [id]
      );

      const clientUser = await get(
        `SELECT "userId" FROM public."ClientProfile" WHERE id = ?`,
        [appointment.clientId]
      );

      const lawyerUser = await get(
        `SELECT "userId" FROM public."LawyerProfile" WHERE id = ?`,
        [appointment.lawyerId]
      );

      if (clientUser?.userId) {
        await createNotification({
          userId: clientUser.userId,
          type: 'appointment.booked',
          title: 'Appointment booked',
          body: 'Your appointment has been scheduled successfully.',
          data: {
            appointmentId: appointment.id,
            screen: 'appointment',
          },
        });
      }

      if (lawyerUser?.userId) {
        await createNotification({
          userId: lawyerUser.userId,
          type: 'appointment.booked',
          title: 'New appointment booked',
          body: 'A client booked an appointment with you.',
          data: {
            appointmentId: appointment.id,
            screen: 'appointment',
          },
        });
      }

      res.status(201).json({ item: mapAppointment(appointment) });
    } catch (error) {
      next(error);
    }
  }
);

router.patch(
  '/:id',
  authRequired,
  validateBody(updateAppointmentSchema),
  async (req, res, next) => {
    try {
      const appointment = await get(
        `SELECT * FROM public."Appointment" WHERE id = ?`,
        [req.params.id]
      );

      if (!appointment) {
        return res.status(404).json({ error: 'Appointment not found.' });
      }

      const clientId =
        req.user.role === 'client' ? await getClientProfileId(req.user.id) : null;
      const lawyerId =
        req.user.role === 'lawyer' ? await getLawyerProfileId(req.user.id) : null;
      const isAdmin = req.user.role === 'admin';

      const isAllowed =
        isAdmin ||
        appointment.clientId === clientId ||
        appointment.lawyerId === lawyerId;

      if (!isAllowed) {
        return res.status(403).json({ error: 'Forbidden.' });
      }

      const { status, startAt, endAt } = req.validatedBody;

      const nextStatus = status ?? appointment.status;
      const nextStartAt = startAt ?? appointment.startTime;
      const nextEndAt = endAt ?? appointment.endTime;

      const windowChanged =
        nextStartAt !== appointment.startTime || nextEndAt !== appointment.endTime;

      if (
        (appointment.status === 'COMPLETED' ||
          appointment.status === 'CANCELLED') &&
        windowChanged
      ) {
        return res.status(400).json({
          error: 'Completed or cancelled appointments cannot be rescheduled.',
        });
      }

      if (windowChanged && nextStatus !== 'CANCELLED') {
        const validation = await validateAppointmentWindow({
          lawyerId: appointment.lawyerId,
          startAt: nextStartAt,
          endAt: nextEndAt,
          excludeAppointmentId: appointment.id,
        });

        if (!validation.ok) {
          return res.status(validation.status).json({ error: validation.error });
        }
      }

      await run(
        `UPDATE public."Appointment"
         SET status = ?, "startTime" = ?, "endTime" = ?, "updatedAt" = ?
         WHERE id = ?`,
        [nextStatus, nextStartAt, nextEndAt, nowIso(), appointment.id]
      );

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'appointment.updated',
        targetType: 'appointment',
        targetId: appointment.id,
        ipAddress: req.ip,
        meta: { status: nextStatus },
      });

      const updated = await get(
        `SELECT * FROM public."Appointment" WHERE id = ?`,
        [appointment.id]
      );

      const clientUser = await get(
        `SELECT "userId" FROM public."ClientProfile" WHERE id = ?`,
        [updated.clientId]
      );

      const lawyerUser = await get(
        `SELECT "userId" FROM public."LawyerProfile" WHERE id = ?`,
        [updated.lawyerId]
      );

      const notificationType =
        updated.status === 'CANCELLED'
          ? 'appointment.cancelled'
          : windowChanged
          ? 'appointment.rescheduled'
          : 'appointment.updated';

      const notificationBody =
        updated.status === 'CANCELLED'
          ? 'An appointment was cancelled.'
          : windowChanged
          ? 'An appointment was rescheduled.'
          : 'Your appointment was updated.';

      if (clientUser?.userId) {
        await createNotification({
          userId: clientUser.userId,
          type: notificationType,
          title: 'Appointment update',
          body: notificationBody,
          data: {
            appointmentId: updated.id,
            screen: 'appointment',
          },
        });
      }

      if (lawyerUser?.userId) {
        await createNotification({
          userId: lawyerUser.userId,
          type: notificationType,
          title: 'Appointment update',
          body: notificationBody,
          data: {
            appointmentId: updated.id,
            screen: 'appointment',
          },
        });
      }

      res.json({ item: mapAppointment(updated) });
    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;