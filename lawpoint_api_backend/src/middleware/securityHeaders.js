const helmet = require('helmet');

function securityHeaders() {
  return helmet({
    crossOriginEmbedderPolicy: false,
    contentSecurityPolicy: false,
  });
}

module.exports = { securityHeaders };