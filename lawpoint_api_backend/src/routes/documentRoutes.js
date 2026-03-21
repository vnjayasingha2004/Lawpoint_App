const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { z } = require('zod');
const { v4: uuid } = require('uuid');

const { all, get, run } = require('../db');
const { authRequired, requireRole } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const env = require('../config/env');
const {
  issueDocumentDownloadToken,
  verifyDocumentDownloadToken,
} = require('../utils/documentDownloadTokens');
const {
  fileChecksum,
  encryptFileBuffer,
  decryptFileBuffer,
} = require('../utils/crypto');
const { nowIso } = require('../utils/time');
const { writeAudit } = require('../services/auditService');
const { createNotification } = require('../services/notificationService');
const {
  SECRET_DOCUMENT_CATEGORIES,
  isSupportedSecretUploadMime,
  createRedactedDerivative,
} = require('../services/redactionService');

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
});

const shareDocumentSchema = z.object({
  lawyerId: z.string().trim().min(1, 'lawyerId is required.'),
  allowRiskyShare: z.boolean().optional(),
});

fs.mkdirSync(env.storageDir, { recursive: true });

function sanitizeFileName(name) {
  return String(name || 'file')
    .replace(/[^a-zA-Z0-9._-]/g, '_')
    .replace(/_+/g, '_');
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
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

function normalizeClassification(value) {
  const normalized = String(value || 'NORMAL').trim().toUpperCase();
  return normalized === 'SECRET' ? 'SECRET' : 'NORMAL';
}

function normalizeSecretCategory(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return SECRET_DOCUMENT_CATEGORIES.includes(normalized) ? normalized : null;
}

function resolveStoredPathFromKey(storageKey) {
  if (!storageKey) return null;
  return path.join(env.storageDir, storageKey);
}
function deleteFileIfExists(filePath) {
  try {
    if (filePath && fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  } catch (error) {
    console.error('Failed to delete stored file:', filePath, error.message);
  }
}
function readStoredFileBuffer(filePath) {
  const stored = fs.readFileSync(filePath);
  return decryptFileBuffer(stored);
}

function sendBufferDownload(res, { payload, contentType, downloadName }) {
  res.setHeader('Content-Type', contentType);
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="${sanitizeFileName(downloadName || 'document')}"`
  );
  res.setHeader('Content-Length', String(payload.length));
  return res.send(payload);
}

function resolveDownloadTargetForRequester({
  doc,
  requesterRole,
  forcedVariant = null,
}) {
  let variant = forcedVariant || 'original';
  let filePath = resolveStoredPath(doc);
  let downloadName = doc.name;
  let contentType = doc.mimeType || 'application/octet-stream';

  const isSecret = String(doc.classification || '').toUpperCase() === 'SECRET';

  if (isSecret) {
    if (forcedVariant === 'redacted') {
      if (
        String(doc.redactionStatus || '').toUpperCase() !== 'READY' ||
        !doc.redactedStorageKey
      ) {
        const error = new Error('Redacted document is not available.');
        error.statusCode = 409;
        throw error;
      }

      variant = 'redacted';
      filePath = resolveStoredPathFromKey(doc.redactedStorageKey);
      downloadName = buildRedactedDownloadName(doc.name, doc.redactedStorageKey);
      contentType = detectMimeFromStorageKey(
        doc.redactedStorageKey,
        'application/octet-stream'
      );
    } else if (String(requesterRole || '').toLowerCase() === 'lawyer') {
      const status = String(doc.redactionStatus || '').toUpperCase();

      if (status === 'READY' && doc.redactedStorageKey) {
        variant = 'redacted';
        filePath = resolveStoredPathFromKey(doc.redactedStorageKey);
        downloadName = buildRedactedDownloadName(doc.name, doc.redactedStorageKey);
        contentType = detectMimeFromStorageKey(
          doc.redactedStorageKey,
          'application/octet-stream'
        );
      } else if (
        status === 'MANUAL_REQUIRED' &&
        canLawyerReceiveOriginalOnManualShare(doc)
      ) {
        variant = 'original';
        filePath = resolveStoredPath(doc);
        downloadName = doc.name;
        contentType = doc.mimeType || 'application/octet-stream';
      } else {
        const error = new Error(
          'This secret document is not available to the lawyer yet.'
        );
        error.statusCode = 409;
        throw error;
      }
    }
  }

  if (!filePath || !fs.existsSync(filePath)) {
    const error = new Error('Stored file not found.');
    error.statusCode = 404;
    throw error;
  }

  return {
    variant,
    filePath,
    downloadName,
    contentType,
  };
}

function resolveStoredPath(doc) {
  const storageKey =
    doc.storageKey || doc.storage_key || path.basename(String(doc.fileUrl || ''));
  return resolveStoredPathFromKey(storageKey);
}

function requiresPreviewBeforeShare(doc) {
  return (
    String(doc.classification || '').toUpperCase() === 'SECRET' &&
    String(doc.secretCategory || '').toLowerCase() === 'sri_nic'
  );
}
function canLawyerReceiveOriginalOnManualShare(doc) {
  return (
    String(doc.classification || '').toUpperCase() === 'SECRET' &&
    String(doc.redactionStatus || '').toUpperCase() === 'MANUAL_REQUIRED' &&
    Boolean(doc.manualShareApprovedAt)
  );
}

function detectMimeFromStorageKey(storageKey, fallback = 'application/octet-stream') {
  const lower = String(storageKey || '').toLowerCase();

  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';

  return fallback;
}

function buildRedactedDownloadName(originalName, storageKey) {
  const ext = path.extname(String(storageKey || '')) || '.png';
  return `redacted_${path.parse(String(originalName || 'document')).name}${ext}`;
}

function mapDocument(row) {
  const sharedWithIds = asArray(row.sharedWith);
  const reviewedForShare = Boolean(row.redactionReviewedAt);

  return {
    id: row.id,
    name: row.name,
    fileName: row.name,
    fileUrl: row.fileUrl,
    downloadUrl: `/api/v1/documents/${row.id}/download`,
    previewUrl: `/api/v1/documents/${row.id}/preview`,
    fileType: row.mimeType || 'application/octet-stream',
    mimeType: row.mimeType || 'application/octet-stream',
    sizeBytes: Number(row.sizeBytes || 0),
    checksum: row.checksum || null,
    uploadedAt: row.uploadedAt,
    uploaded_at: row.uploadedAt,
    shared: sharedWithIds.length > 0,
    sharedWithIds,
    isEncrypted: Boolean(row.isEncrypted),

    classification: row.classification || 'NORMAL',
    secretCategory: row.secretCategory || null,
    redactionStatus: row.redactionStatus || 'NOT_REQUIRED',
    hasRedactedVersion: Boolean(row.redactedStorageKey),
    redactionSummary: safeParseJson(row.redactionSummary),

    requiresPreviewBeforeShare: requiresPreviewBeforeShare(row),
    reviewedForShare,
    redactionReviewedAt: row.redactionReviewedAt || null,

    manualShareApproved: Boolean(row.manualShareApprovedAt),
    manualShareApprovedAt: row.manualShareApprovedAt || null,
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

async function hasAssignment(clientProfileId, lawyerProfileId) {
  const appointment = await get(
    `SELECT id
     FROM public."Appointment"
     WHERE "clientId" = ?
       AND "lawyerId" = ?
       AND status IN ('SCHEDULED', 'COMPLETED')
     LIMIT 1`,
    [clientProfileId, lawyerProfileId]
  );

  if (appointment) return true;

  const caseLink = await get(
    `SELECT id
     FROM public."Case"
     WHERE "clientId" = ?
       AND "lawyerId" = ?
     LIMIT 1`,
    [clientProfileId, lawyerProfileId]
  );

  return Boolean(caseLink);
}

async function canUserAccessDocument(reqUser, doc) {
  if (reqUser.role === 'admin') {
    return true;
  }

  if (reqUser.role === 'client') {
    const clientProfile = await getClientProfile(reqUser.id);
    return Boolean(clientProfile && doc.clientId === clientProfile.id);
  }

  if (reqUser.role === 'lawyer') {
    const lawyerProfile = await getLawyerProfile(reqUser.id);
    if (!lawyerProfile) return false;

    const sharedWithIds = asArray(doc.sharedWith);
    if (!sharedWithIds.includes(lawyerProfile.id)) return false;

    return hasAssignment(doc.clientId, lawyerProfile.id);
  }

  return false;
}

router.get('/', authRequired, requireRole('client'), async (req, res, next) => {
  try {
    const clientProfile = await getClientProfile(req.user.id);
    if (!clientProfile) {
      return res.status(400).json({ error: 'Client profile not found.' });
    }

    const rows = await all(
      `SELECT *
       FROM public."Document"
       WHERE "clientId" = ?
       ORDER BY "uploadedAt" DESC`,
      [clientProfile.id]
    );

    res.json({ items: rows.map(mapDocument) });
  } catch (error) {
    next(error);
  }
});

router.get('/shared', authRequired, requireRole('lawyer'), async (req, res, next) => {
  try {
    const lawyerProfile = await getLawyerProfile(req.user.id);
    if (!lawyerProfile) {
      return res.status(400).json({ error: 'Lawyer profile not found.' });
    }

    const rows = await all(
      `SELECT *
       FROM public."Document"
       WHERE ? = ANY(COALESCE("sharedWith", ARRAY[]::text[]))
       ORDER BY "uploadedAt" DESC`,
      [lawyerProfile.id]
    );

    const allowed = [];
    for (const row of rows) {
      const ok = await hasAssignment(row.clientId, lawyerProfile.id);
      if (ok) allowed.push(mapDocument(row));
    }

    res.json({ items: allowed });
  } catch (error) {
    next(error);
  }
});

router.post('/', authRequired, requireRole('client'), upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'file is required.' });
    }

    const clientProfile = await getClientProfile(req.user.id);
    if (!clientProfile) {
      return res.status(400).json({ error: 'Client profile not found.' });
    }

    const classification = normalizeClassification(req.body.classification);
    const secretCategory = normalizeSecretCategory(req.body.secretCategory);

    if (classification === 'SECRET' && !secretCategory) {
      return res.status(400).json({
        error: `secretCategory is required. Allowed values: ${SECRET_DOCUMENT_CATEGORIES.join(', ')}`,
      });
    }

    if (
      classification === 'SECRET' &&
      !isSupportedSecretUploadMime(req.file.mimetype, secretCategory)
    ) {
      if (secretCategory === 'sri_nic') {
        return res.status(400).json({
          error: 'Sri Lankan NIC secret uploads currently support image files only: jpg, png, webp.',
        });
      }

      return res.status(400).json({
        error: 'Secret documents currently support: jpg, png, webp, and pdf.',
      });
    }

    const id = uuid();
const safeName = sanitizeFileName(req.file.originalname);
const storageKey = `${id}_${safeName}`;
const outputPath = path.join(env.storageDir, storageKey);

const encryptedPayload = encryptFileBuffer(req.file.buffer);
fs.writeFileSync(outputPath, encryptedPayload);

    let redactionStatus = 'NOT_REQUIRED';
    let redactedStorageKey = null;
    let redactionSummary = null;

    if (classification === 'SECRET') {
      try {
        const result = await createRedactedDerivative({
          buffer: req.file.buffer,
          mimeType: req.file.mimetype,
          originalFileName: req.file.originalname,
          category: secretCategory,
        });

        redactionStatus = result.status;
        redactedStorageKey = result.storageKey;
        redactionSummary = result.summary || null;
      } catch (error) {
        console.error('Secret document redaction failed:', error);
        redactionStatus = 'FAILED';
        redactionSummary = {
          reason: 'redaction_exception',
          message: error.message,
        };
      }
    }

    await run(
      `INSERT INTO public."Document"
        (
          id,
          "clientId",
          name,
          "fileUrl",
          "sharedWith",
          "isEncrypted",
          "uploadedAt",
          "storageKey",
          "mimeType",
          "sizeBytes",
          checksum,
          "updatedAt",
          classification,
          "secretCategory",
          "redactionStatus",
          "redactedStorageKey",
          "redactionSummary",
          "redactionReviewedAt",
          "redactionReviewedByUserId"
        )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        clientProfile.id,
        req.file.originalname,
        `/api/v1/documents/${id}/download`,
        [],
        true,
        nowIso(),
        storageKey,
        req.file.mimetype || 'application/octet-stream',
        req.file.size || 0,
        fileChecksum(req.file.buffer),
        nowIso(),
        classification,
        secretCategory,
        redactionStatus,
        redactedStorageKey,
        redactionSummary ? JSON.stringify(redactionSummary) : null,
        null,
        null,
      ]
    );

    await writeAudit({
      actorUserId: req.user.id,
      eventType: classification === 'SECRET' ? 'document.secret_uploaded' : 'document.uploaded',
      targetType: 'document',
      targetId: id,
      ipAddress: req.ip,
    });

    const row = await get(
      `SELECT * FROM public."Document" WHERE id = ?`,
      [id]
    );

    res.status(201).json({ item: mapDocument(row) });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/preview', authRequired, requireRole('client'), async (req, res, next) => {
  try {
    const clientProfile = await getClientProfile(req.user.id);
    if (!clientProfile) {
      return res.status(400).json({ error: 'Client profile not found.' });
    }

    const doc = await get(
      `SELECT * FROM public."Document"
       WHERE id = ? AND "clientId" = ?`,
      [req.params.id, clientProfile.id]
    );

    if (!doc) {
      return res.status(404).json({ error: 'Document not found.' });
    }

    if (String(doc.classification || '').toUpperCase() !== 'SECRET') {
      return res.status(400).json({
        error: 'Preview is only required for secret documents.',
      });
    }

    if (doc.redactionStatus !== 'READY' || !doc.redactedStorageKey) {
      return res.status(409).json({
        error: 'Redacted preview is not ready yet.',
      });
    }

    const previewMime = detectMimeFromStorageKey(doc.redactedStorageKey);
    if (previewMime === 'application/pdf') {
      return res.status(409).json({
        error: 'This secret PDF type does not use the image preview approval flow.',
      });
    }

    const previewPath = resolveStoredPathFromKey(doc.redactedStorageKey);
    if (!previewPath || !fs.existsSync(previewPath)) {
      return res.status(404).json({ error: 'Redacted preview file not found.' });
    }

    res.setHeader('Content-Type', previewMime);
    res.setHeader(
      'Content-Disposition',
      `inline; filename="preview_${path.parse(doc.name || 'document').name}.png"`
    );
    res.sendFile(previewPath);
  } catch (error) {
    next(error);
  }
});

router.post('/:id/mark-reviewed', authRequired, requireRole('client'), async (req, res, next) => {
  try {
    const clientProfile = await getClientProfile(req.user.id);
    if (!clientProfile) {
      return res.status(400).json({ error: 'Client profile not found.' });
    }

    const doc = await get(
      `SELECT * FROM public."Document"
       WHERE id = ? AND "clientId" = ?`,
      [req.params.id, clientProfile.id]
    );

    if (!doc) {
      return res.status(404).json({ error: 'Document not found.' });
    }

    if (!requiresPreviewBeforeShare(doc)) {
      return res.status(400).json({
        error: 'This document does not require mandatory preview review.',
      });
    }

    if (doc.redactionStatus !== 'READY' || !doc.redactedStorageKey) {
      return res.status(409).json({
        error: 'Redacted preview is not ready yet.',
      });
    }

    await run(
      `UPDATE public."Document"
       SET "redactionReviewedAt" = ?, "redactionReviewedByUserId" = ?, "updatedAt" = ?
       WHERE id = ?`,
      [nowIso(), req.user.id, nowIso(), doc.id]
    );

    await writeAudit({
      actorUserId: req.user.id,
      eventType: 'document.redaction_reviewed',
      targetType: 'document',
      targetId: doc.id,
      ipAddress: req.ip,
    });

    const updated = await get(
      `SELECT * FROM public."Document" WHERE id = ?`,
      [doc.id]
    );

    res.json({ item: mapDocument(updated) });
  } catch (error) {
    next(error);
  }
});

router.post(
  '/:id/share',
  authRequired,
  requireRole('client'),
  validateBody(shareDocumentSchema),
  async (req, res, next) => {
    try {
      const { lawyerId, allowRiskyShare = false } = req.validatedBody;

      const clientProfile = await getClientProfile(req.user.id);
      if (!clientProfile) {
        return res.status(400).json({ error: 'Client profile not found.' });
      }

      const doc = await get(
        `SELECT * FROM public."Document"
         WHERE id = ? AND "clientId" = ?`,
        [req.params.id, clientProfile.id]
      );

      if (!doc) {
        return res.status(404).json({ error: 'Document not found.' });
      }

      if (String(doc.classification || '').toUpperCase() === 'SECRET') {
        const status = String(doc.redactionStatus || '').toUpperCase();

        if (status === 'READY') {
          if (requiresPreviewBeforeShare(doc) && !doc.redactionReviewedAt) {
            return res.status(409).json({
              error: 'You must preview and approve the blurred NIC copy before sharing.',
            });
          }
        } else if (status === 'MANUAL_REQUIRED') {
          if (!allowRiskyShare) {
            return res.status(409).json({
              error:
                'This secret document needs manual review. Send allowRiskyShare=true only if you want to share the original unblurred file.',
            });
          }

          await run(
            `UPDATE public."Document"
             SET "manualShareApprovedAt" = ?, "manualShareApprovedByUserId" = ?, "updatedAt" = ?
             WHERE id = ?`,
            [nowIso(), req.user.id, nowIso(), doc.id]
          );

          doc.manualShareApprovedAt = nowIso();
          doc.manualShareApprovedByUserId = req.user.id;
        } else {
          return res.status(409).json({
            error: 'Secret document cannot be shared until redaction is ready or risky share is explicitly approved.',
          });
        }
      }

      const lawyerProfile = await get(
        `SELECT * FROM public."LawyerProfile" WHERE id = ?`,
        [lawyerId]
      );

      if (!lawyerProfile) {
        return res.status(400).json({ error: 'Valid lawyerId is required.' });
      }

      const allowed = await hasAssignment(clientProfile.id, lawyerProfile.id);
      if (!allowed) {
        return res.status(403).json({
          error: 'You can only share documents with an assigned lawyer.',
        });
      }

      const current = asArray(doc.sharedWith);
      const nextSharedWith = Array.from(new Set([...current, lawyerProfile.id]));

      await run(
        `UPDATE public."Document"
         SET "sharedWith" = ?, "updatedAt" = ?
         WHERE id = ?`,
        [nextSharedWith, nowIso(), doc.id]
      );

      await createNotification({
        userId: lawyerProfile.userId,
        type: 'document.shared',
        title: 'New shared document',
        body:
          String(doc.classification || '').toUpperCase() === 'SECRET'
            ? String(doc.redactionStatus || '').toUpperCase() === 'MANUAL_REQUIRED'
              ? `${doc.name} was shared with you with a privacy risk warning.`
              : `${doc.name} was shared with you as a redacted copy.`
            : `${doc.name} was shared with you.`,
        data: {
          documentId: doc.id,
          screen: 'documents',
        },
      });

      await writeAudit({
        actorUserId: req.user.id,
        eventType:
          String(doc.redactionStatus || '').toUpperCase() === 'MANUAL_REQUIRED'
            ? 'document.risky_shared'
            : 'document.shared',
        targetType: 'document',
        targetId: doc.id,
        ipAddress: req.ip,
      });

      const updated = await get(
        `SELECT * FROM public."Document" WHERE id = ?`,
        [doc.id]
      );

      res.status(201).json({ item: mapDocument(updated) });
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/:id/revoke',
  authRequired,
  requireRole('client'),
  validateBody(shareDocumentSchema),
  async (req, res, next) => {
    try {
      const { lawyerId } = req.validatedBody;

      const clientProfile = await getClientProfile(req.user.id);
      if (!clientProfile) {
        return res.status(400).json({ error: 'Client profile not found.' });
      }

      const doc = await get(
        `SELECT * FROM public."Document"
         WHERE id = ? AND "clientId" = ?`,
        [req.params.id, clientProfile.id]
      );

      if (!doc) {
        return res.status(404).json({ error: 'Document not found.' });
      }

      const nextSharedWith = asArray(doc.sharedWith).filter((id) => id !== lawyerId);

      await run(
        `UPDATE public."Document"
         SET "sharedWith" = ?, "updatedAt" = ?
         WHERE id = ?`,
        [nextSharedWith, nowIso(), doc.id]
      );

      const lawyerProfile = await get(
        `SELECT * FROM public."LawyerProfile" WHERE id = ?`,
        [lawyerId]
      );

      if (lawyerProfile?.userId) {
        await createNotification({
          userId: lawyerProfile.userId,
          type: 'document.revoked',
          title: 'Document access revoked',
          body: `${doc.name} is no longer shared with you.`,
          data: {
            documentId: doc.id,
            screen: 'documents',
          },
        });
      }

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'document.revoked',
        targetType: 'document',
        targetId: doc.id,
        ipAddress: req.ip,
      });

      const updated = await get(
        `SELECT * FROM public."Document" WHERE id = ?`,
        [doc.id]
      );

      res.json({ item: mapDocument(updated) });
    } catch (error) {
      next(error);
    }
  }
);

router.delete('/:id', authRequired, requireRole('client'), async (req, res, next) => {
  try {
    const clientProfile = await getClientProfile(req.user.id);
    if (!clientProfile) {
      return res.status(400).json({ error: 'Client profile not found.' });
    }

    const doc = await get(
      `SELECT * FROM public."Document"
       WHERE id = ? AND "clientId" = ?`,
      [req.params.id, clientProfile.id]
    );

    if (!doc) {
      return res.status(404).json({ error: 'Document not found.' });
    }

    const originalPath = resolveStoredPath(doc);
    const redactedPath = resolveStoredPathFromKey(doc.redactedStorageKey);

    await run(
      `DELETE FROM public."Document"
       WHERE id = ?`,
      [doc.id]
    );

    deleteFileIfExists(originalPath);
    deleteFileIfExists(redactedPath);

    await writeAudit({
      actorUserId: req.user.id,
      eventType: 'document.deleted',
      targetType: 'document',
      targetId: doc.id,
      ipAddress: req.ip,
    });

    res.json({
      success: true,
      deletedId: doc.id,
    });
  } catch (error) {
    next(error);
  }
});

router.post('/:id/download-token', authRequired, async (req, res, next) => {
  try {
    const doc = await get(
      `SELECT * FROM public."Document" WHERE id = ?`,
      [req.params.id]
    );

    if (!doc) {
      return res.status(404).json({ error: 'Document not found.' });
    }

    const allowed = await canUserAccessDocument(req.user, doc);
    if (!allowed) {
      return res.status(403).json({ error: 'Forbidden.' });
    }

    const target = resolveDownloadTargetForRequester({
      doc,
      requesterRole: req.user.role,
    });

    const token = issueDocumentDownloadToken({
      documentId: doc.id,
      userId: req.user.id,
      variant: target.variant,
    });

    return res.json({
      token,
      variant: target.variant,
      expiresInSeconds: 120,
      url: `/api/v1/documents/${doc.id}/download-by-token?token=${encodeURIComponent(
        token
      )}`,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ error: error.message });
    }
    next(error);
  }
});

router.get('/:id/download-by-token', async (req, res, next) => {
  try {
    const token = String(req.query.token || '').trim();

    if (!token) {
      return res.status(401).json({ error: 'Missing download token.' });
    }

    const payload = verifyDocumentDownloadToken(token);

    if (String(payload.docId) !== String(req.params.id)) {
      return res.status(401).json({ error: 'Token/document mismatch.' });
    }

    const doc = await get(
      `SELECT * FROM public."Document" WHERE id = ?`,
      [req.params.id]
    );

    if (!doc) {
      return res.status(404).json({ error: 'Document not found.' });
    }

    const target = resolveDownloadTargetForRequester({
      doc,
      requesterRole: null,
      forcedVariant: payload.variant || 'original',
    });

    const payloadBuffer = readStoredFileBuffer(target.filePath);

    return sendBufferDownload(res, {
      payload: payloadBuffer,
      contentType: target.contentType,
      downloadName: target.downloadName,
    });
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired download token.' });
  }
});

router.get('/:id/download', authRequired, async (req, res, next) => {
  try {
    const doc = await get(
      `SELECT * FROM public."Document" WHERE id = ?`,
      [req.params.id]
    );

    if (!doc) {
      return res.status(404).json({ error: 'Document not found.' });
    }

    const allowed = await canUserAccessDocument(req.user, doc);
    if (!allowed) {
      return res.status(403).json({ error: 'Forbidden.' });
    }

    const target = resolveDownloadTargetForRequester({
      doc,
      requesterRole: req.user.role,
    });

    const payload = readStoredFileBuffer(target.filePath);

    return sendBufferDownload(res, {
      payload,
      contentType: target.contentType,
      downloadName: target.downloadName,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ error: error.message });
    }
    next(error);
  }
});

module.exports = router;