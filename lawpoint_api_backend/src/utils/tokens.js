const jwt = require('jsonwebtoken');
const { v4: uuid } = require('uuid');
const { run } = require('../db');
const env = require('../config/env');
const { hashToken } = require('./crypto');
const { nowIso } = require('./time');

function accessPayload(user) {
  return {
    sub: user.id,
    role: user.role,
  };
}

function refreshPayload(user) {
  return {
    sub: user.id,
    role: user.role,
    type: 'refresh',
  };
}

async function issueTokens(user) {
  const accessToken = jwt.sign(
    accessPayload(user),
    env.jwtAccessSecret,
    { expiresIn: '15m' }
  );

  const refreshToken = jwt.sign(
    refreshPayload(user),
    env.jwtRefreshSecret,
    {
      expiresIn: '30d',
      jwtid: uuid(),
    }
  );

  const expiresAt = new Date(
    Date.now() + 30 * 24 * 60 * 60 * 1000
  ).toISOString();

  await run(
    `INSERT INTO public."RefreshToken"
      (id, "userId", "tokenHash", "expiresAt", "revokedAt", "createdAt")
     VALUES (?, ?, ?, ?, ?, ?)`,
    [
      uuid(),
      user.id,
      hashToken(refreshToken),
      expiresAt,
      null,
      nowIso(),
    ]
  );

  return {
    accessToken,
    refreshToken,
  };
}

module.exports = {
  issueTokens,
};