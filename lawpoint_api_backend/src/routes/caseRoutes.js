const express = require('express');
const { z } = require('zod');
const { v4: uuid } = require('uuid');

const { all, get, run } = require('../db');
const { authRequired } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const { nowIso } = require('../utils/time');
const { writeAudit } = require('../services/auditService');
const { createNotification } = require('../services/notificationService');

const router = express.Router();

const createCaseSchema = z.object({
  lawyerId: z.string().trim().min(1, 'lawyerId is required.'),
  title: z.string().trim().min(1, 'title is required.').max(200),
  description: z.string().trim().max(2000).optional().default(''),
});

const createCaseUpdateSchema = z.object({
  title: z.string().trim().min(1, 'title is required.').max(200),
  description: z.string().trim().max(4000).optional().default(''),
  hearingDate: z
    .union([z.string().datetime(), z.null(), z.undefined()])
    .optional(),
});

const updateCaseStatusSchema = z.object({
  status: z.enum(['OPEN', 'IN_PROGRESS', 'WAITING_CLIENT', 'CLOSED']),
});

function normalizeRole(role) {
  return String(role || '').trim().toLowerCase();
}

function normalizeCaseStatus(value, fallback = 'OPEN') {
  const normalized = String(value ?? fallback).trim().toUpperCase();
  return ['OPEN', 'IN_PROGRESS', 'WAITING_CLIENT', 'CLOSED'].includes(
    normalized
  )
    ? normalized
    : null;
}

function mapCase(row) {
  return {
    id: row.id,
    clientId: row.clientId,
    lawyerId: row.lawyerId,
    title: row.title,
    description: row.description || '',
    status: row.status || 'OPEN',
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

function mapCaseUpdate(row) {
  const title = row.title || 'Update';
  const description = row.description || '';

  return {
    id: row.id,
    caseId: row.caseId,
    title,
    description,
    updateText: description ? `${title} — ${description}` : title,
    postedById: row.postedById,
    hearingDate: row.hearingDate || null,
    createdAt: row.createdAt,
  };
}

async function getClientProfile(userId) {
  return get(
    `SELECT * FROM public."ClientProfile" WHERE "userId" = ?`,
    [userId]
  );
}

async function getLawyerProfile(userId) {
  return get(
    `SELECT * FROM public."LawyerProfile" WHERE "userId" = ?`,
    [userId]
  );
}

async function hasAssignedAppointment(clientId, lawyerId) {
  const row = await get(
    `SELECT id
     FROM public."Appointment"
     WHERE "clientId" = ?
       AND "lawyerId" = ?
       AND status IN ('SCHEDULED', 'COMPLETED')
     LIMIT 1`,
    [clientId, lawyerId]
  );

  return Boolean(row);
}

async function ensureCaseAccess(caseId, user) {
  const caseRow = await get(
    `SELECT *
     FROM public."Case"
     WHERE id = ?`,
    [caseId]
  );

  if (!caseRow) {
    return { status: 404, body: { error: 'Case not found.' } };
  }

  const role = normalizeRole(user.role);

  if (role === 'admin') {
    return { caseRow };
  }

  if (role === 'client') {
    const clientProfile = await getClientProfile(user.id);
    if (!clientProfile || caseRow.clientId !== clientProfile.id) {
      return { status: 403, body: { error: 'Forbidden.' } };
    }
    return { caseRow, clientProfile };
  }

  if (role === 'lawyer') {
    const lawyerProfile = await getLawyerProfile(user.id);
    if (!lawyerProfile || caseRow.lawyerId !== lawyerProfile.id) {
      return { status: 403, body: { error: 'Forbidden.' } };
    }
    return { caseRow, lawyerProfile };
  }

  return { status: 403, body: { error: 'Forbidden.' } };
}

router.get('/', authRequired, async (req, res, next) => {
  try {
    const role = normalizeRole(req.user.role);
    let rows = [];

    if (role === 'client') {
      const clientProfile = await getClientProfile(req.user.id);
      if (!clientProfile) {
        return res.status(400).json({ error: 'Client profile not found.' });
      }

      rows = await all(
        `SELECT *
         FROM public."Case"
         WHERE "clientId" = ?
         ORDER BY "updatedAt" DESC, "createdAt" DESC`,
        [clientProfile.id]
      );
    } else if (role === 'lawyer') {
      const lawyerProfile = await getLawyerProfile(req.user.id);
      if (!lawyerProfile) {
        return res.status(400).json({ error: 'Lawyer profile not found.' });
      }

      rows = await all(
        `SELECT *
         FROM public."Case"
         WHERE "lawyerId" = ?
         ORDER BY "updatedAt" DESC, "createdAt" DESC`,
        [lawyerProfile.id]
      );
    } else {
      rows = await all(
        `SELECT *
         FROM public."Case"
         ORDER BY "updatedAt" DESC, "createdAt" DESC`
      );
    }

    res.json({ items: rows.map(mapCase) });
  } catch (error) {
    next(error);
  }
});

router.get('/:id', authRequired, async (req, res, next) => {
  try {
    const access = await ensureCaseAccess(req.params.id, req.user);
    if (access.status) {
      return res.status(access.status).json(access.body);
    }

    res.json({ item: mapCase(access.caseRow) });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/updates', authRequired, async (req, res, next) => {
  try {
    const access = await ensureCaseAccess(req.params.id, req.user);
    if (access.status) {
      return res.status(access.status).json(access.body);
    }

    const rows = await all(
      `SELECT *
       FROM public."CaseUpdate"
       WHERE "caseId" = ?
       ORDER BY "createdAt" ASC`,
      [req.params.id]
    );

    res.json({ items: rows.map(mapCaseUpdate) });
  } catch (error) {
    next(error);
  }
});

router.post(
  '/',
  authRequired,
  validateBody(createCaseSchema),
  async (req, res, next) => {
    try {
      if (normalizeRole(req.user.role) !== 'client') {
        return res.status(403).json({ error: 'Only clients can create cases.' });
      }

      const { lawyerId, title, description = '' } = req.validatedBody;

      const clientProfile = await getClientProfile(req.user.id);
      if (!clientProfile) {
        return res.status(400).json({ error: 'Client profile not found.' });
      }

      const lawyerProfile = await get(
        `SELECT *
         FROM public."LawyerProfile"
         WHERE id = ?
           AND "verificationStatus" = 'APPROVED'`,
        [lawyerId]
      );

      if (!lawyerProfile) {
        return res.status(404).json({ error: 'Approved lawyer not found.' });
      }

      const assigned = await hasAssignedAppointment(
        clientProfile.id,
        lawyerProfile.id
      );

      if (!assigned) {
        return res.status(403).json({
          error: 'Book an appointment with this lawyer first before creating a case.',
        });
      }

      const existing = await get(
        `SELECT *
         FROM public."Case"
         WHERE "clientId" = ?
           AND "lawyerId" = ?
           AND status != 'CLOSED'
         ORDER BY "updatedAt" DESC
         LIMIT 1`,
        [clientProfile.id, lawyerProfile.id]
      );

      if (existing) {
        return res.status(200).json({ item: mapCase(existing) });
      }

      const id = uuid();
      const now = nowIso();

      await run(
        `INSERT INTO public."Case"
          (id, "clientId", "lawyerId", title, description, status, "createdAt", "updatedAt")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          id,
          clientProfile.id,
          lawyerProfile.id,
          title.trim(),
          description.trim(),
          'OPEN',
          now,
          now,
        ]
      );

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'case.created',
        targetType: 'case',
        targetId: id,
        ipAddress: req.ip,
      });

      const item = await get(
        `SELECT *
         FROM public."Case"
         WHERE id = ?`,
        [id]
      );

      res.status(201).json({ item: mapCase(item) });
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/:id/updates',
  authRequired,
  validateBody(createCaseUpdateSchema),
  async (req, res, next) => {
    try {
      const access = await ensureCaseAccess(req.params.id, req.user);
      if (access.status) {
        return res.status(access.status).json(access.body);
      }

      const role = normalizeRole(req.user.role);
      if (role !== 'lawyer' && role !== 'admin') {
        return res.status(403).json({
          error: 'Only the lawyer can post case updates.',
        });
      }

      const { title, description = '', hearingDate } = req.validatedBody;
      const parsedHearingDate = hearingDate ? new Date(hearingDate) : null;

      if (parsedHearingDate && Number.isNaN(parsedHearingDate.getTime())) {
        return res.status(400).json({ error: 'Invalid hearingDate.' });
      }

      const id = uuid();
      const createdAt = nowIso();

      await run(
        `INSERT INTO public."CaseUpdate"
          (id, "caseId", title, description, "postedById", "hearingDate", "createdAt")
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          id,
          access.caseRow.id,
          title.trim(),
          description.trim() || null,
          req.user.id,
          parsedHearingDate ? parsedHearingDate.toISOString() : null,
          createdAt,
        ]
      );

      await run(
        `UPDATE public."Case"
         SET "updatedAt" = ?
         WHERE id = ?`,
        [createdAt, access.caseRow.id]
      );

      const clientProfile = await get(
        `SELECT * FROM public."ClientProfile" WHERE id = ?`,
        [access.caseRow.clientId]
      );

      if (clientProfile?.userId) {
        await createNotification({
          userId: clientProfile.userId,
          type: 'case.update_posted',
          title: 'New case update',
          body: title.trim(),
          data: {
            caseId: access.caseRow.id,
            screen: 'case',
          },
        });
      }

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'case.update_posted',
        targetType: 'case',
        targetId: access.caseRow.id,
        ipAddress: req.ip,
      });

      const item = await get(
        `SELECT *
         FROM public."CaseUpdate"
         WHERE id = ?`,
        [id]
      );

      res.status(201).json({ item: mapCaseUpdate(item) });
    } catch (error) {
      next(error);
    }
  }
);

router.patch(
  '/:id',
  authRequired,
  validateBody(updateCaseStatusSchema),
  async (req, res, next) => {
    try {
      const access = await ensureCaseAccess(req.params.id, req.user);
      if (access.status) {
        return res.status(access.status).json(access.body);
      }

      const role = normalizeRole(req.user.role);
      if (role !== 'lawyer' && role !== 'admin') {
        return res.status(403).json({
          error: 'Only the lawyer can change case status.',
        });
      }

      const nextStatus = normalizeCaseStatus(
        req.validatedBody.status,
        access.caseRow.status
      );

      if (!nextStatus) {
        return res.status(400).json({
          error: 'Invalid status. Use OPEN, IN_PROGRESS, WAITING_CLIENT, or CLOSED.',
        });
      }

      const now = nowIso();

      await run(
        `UPDATE public."Case"
         SET status = ?, "updatedAt" = ?
         WHERE id = ?`,
        [nextStatus, now, access.caseRow.id]
      );

      const clientProfile = await get(
        `SELECT * FROM public."ClientProfile" WHERE id = ?`,
        [access.caseRow.clientId]
      );

      if (clientProfile?.userId) {
        await createNotification({
          userId: clientProfile.userId,
          type: 'case.status_changed',
          title: 'Case status updated',
          body: `Status changed to ${nextStatus}`,
          data: {
            caseId: access.caseRow.id,
            screen: 'case',
          },
        });
      }

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'case.status_changed',
        targetType: 'case',
        targetId: access.caseRow.id,
        ipAddress: req.ip,
      });

      const item = await get(
        `SELECT *
         FROM public."Case"
         WHERE id = ?`,
        [access.caseRow.id]
      );

      res.json({ item: mapCase(item) });
    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;