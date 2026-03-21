const jwt = require('jsonwebtoken');
const env = require('../config/env');

function issueDocumentDownloadToken({
  documentId,
  userId,
  variant = 'original',
  expiresIn = '120s',
}) {
  return jwt.sign(
    {
      type: 'document_download',
      docId: documentId,
      sub: userId,
      variant,
    },
    env.jwtAccessSecret,
    { expiresIn }
  );
}

function verifyDocumentDownloadToken(token) {
  const payload = jwt.verify(token, env.jwtAccessSecret);

  if (
    !payload ||
    payload.type !== 'document_download' ||
    !payload.docId ||
    !payload.sub
  ) {
    throw new Error('Invalid document download token.');
  }

  return payload;
}

module.exports = {
  issueDocumentDownloadToken,
  verifyDocumentDownloadToken,
};