const express = require('express');
const { z } = require('zod');
const { v4: uuid } = require('uuid');

const { get, run } = require('../db');
const { authRequired, requireRole } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const { buildVideoSession } = require('../services/videoService');
const { nowIso } = require('../utils/time');
const { writeAudit } = require('../services/auditService');

const router = express.Router();

const videoTokenSchema = z.object({
  appointmentId: z.string().trim().min(1, 'appointmentId is required.'),
});

async function getProfileIdByRole(user) {
  if (user.role === 'client') {
    const client = await get(
      `SELECT * FROM public."ClientProfile" WHERE "userId" = ?`,
      [user.id]
    );
    return client ? { role: 'client', profileId: client.id } : null;
  }

  if (user.role === 'lawyer') {
    const lawyer = await get(
      `SELECT * FROM public."LawyerProfile" WHERE "userId" = ?`,
      [user.id]
    );
    return lawyer ? { role: 'lawyer', profileId: lawyer.id } : null;
  }

  return null;
}

router.post(
  '/token',
  authRequired,
  requireRole('client', 'lawyer'),
  validateBody(videoTokenSchema),
  async (req, res, next) => {
    try {
      const { appointmentId } = req.validatedBody;

      const appointment = await get(
        `SELECT *
         FROM public."Appointment"
         WHERE id = ?`,
        [appointmentId]
      );

      if (!appointment) {
        return res.status(404).json({ error: 'Appointment not found.' });
      }

      if (appointment.status !== 'SCHEDULED') {
        return res.status(400).json({
          error: 'Video is only available for scheduled appointments.',
        });
      }

      const access = await getProfileIdByRole(req.user);
      if (!access) {
        return res.status(400).json({ error: 'Profile not found.' });
      }

      const permitted =
        (access.role === 'client' && access.profileId === appointment.clientId) ||
        (access.role === 'lawyer' && access.profileId === appointment.lawyerId);

      if (!permitted) {
        return res.status(403).json({ error: 'Forbidden.' });
      }

      if (!appointment.videoSessionId) {
        const newSessionId = uuid();

        await run(
          `UPDATE public."Appointment"
           SET "videoSessionId" = ?, "updatedAt" = ?
           WHERE id = ?`,
          [newSessionId, nowIso(), appointment.id]
        );

        appointment.videoSessionId = newSessionId;
      }

      const session = buildVideoSession({
        appointment,
        requester: req.user,
      });

      await writeAudit({
        actorUserId: req.user.id,
        eventType: session.canJoinNow
          ? 'video.session_token_issued'
          : 'video.session_checked',
        targetType: 'appointment',
        targetId: appointment.id,
        ipAddress: req.ip,
      });

      res.json(session);
    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;