const express = require('express');
const { z } = require('zod');

const { authRequired } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const {
  listNotificationsForUser,
  markNotificationRead,
  markAllNotificationsRead,
  upsertDeviceToken,
  mapNotification,
} = require('../services/notificationService');

const router = express.Router();

const registerDeviceTokenSchema = z.object({
  token: z.string().trim().min(1).max(500),
  deviceOs: z.preprocess((value) => {
    if (value == null) return undefined;
    const next = String(value).trim();
    return next.length ? next : undefined;
  }, z.string().min(1).max(40).optional()),
});

router.use(authRequired);

router.get('/', async (req, res, next) => {
  try {
    const unreadOnly = String(req.query.unreadOnly || '').toLowerCase() === 'true';

    const items = await listNotificationsForUser(req.user.id, { unreadOnly });

    res.json({ items });
  } catch (error) {
    next(error);
  }
});

router.post(
  '/device-token',
  validateBody(registerDeviceTokenSchema),
  async (req, res, next) => {
    try {
      const { token, deviceOs } = req.validatedBody;

      const item = await upsertDeviceToken({
        userId: req.user.id,
        token,
        deviceOs: deviceOs || null,
      });

      res.status(201).json({ item });
    } catch (error) {
      next(error);
    }
  }
);

router.post('/:id/read', async (req, res, next) => {
  try {
    const row = await markNotificationRead(req.params.id, req.user.id);

    if (!row) {
      return res.status(404).json({ error: 'Notification not found.' });
    }

    res.json({ item: mapNotification(row) });
  } catch (error) {
    next(error);
  }
});

router.post('/read-all', async (req, res, next) => {
  try {
    await markAllNotificationsRead(req.user.id);
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

module.exports = router;