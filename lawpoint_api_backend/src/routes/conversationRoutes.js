const express = require('express');
const { z } = require('zod');
const { v4: uuid } = require('uuid');

const { readUserPrivateFields } = require('../services/userService');
const { all, get, run } = require('../db');
const { authRequired, requireRole } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const { nowIso } = require('../utils/time');
const { writeAudit } = require('../services/auditService');
const { createNotification } = require('../services/notificationService');
const { decryptText } = require('../utils/crypto');

const router = express.Router();

const optionalTrimmedString = (max) =>
  z.preprocess((value) => {
    if (value == null) return undefined;
    const next = String(value).trim();
    return next.length ? next : undefined;
  }, z.string().min(1).max(max).optional());

const wrappedKeySchema = z.object({
  senderPublicKey: z.string().trim().min(20).max(5000),
  nonce: z.string().trim().min(8).max(5000),
  ciphertext: z.string().trim().min(8).max(20000),
});

const savePublicKeySchema = z.object({
  publicKey: z.string().trim().min(20).max(5000),
});

const saveConversationKeySchema = z.object({
  clientWrappedKey: wrappedKeySchema,
  lawyerWrappedKey: wrappedKeySchema,
});

const openConversationSchema = z
  .object({
    lawyerId: optionalTrimmedString(255),
    clientId: optionalTrimmedString(255),
  })
  .refine((value) => Boolean(value.lawyerId || value.clientId), {
    message: 'lawyerId or clientId is required.',
    path: ['lawyerId'],
  });

const sendMessageSchema = z
  .object({
    text: optionalTrimmedString(12000),
    content: optionalTrimmedString(12000),
    attachmentUrl: optionalTrimmedString(1000),
    nonce: optionalTrimmedString(5000),
    messageEncoding: optionalTrimmedString(50),
  })
  .refine((value) => Boolean(value.text || value.content || value.attachmentUrl), {
    message: 'Message text or attachmentUrl is required.',
    path: ['text'],
  });

router.use(authRequired, requireRole('client', 'lawyer'));

function normalizeRole(role) {
  return String(role || '').trim().toLowerCase();
}

function buildConversationId(clientUserId, lawyerUserId) {
  return `${clientUserId}__${lawyerUserId}`;
}

function parseConversationId(conversationId) {
  const [clientUserId, lawyerUserId] = String(conversationId || '').split('__');
  if (!clientUserId || !lawyerUserId) return null;
  return { clientUserId, lawyerUserId };
}

function normalizeStoredText(value) {
  if (value == null) return '';
  return String(value);
}

function safeParseJson(value) {
  if (!value) return null;
  if (typeof value === 'object') return value;

  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function readLegacyMessageContent(row) {
  if (row?.contentCiphertext) {
    try {
      return decryptText(row.contentCiphertext) || '';
    } catch (_) {}
  }

  return normalizeStoredText(row?.content);
}

function getMessagePreview(row) {
  if (!row) return '';

  if (String(row.messageEncoding || '') === 'e2ee-v1') {
    return row.attachmentUrl ? 'Encrypted attachment' : 'Encrypted message';
  }

  const legacy = readLegacyMessageContent(row).trim();
  if (legacy) return legacy;
  if (row.attachmentUrl) return 'Attachment';
  return '';
}

function mapMessage(row, conversationId) {
  if (String(row.messageEncoding || '') === 'e2ee-v1') {
    return {
      id: row.id,
      conversationId,
      senderId: row.senderId,
      receiverId: row.receiverId,
      content: row.clientCiphertext || '',
      ciphertext: row.clientCiphertext || '',
      caseId: row.caseId || null,
      attachmentUrl: row.attachmentUrl || null,
      nonce: row.clientNonce || null,
      messageEncoding: 'e2ee-v1',
      createdAt: row.createdAt,
    };
  }

  return {
    id: row.id,
    conversationId,
    senderId: row.senderId,
    receiverId: row.receiverId,
    content: readLegacyMessageContent(row),
    caseId: row.caseId || null,
    attachmentUrl: row.attachmentUrl || null,
    nonce: row.nonce || null,
    messageEncoding: row.messageEncoding || 'legacy-v0',
    createdAt: row.createdAt,
  };
}

async function getUserById(userId) {
  return get(`SELECT * FROM public."User" WHERE id = ?`, [userId]);
}

async function getClientProfileByUserId(userId) {
  return get(
    `SELECT * FROM public."ClientProfile" WHERE "userId" = ?`,
    [userId]
  );
}

async function getLawyerProfileByUserId(userId) {
  return get(
    `SELECT * FROM public."LawyerProfile" WHERE "userId" = ?`,
    [userId]
  );
}

async function getClientProfileId(userId) {
  const profile = await getClientProfileByUserId(userId);
  return profile ? profile.id : null;
}

async function getLawyerProfileId(userId) {
  const profile = await getLawyerProfileByUserId(userId);
  return profile ? profile.id : null;
}

async function getDisplayNameForUser(userId, roleHint = null) {
  const user = await getUserById(userId);
  if (!user) return 'User';

  const role = normalizeRole(roleHint || user.role);
  const privateFields = readUserPrivateFields(user);
  const email = privateFields.email || '';
  const phone = privateFields.phone || '';

  if (role === 'client') {
    const profile = await getClientProfileByUserId(userId);
    const fullName = [profile?.firstName, profile?.lastName]
      .filter(Boolean)
      .join(' ')
      .trim();
    return fullName || email || phone || 'Client';
  }

  if (role === 'lawyer') {
    const profile = await getLawyerProfileByUserId(userId);
    const fullName = [profile?.firstName, profile?.lastName]
      .filter(Boolean)
      .join(' ')
      .trim();
    return fullName || email || phone || 'Lawyer';
  }

  return email || phone || 'User';
}

async function getConversationContextByUsers(clientUserId, lawyerUserId) {
  const [clientUser, lawyerUser, clientProfile, lawyerProfile] =
    await Promise.all([
      getUserById(clientUserId),
      getUserById(lawyerUserId),
      getClientProfileByUserId(clientUserId),
      getLawyerProfileByUserId(lawyerUserId),
    ]);

  if (!clientUser || !lawyerUser || !clientProfile || !lawyerProfile) {
    return null;
  }

  const [appointmentLink, caseLink] = await Promise.all([
    get(
      `SELECT *
       FROM public."Appointment"
       WHERE "clientId" = ?
         AND "lawyerId" = ?
         AND status IN ('SCHEDULED', 'COMPLETED')
       ORDER BY "startTime" DESC
       LIMIT 1`,
      [clientProfile.id, lawyerProfile.id]
    ),
    get(
      `SELECT *
       FROM public."Case"
       WHERE "clientId" = ?
         AND "lawyerId" = ?
       ORDER BY "createdAt" DESC
       LIMIT 1`,
      [clientProfile.id, lawyerProfile.id]
    ),
  ]);

  return {
    clientUser,
    lawyerUser,
    clientProfile,
    lawyerProfile,
    appointmentLink,
    caseLink,
    isAssigned: Boolean(appointmentLink || caseLink),
    defaultCaseId: caseLink?.id || null,
  };
}

async function getLastMessageBetween(clientUserId, lawyerUserId) {
  return get(
    `SELECT *
     FROM public."Message"
     WHERE ("senderId" = ? AND "receiverId" = ?)
        OR ("senderId" = ? AND "receiverId" = ?)
     ORDER BY "createdAt" DESC
     LIMIT 1`,
    [clientUserId, lawyerUserId, lawyerUserId, clientUserId]
  );
}

async function getConversationKeyEnvelope(conversationId) {
  return get(
    `SELECT *
     FROM public."ConversationKeyEnvelope"
     WHERE "conversationId" = ?`,
    [conversationId]
  );
}

async function listAssignedConversationPairsForUser(currentUser) {
  const role = normalizeRole(currentUser.role);

  if (role === 'client') {
    const clientProfileId = await getClientProfileId(currentUser.id);
    if (!clientProfileId) return [];

    const [appointmentRows, caseRows] = await Promise.all([
      all(
        `SELECT DISTINCT lp."userId" AS "otherUserId"
         FROM public."Appointment" a
         JOIN public."LawyerProfile" lp ON lp.id = a."lawyerId"
         WHERE a."clientId" = ?
           AND a.status IN ('SCHEDULED', 'COMPLETED')`,
        [clientProfileId]
      ),
      all(
        `SELECT DISTINCT lp."userId" AS "otherUserId"
         FROM public."Case" c
         JOIN public."LawyerProfile" lp ON lp.id = c."lawyerId"
         WHERE c."clientId" = ?`,
        [clientProfileId]
      ),
    ]);

    const lawyerUserIds = [
      ...new Set(
        [...appointmentRows, ...caseRows]
          .map((row) => row.otherUserId)
          .filter(Boolean)
      ),
    ];

    return lawyerUserIds.map((lawyerUserId) => ({
      clientUserId: currentUser.id,
      lawyerUserId,
    }));
  }

  const lawyerProfileId = await getLawyerProfileId(currentUser.id);
  if (!lawyerProfileId) return [];

  const [appointmentRows, caseRows] = await Promise.all([
    all(
      `SELECT DISTINCT cp."userId" AS "otherUserId"
       FROM public."Appointment" a
       JOIN public."ClientProfile" cp ON cp.id = a."clientId"
       WHERE a."lawyerId" = ?
         AND a.status IN ('SCHEDULED', 'COMPLETED')`,
      [lawyerProfileId]
    ),
    all(
      `SELECT DISTINCT cp."userId" AS "otherUserId"
       FROM public."Case" c
       JOIN public."ClientProfile" cp ON cp.id = c."clientId"
       WHERE c."lawyerId" = ?`,
      [lawyerProfileId]
    ),
  ]);

  const clientUserIds = [
    ...new Set(
      [...appointmentRows, ...caseRows]
        .map((row) => row.otherUserId)
        .filter(Boolean)
    ),
  ];

  return clientUserIds.map((clientUserId) => ({
    clientUserId,
    lawyerUserId: currentUser.id,
  }));
}

async function decorateConversation({
  clientUserId,
  lawyerUserId,
  currentUserRole,
}) {
  const context = await getConversationContextByUsers(clientUserId, lawyerUserId);
  if (!context || !context.isAssigned) return null;

  const [clientName, lawyerName, lastMessage] = await Promise.all([
    getDisplayNameForUser(clientUserId, 'client'),
    getDisplayNameForUser(lawyerUserId, 'lawyer'),
    getLastMessageBetween(clientUserId, lawyerUserId),
  ]);

  const role = normalizeRole(currentUserRole);

  let title = 'Conversation';
  if (role === 'client') {
    title = lawyerName || 'Lawyer';
  } else if (role === 'lawyer') {
    title = clientName || 'Client';
  }

  return {
    id: buildConversationId(clientUserId, lawyerUserId),
    clientId: context.clientProfile.id,
    lawyerId: context.lawyerProfile.id,
    title,
    lastMessagePreview: getMessagePreview(lastMessage),
    updatedAt: lastMessage?.createdAt || null,
    createdAt: lastMessage?.createdAt || null,
  };
}

async function resolveConversation(conversationId, currentUser) {
  const parsed = parseConversationId(conversationId);
  if (!parsed) {
    return { status: 400, body: { error: 'Invalid conversation id.' } };
  }

  const { clientUserId, lawyerUserId } = parsed;
  const role = normalizeRole(currentUser.role);

  if (role === 'client' && currentUser.id !== clientUserId) {
    return { status: 403, body: { error: 'Forbidden.' } };
  }

  if (role === 'lawyer' && currentUser.id !== lawyerUserId) {
    return { status: 403, body: { error: 'Forbidden.' } };
  }

  const context = await getConversationContextByUsers(clientUserId, lawyerUserId);

  if (!context) {
    return {
      status: 404,
      body: { error: 'Conversation participants not found.' },
    };
  }

  if (!context.isAssigned) {
    return {
      status: 403,
      body: {
        error: 'Messaging is only allowed between assigned clients and lawyers.',
      },
    };
  }

  return {
    clientUserId,
    lawyerUserId,
    context,
  };
}

router.get('/keys/me', async (req, res, next) => {
  try {
    const user = await getUserById(req.user.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    return res.json({
      publicKey: user.chatPublicKey || null,
      keyVersion: Number(user.chatKeyVersion || 1),
    });
  } catch (error) {
    next(error);
  }
});

router.put('/keys/me', validateBody(savePublicKeySchema), async (req, res, next) => {
  try {
    const { publicKey } = req.validatedBody;

    await run(
      `UPDATE public."User"
       SET "chatPublicKey" = ?, "chatKeyVersion" = ?, "updatedAt" = ?
       WHERE id = ?`,
      [publicKey, 1, nowIso(), req.user.id]
    );

    return res.json({
      ok: true,
      publicKey,
      keyVersion: 1,
    });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/e2ee-key', async (req, res, next) => {
  try {
    const resolved = await resolveConversation(req.params.id, req.user);
    if (resolved.status) {
      return res.status(resolved.status).json(resolved.body);
    }

    const currentUserRole =
      req.user.id === resolved.clientUserId ? 'client' : 'lawyer';

    const envelope = await getConversationKeyEnvelope(req.params.id);

    if (!envelope) {
      return res.json({
        exists: false,
        currentUserRole,
        clientPublicKey: resolved.context.clientUser.chatPublicKey || null,
        lawyerPublicKey: resolved.context.lawyerUser.chatPublicKey || null,
      });
    }

    return res.json({
      exists: true,
      currentUserRole,
      clientPublicKey: resolved.context.clientUser.chatPublicKey || null,
      lawyerPublicKey: resolved.context.lawyerUser.chatPublicKey || null,
      wrappedKey:
        currentUserRole === 'client'
          ? safeParseJson(envelope.clientWrappedKey)
          : safeParseJson(envelope.lawyerWrappedKey),
    });
  } catch (error) {
    next(error);
  }
});

router.post(
  '/:id/e2ee-key',
  validateBody(saveConversationKeySchema),
  async (req, res, next) => {
    try {
      const resolved = await resolveConversation(req.params.id, req.user);
      if (resolved.status) {
        return res.status(resolved.status).json(resolved.body);
      }

      if (
        !resolved.context.clientUser.chatPublicKey ||
        !resolved.context.lawyerUser.chatPublicKey
      ) {
        return res.status(409).json({
          error: 'Both users must publish their chat public keys first.',
        });
      }

      const { clientWrappedKey, lawyerWrappedKey } = req.validatedBody;
      const id = uuid();
      const ts = nowIso();

      await run(
        `INSERT INTO public."ConversationKeyEnvelope"
          (
            id,
            "conversationId",
            "clientUserId",
            "lawyerUserId",
            algorithm,
            "clientWrappedKey",
            "lawyerWrappedKey",
            "createdAt",
            "updatedAt"
          )
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT ("conversationId")
         DO UPDATE SET
           "clientWrappedKey" = EXCLUDED."clientWrappedKey",
           "lawyerWrappedKey" = EXCLUDED."lawyerWrappedKey",
           "updatedAt" = EXCLUDED."updatedAt"`,
        [
          id,
          req.params.id,
          resolved.clientUserId,
          resolved.lawyerUserId,
          'x25519+aes-256-gcm-v1',
          JSON.stringify(clientWrappedKey),
          JSON.stringify(lawyerWrappedKey),
          ts,
          ts,
        ]
      );

      return res.status(201).json({
        ok: true,
        algorithm: 'x25519+aes-256-gcm-v1',
      });
    } catch (error) {
      next(error);
    }
  }
);

router.get('/', async (req, res, next) => {
  try {
    const pairs = await listAssignedConversationPairsForUser(req.user);

    const items = (await Promise.all(
      pairs.map((pair) =>
        decorateConversation({
          ...pair,
          currentUserRole: req.user.role,
        })
      )
    ))
      .filter(Boolean)
      .sort((a, b) => {
        const timeA = a.updatedAt ? new Date(a.updatedAt).getTime() : 0;
        const timeB = b.updatedAt ? new Date(b.updatedAt).getTime() : 0;
        return timeB - timeA;
      });

    res.json({ items });
  } catch (error) {
    next(error);
  }
});

router.post('/', validateBody(openConversationSchema), async (req, res, next) => {
  try {
    const role = normalizeRole(req.user.role);

    let clientUserId = null;
    let lawyerUserId = null;

    if (role === 'client') {
      const { lawyerId } = req.validatedBody;
      const lawyerProfile = await get(
        `SELECT * FROM public."LawyerProfile" WHERE id = ?`,
        [lawyerId]
      );

      if (!lawyerProfile) {
        return res.status(400).json({ error: 'Valid lawyerId is required.' });
      }

      clientUserId = req.user.id;
      lawyerUserId = lawyerProfile.userId;
    } else {
      const { clientId } = req.validatedBody;
      const clientProfile = await get(
        `SELECT * FROM public."ClientProfile" WHERE id = ?`,
        [clientId]
      );

      if (!clientProfile) {
        return res.status(400).json({ error: 'Valid clientId is required.' });
      }

      clientUserId = clientProfile.userId;
      lawyerUserId = req.user.id;
    }

    const context = await getConversationContextByUsers(clientUserId, lawyerUserId);

    if (!context || !context.isAssigned) {
      return res.status(403).json({
        error: 'You can only open chat with an assigned lawyer/client.',
      });
    }

    const item = await decorateConversation({
      clientUserId,
      lawyerUserId,
      currentUserRole: req.user.role,
    });

    await writeAudit({
      actorUserId: req.user.id,
      eventType: 'conversation.opened',
      targetType: 'conversation',
      targetId: item.id,
      ipAddress: req.ip,
    });

    res.status(201).json({ item });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/messages', async (req, res, next) => {
  try {
    const resolved = await resolveConversation(req.params.id, req.user);
    if (resolved.status) {
      return res.status(resolved.status).json(resolved.body);
    }

    const rows = await all(
      `SELECT *
       FROM public."Message"
       WHERE ("senderId" = ? AND "receiverId" = ?)
          OR ("senderId" = ? AND "receiverId" = ?)
       ORDER BY "createdAt" ASC`,
      [
        resolved.clientUserId,
        resolved.lawyerUserId,
        resolved.lawyerUserId,
        resolved.clientUserId,
      ]
    );

    res.json({
      items: rows.map((row) => mapMessage(row, req.params.id)),
    });
  } catch (error) {
    next(error);
  }
});

router.post(
  '/:id/messages',
  validateBody(sendMessageSchema),
  async (req, res, next) => {
    try {
      const resolved = await resolveConversation(req.params.id, req.user);
      if (resolved.status) {
        return res.status(resolved.status).json(resolved.body);
      }

      const submittedText = String(
        req.validatedBody.text ?? req.validatedBody.content ?? ''
      ).trim();
      const attachmentUrl = req.validatedBody.attachmentUrl || null;
      const nonce = req.validatedBody.nonce || null;
      const messageEncoding = String(
        req.validatedBody.messageEncoding || ''
      ).trim();

      const receiverId =
        req.user.id === resolved.clientUserId
          ? resolved.lawyerUserId
          : resolved.clientUserId;

      const id = uuid();
      const createdAt = nowIso();

      if (messageEncoding === 'e2ee-v1') {
        if (!submittedText || !nonce) {
          return res.status(400).json({
            error: 'Encrypted messages require ciphertext and nonce.',
          });
        }

        await run(
          `INSERT INTO public."Message"
            (
              id,
              "senderId",
              "receiverId",
              content,
              "attachmentUrl",
              nonce,
              "createdAt",
              "messageEncoding",
              "clientCiphertext",
              "clientNonce"
            )
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            id,
            req.user.id,
            receiverId,
            '',
            attachmentUrl,
            null,
            createdAt,
            'e2ee-v1',
            submittedText,
            nonce,
          ]
        );
      } else {
        await run(
          `INSERT INTO public."Message"
            (
              id,
              "senderId",
              "receiverId",
              content,
              "attachmentUrl",
              nonce,
              "createdAt",
              "messageEncoding"
            )
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            id,
            req.user.id,
            receiverId,
            submittedText || '',
            attachmentUrl,
            nonce,
            createdAt,
            'legacy-v0',
          ]
        );
      }

      const item = await get(
        `SELECT *
         FROM public."Message"
         WHERE id = ?`,
        [id]
      );

      await createNotification({
        userId: receiverId,
        type: 'message.received',
        title: 'New secure message',
        body:
          messageEncoding === 'e2ee-v1'
            ? 'Encrypted message received'
            : submittedText
            ? submittedText.slice(0, 120)
            : 'Attachment received',
        data: {
          conversationId: req.params.id,
          screen: 'messages',
        },
      });

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'message.sent',
        targetType: 'conversation',
        targetId: req.params.id,
        ipAddress: req.ip,
      });

      res.status(201).json({
        item: mapMessage(item, req.params.id),
      });
    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;