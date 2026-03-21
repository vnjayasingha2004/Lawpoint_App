const { v4: uuid } = require('uuid');
const { all, get, run } = require('../db');
const { nowIso } = require('../utils/time');

async function createNotification({
  userId,
  type,
  title,
  body,
  data = {},
}) {
  const id = uuid();

  await run(
    `INSERT INTO public."Notification"
      (id, "userId", title, body, type, "isRead", "createdAt", "readAt", data)
     VALUES (?, ?, ?, ?, ?, false, ?, ?, ?)`,
    [
      id,
      userId,
      title,
      body,
      type,
      nowIso(),
      null,
      JSON.stringify(data || {}),
    ],
  );

  return get(
    `SELECT * FROM public."Notification" WHERE id = ?`,
    [id],
  );
}

function mapNotification(row) {
  let parsedData = {};
  try {
    parsedData =
      typeof row.data === 'string' ? JSON.parse(row.data) : (row.data || {});
  } catch (_) {
    parsedData = {};
  }

  return {
    id: row.id,
    userId: row.userId,
    title: row.title,
    body: row.body,
    type: row.type,
    isRead: Boolean(row.isRead),
    createdAt: row.createdAt,
    readAt: row.readAt || null,
    data: parsedData,
  };
}

async function listNotificationsForUser(userId, { unreadOnly = false } = {}) {
  const rows = unreadOnly
    ? await all(
        `SELECT *
         FROM public."Notification"
         WHERE "userId" = ?
           AND "isRead" = false
         ORDER BY "createdAt" DESC`,
        [userId],
      )
    : await all(
        `SELECT *
         FROM public."Notification"
         WHERE "userId" = ?
         ORDER BY "createdAt" DESC`,
        [userId],
      );

  return rows.map(mapNotification);
}

async function markNotificationRead(notificationId, userId) {
  await run(
    `UPDATE public."Notification"
     SET "isRead" = true,
         "readAt" = COALESCE("readAt", ?)
     WHERE id = ?
       AND "userId" = ?`,
    [nowIso(), notificationId, userId],
  );

  return get(
    `SELECT * FROM public."Notification"
     WHERE id = ? AND "userId" = ?`,
    [notificationId, userId],
  );
}

async function markAllNotificationsRead(userId) {
  await run(
    `UPDATE public."Notification"
     SET "isRead" = true,
         "readAt" = COALESCE("readAt", ?)
     WHERE "userId" = ?
       AND "isRead" = false`,
    [nowIso(), userId],
  );
}

async function upsertDeviceToken({ userId, token, deviceOs = null }) {
  const existing = await get(
    `SELECT * FROM public."DeviceToken"
     WHERE token = ?`,
    [token],
  );

  if (existing) {
    await run(
      `UPDATE public."DeviceToken"
       SET "userId" = ?, "deviceOs" = ?
       WHERE id = ?`,
      [userId, deviceOs, existing.id],
    );

    return get(
      `SELECT * FROM public."DeviceToken" WHERE id = ?`,
      [existing.id],
    );
  }

  const id = uuid();

  await run(
    `INSERT INTO public."DeviceToken"
      (id, "userId", token, "deviceOs")
     VALUES (?, ?, ?, ?)`,
    [id, userId, token, deviceOs],
  );

  return get(
    `SELECT * FROM public."DeviceToken" WHERE id = ?`,
    [id],
  );
}

module.exports = {
  createNotification,
  listNotificationsForUser,
  markNotificationRead,
  markAllNotificationsRead,
  upsertDeviceToken,
  mapNotification,
};