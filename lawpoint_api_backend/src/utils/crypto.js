const crypto = require('crypto');
const env = require('../config/env');

const fieldKey = Buffer.from(env.fieldEncryptionKey, 'hex');
const hmacKey = Buffer.from(env.lookupHmacKey, 'hex');
const fileMasterKey = Buffer.from(env.fileEncryptionMasterKey, 'hex');

const FILE_ENVELOPE_MAGIC = 'LAWPOINT_FILE_V1';
const GCM_IV_LENGTH = 12;

function normalizeLookupValue(value) {
  return String(value).trim().toLowerCase();
}

function lookupHash(value) {
  if (!value) return null;

  return crypto
    .createHmac('sha256', hmacKey)
    .update(normalizeLookupValue(value))
    .digest('hex');
}

function hashOtpCode(code) {
  if (!code) return null;

  return crypto
    .createHmac('sha256', hmacKey)
    .update(`otp:${String(code).trim()}`)
    .digest('hex');
}

function encryptText(plainText) {
  if (plainText == null) return null;

  const iv = crypto.randomBytes(GCM_IV_LENGTH);
  const cipher = crypto.createCipheriv('aes-256-gcm', fieldKey, iv);
  const encrypted = Buffer.concat([
    cipher.update(String(plainText), 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();

  return Buffer.concat([iv, tag, encrypted]).toString('base64');
}

function decryptText(payload) {
  if (!payload) return null;

  const raw = Buffer.from(payload, 'base64');
  const iv = raw.subarray(0, GCM_IV_LENGTH);
  const tag = raw.subarray(GCM_IV_LENGTH, GCM_IV_LENGTH + 16);
  const encrypted = raw.subarray(GCM_IV_LENGTH + 16);

  const decipher = crypto.createDecipheriv('aes-256-gcm', fieldKey, iv);
  decipher.setAuthTag(tag);

  const decrypted = Buffer.concat([
    decipher.update(encrypted),
    decipher.final(),
  ]);

  return decrypted.toString('utf8');
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function fileChecksum(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function encryptAes256GcmBuffer(buffer, key) {
  const iv = crypto.randomBytes(GCM_IV_LENGTH);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);

  const ciphertext = Buffer.concat([cipher.update(buffer), cipher.final()]);
  const tag = cipher.getAuthTag();

  return { iv, tag, ciphertext };
}

function decryptAes256GcmBuffer({ iv, tag, ciphertext }, key) {
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);

  return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
}

function asBuffer(value) {
  if (Buffer.isBuffer(value)) return value;
  if (value == null) return Buffer.alloc(0);
  return Buffer.from(value);
}

function encryptFileBuffer(fileBuffer) {
  const plainBuffer = asBuffer(fileBuffer);
  const dataKey = crypto.randomBytes(32);

  const filePayload = encryptAes256GcmBuffer(plainBuffer, dataKey);
  const wrappedKeyPayload = encryptAes256GcmBuffer(dataKey, fileMasterKey);

  const envelope = {
    magic: FILE_ENVELOPE_MAGIC,
    version: 1,
    algorithm: 'aes-256-gcm',
    wrappedKey: {
      iv: wrappedKeyPayload.iv.toString('base64'),
      tag: wrappedKeyPayload.tag.toString('base64'),
      ciphertext: wrappedKeyPayload.ciphertext.toString('base64'),
    },
    file: {
      iv: filePayload.iv.toString('base64'),
      tag: filePayload.tag.toString('base64'),
      ciphertext: filePayload.ciphertext.toString('base64'),
    },
  };

  return Buffer.from(JSON.stringify(envelope), 'utf8');
}

function parseFileEnvelope(buffer) {
  try {
    const parsed = JSON.parse(Buffer.from(buffer).toString('utf8'));

    if (
      !parsed ||
      parsed.magic !== FILE_ENVELOPE_MAGIC ||
      Number(parsed.version) !== 1
    ) {
      return null;
    }

    if (
      !parsed.wrappedKey ||
      !parsed.file ||
      !parsed.wrappedKey.iv ||
      !parsed.wrappedKey.tag ||
      !parsed.wrappedKey.ciphertext ||
      !parsed.file.iv ||
      !parsed.file.tag ||
      !parsed.file.ciphertext
    ) {
      return null;
    }

    return parsed;
  } catch {
    return null;
  }
}

function isEncryptedFileEnvelope(buffer) {
  return Boolean(parseFileEnvelope(buffer));
}

function decryptFileBuffer(storedBuffer) {
  const rawBuffer = asBuffer(storedBuffer);
  const envelope = parseFileEnvelope(rawBuffer);

  // Backward compatibility: old files were stored as plaintext.
  if (!envelope) {
    return rawBuffer;
  }

  const unwrappedKey = decryptAes256GcmBuffer(
    {
      iv: Buffer.from(envelope.wrappedKey.iv, 'base64'),
      tag: Buffer.from(envelope.wrappedKey.tag, 'base64'),
      ciphertext: Buffer.from(envelope.wrappedKey.ciphertext, 'base64'),
    },
    fileMasterKey
  );

  return decryptAes256GcmBuffer(
    {
      iv: Buffer.from(envelope.file.iv, 'base64'),
      tag: Buffer.from(envelope.file.tag, 'base64'),
      ciphertext: Buffer.from(envelope.file.ciphertext, 'base64'),
    },
    unwrappedKey
  );
}

module.exports = {
  lookupHash,
  hashOtpCode,
  encryptText,
  decryptText,
  hashToken,
  fileChecksum,
  encryptFileBuffer,
  decryptFileBuffer,
  isEncryptedFileEnvelope,
};