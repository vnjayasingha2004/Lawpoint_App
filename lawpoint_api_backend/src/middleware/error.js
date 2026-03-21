function errorHandler(error, req, res, next) {
  console.error(error);
  if (res.headersSent) return next(error);
  res.status(error.statusCode || 500).json({
    error: error.publicMessage || 'Internal server error'
  });
}

module.exports = { errorHandler };
