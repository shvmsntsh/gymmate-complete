let warnedMissingSecret = false;

function getJwtSecret() {
  if (process.env.JWT_SECRET) {
    return process.env.JWT_SECRET;
  }

  const isProduction =
    process.env.NODE_ENV === 'production' || process.env.VERCEL_ENV === 'production';

  if (isProduction) {
    throw new Error('JWT_SECRET is required in production.');
  }

  if (!warnedMissingSecret) {
    warnedMissingSecret = true;
    console.warn('⚠️ JWT_SECRET missing; using development-only JWT secret.');
  }

  return 'development-only-jwt-secret';
}

module.exports = { getJwtSecret };
