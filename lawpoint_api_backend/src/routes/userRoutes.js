const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const { hydrateUser } = require('../services/userService');

router.get('/me', authRequired, async (req, res, next) => {
  try {
    const user = await hydrateUser(req.user);
    return res.json(user);
  } catch (error) {
    next(error);
  }
});

module.exports = router;