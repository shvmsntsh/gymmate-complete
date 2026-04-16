function digitsOnly(value) {
  return String(value || '').replace(/\D/g, '');
}

function normalizeIndianPhone(value) {
  const digits = digitsOnly(value);
  if (!digits) {
    return '';
  }

  let national = digits;
  if (digits.length === 12 && digits.startsWith('91')) {
    national = digits.slice(2);
  }

  if (national.length !== 10 || !/^[6-9]\d{9}$/.test(national)) {
    return '';
  }

  return `+91${national}`;
}

function indianPhoneVariants(value) {
  const normalized = normalizeIndianPhone(value);
  if (!normalized) {
    return [];
  }

  const national = normalized.slice(3);
  return [...new Set([normalized, national, `91${national}`, String(value || '').trim()].filter(Boolean))];
}

function looksLikeEmail(value) {
  return String(value || '').includes('@');
}

module.exports = {
  normalizeIndianPhone,
  indianPhoneVariants,
  looksLikeEmail,
};
