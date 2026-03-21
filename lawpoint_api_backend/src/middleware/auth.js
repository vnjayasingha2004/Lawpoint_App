const jwt = require('jsonwebtoken');
const env = require('../config/env');
const { get } = require('../db');

async function authRequired(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ')
      ? header.slice(7).trim()
      : null;

    if (!token) {
      return res.status(401).json({ error: 'Missing bearer token' });
    }

    const payload = jwt.verify(token, env.jwtAccessSecret);

    if (!payload || !payload.sub) {
      return res.status(401).json({ error: 'Invalid token payload' });
    }

    const user = await get(
      `SELECT * FROM public."User" WHERE id = ? LIMIT 1`,
      [payload.sub]
    );

    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    req.user = {
      ...user,
      role: String(user.role || payload.role || '').toLowerCase(),
      isVerified: Boolean(user.isVerified),
    };

    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function requireRole(...roles) {
  const normalizedRoles = roles.map((r) => String(r).toLowerCase());

  return (req, res, next) => {
    const role = String(req.user?.role || '').toLowerCase();

    if (!req.user || !normalizedRoles.includes(role)) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    next();
  };
}

module.exports = { authRequired, requireRole };