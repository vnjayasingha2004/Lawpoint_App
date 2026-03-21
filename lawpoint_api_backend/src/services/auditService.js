const { v4: uuid } = require('uuid');
const { run } = require('../db');
const { nowIso } = require('../utils/time');

async function writeAudit({
  actorUserId = null,
  eventType,
  targetType = null,
  targetId = null,
  ipAddress = null,
}) {
  await run(
    `INSERT INTO public."AuditLog"
      (id, "actorUserId", "eventType", "targetType", "targetId", "ipAddress", "createdAt")
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      uuid(),
      actorUserId,
      eventType,
      targetType,
      targetId,
      ipAddress,
      nowIso(),
    ]
  );
}

module.exports = {
  writeAudit,
};
