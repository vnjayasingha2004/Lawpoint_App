const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(process.cwd(), '.env') });

function required(name) {
  const value = process.env[name];
  if (value == null || String(value).trim() === '') {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return String(value).trim();
}

function requiredHexKey(name, bytes = 32) {
  const value = required(name);
  const expectedLength = bytes * 2;

  if (!new RegExp(`^[0-9a-fA-F]{${expectedLength}}$`).test(value)) {
    throw new Error(
      `${name} must be exactly ${expectedLength} hex characters (${bytes} bytes).`
    );
  }

  return value.toLowerCase();
}

module.exports = {
  port: Number(process.env.PORT || 3000),
  nodeEnv: process.env.NODE_ENV || 'development',

  jwtAccessSecret: required('JWT_ACCESS_SECRET'),
  jwtRefreshSecret: required('JWT_REFRESH_SECRET'),

  fieldEncryptionKey: requiredHexKey('FIELD_ENCRYPTION_KEY', 32),
  lookupHmacKey: requiredHexKey('LOOKUP_HMAC_KEY', 32),
  fileEncryptionMasterKey: requiredHexKey('FILE_ENCRYPTION_MASTER_KEY', 32),

  otpDevBypass:
    String(process.env.OTP_DEV_BYPASS || 'false').toLowerCase() === 'true',

  allowedOrigins: String(process.env.ALLOWED_ORIGINS || '*').trim() || '*',

  storageDir: process.env.STORAGE_DIR
    ? path.resolve(process.cwd(), process.env.STORAGE_DIR)
    : path.join(__dirname, '../../storage'),
};