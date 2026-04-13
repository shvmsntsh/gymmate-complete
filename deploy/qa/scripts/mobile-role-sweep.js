const fs = require('fs');
const path = require('path');
const { chromium, devices } = require('playwright');

const MOBILE_BASE = process.env.GYMMATE_MOBILE_BASE || 'http://127.0.0.1:58967';
const API_BASE = process.env.GYMMATE_API_BASE || 'http://127.0.0.1:5050';
const outDir = '/Users/shivamsantosh/gymmate_mvp/deploy/qa/screenshots';
fs.mkdirSync(outDir, { recursive: true });

const roles = {
  owner: {
    email: 'demo_owner_iron@gymmate.local',
    password: 'DemoOwner123!',
    tabs: ['dashboard', 'invites', 'profile'],
  },
  trainer: {
    email: 'demo_trainer_iron@gymmate.local',
    password: 'DemoTrainer123!',
    tabs: ['dashboard', 'clients', 'messages', 'profile'],
  },
  member: {
    email: 'demo_member_iron@gymmate.local',
    password: 'DemoMember123!',
    tabs: ['dashboard', 'plan', 'coach', 'profile'],
  },
  admin: {
    email: 'demo_admin@gymmate.local',
    password: 'DemoAdmin123!',
    tabs: ['dashboard', 'invites', 'profile'],
  },
};

function sanitizeErrorText(value) {
  return String(value || '')
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[redacted-jwt]')
    .replace(/"token"\s*:\s*"[^"]+"/gi, '"token":"[redacted]"')
    .replace(/"password"\s*:\s*"[^"]+"/gi, '"password":"[redacted]"')
    .slice(0, 500);
}

function safeError(message, pathname, status) {
  const sanitized = sanitizeErrorText(message);
  return status ? `${pathname} -> ${status}: ${sanitized}` : sanitized;
}

function joinUrl(base, route = '') {
  const normalizedBase = String(base || '').replace(/\/$/, '');
  const normalizedRoute = String(route || '').replace(/^\//, '');
  return normalizedRoute ? `${normalizedBase}/${normalizedRoute}` : normalizedBase;
}

async function apiJson(pathname, options = {}) {
  const res = await fetch(`${API_BASE}${pathname}`, options);
  const text = await res.text();
  const json = JSON.parse(text);
  if (!res.ok) {
    throw new Error(safeError(JSON.stringify(json), pathname, res.status));
  }
  return json;
}

async function login(email, password) {
  return apiJson('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
}

async function getBranding(gymId) {
  if (!gymId) return {};
  try {
    return await apiJson(`/api/gym/branding/${gymId}`);
  } catch {
    return {};
  }
}

async function setMobileSession(page, payload, route = '') {
  const user = {
    ...payload.user,
    role: payload.user.normalizedRole || payload.user.role,
    normalizedRole: payload.user.normalizedRole || payload.user.role,
  };
  const branding = await getBranding(user.gymId);

  await page.goto(joinUrl(MOBILE_BASE, route), { waitUntil: 'networkidle' });
  await page.evaluate(async ({ token, user, branding }) => {
    const toB64 = (bytes) => {
      let binary = '';
      const chunkSize = 0x8000;
      for (let i = 0; i < bytes.length; i += chunkSize) {
        binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
      }
      return btoa(binary);
    };

    const getKey = async () => {
      const publicKeyName = 'FlutterSecureStorage';
      const existing = localStorage.getItem(publicKeyName);
      if (existing) {
        const raw = Uint8Array.from(atob(existing), (c) => c.charCodeAt(0));
        return crypto.subtle.importKey(
          'raw',
          raw,
          { name: 'AES-GCM', length: 256 },
          false,
          ['encrypt', 'decrypt'],
        );
      }

      const generated = await crypto.subtle.generateKey(
        { name: 'AES-GCM', length: 256 },
        true,
        ['encrypt', 'decrypt'],
      );
      const raw = new Uint8Array(await crypto.subtle.exportKey('raw', generated));
      localStorage.setItem(publicKeyName, toB64(raw));
      return crypto.subtle.importKey(
        'raw',
        raw,
        { name: 'AES-GCM', length: 256 },
        false,
        ['encrypt', 'decrypt'],
      );
    };

    const writeSecure = async (key, value) => {
      const cryptoKey = await getKey();
      const iv = crypto.getRandomValues(new Uint8Array(12));
      const encrypted = new Uint8Array(
        await crypto.subtle.encrypt(
          { name: 'AES-GCM', iv },
          cryptoKey,
          new TextEncoder().encode(value),
        ),
      );
      localStorage.setItem(`FlutterSecureStorage.${key}`, `${toB64(iv)}.${toB64(encrypted)}`);
    };

    localStorage.clear();
    const entries = {
      user_token: token,
      user_data: JSON.stringify(user),
      user_id: user.id || '',
      user_role: user.normalizedRole || user.role || '',
      user_name: user.name || '',
      user_email: user.email || '',
      gym_name: user.gymName || '',
      has_completed_onboarding: String(Boolean(user.hasCompletedOnboarding ?? true)),
      avatar_path: user.avatarPath || '',
      branding_data: JSON.stringify(branding || {}),
    };

    for (const [key, value] of Object.entries(entries)) {
      await writeSecure(key, String(value ?? ''));
    }
  }, { token: payload.token, user, branding });

  await page.reload({ waitUntil: 'networkidle' });
}

async function screenshot(page, name) {
  await page.screenshot({ path: path.join(outDir, name), fullPage: true });
}

function attachConsole(page, bucket) {
  page.on('console', (msg) => {
    if (msg.type() === 'error' || msg.type() === 'warning') {
      bucket.push(sanitizeErrorText(`[${msg.type()}] ${msg.text()}`));
    }
  });
  page.on('pageerror', (err) => {
    bucket.push(sanitizeErrorText(`[pageerror] ${err.message}`));
  });
}

async function runRole(roleName, creds) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    ...devices['iPhone 14 Pro Max'],
  });
  const page = await context.newPage();
  const errors = [];
  attachConsole(page, errors);

  const session = await login(creds.email, creds.password);
  const shots = [];

  for (const tab of creds.tabs) {
    const route = tab === 'dashboard' ? '' : `?tab=${tab}`;
    await setMobileSession(page, session, route);
    await page.waitForTimeout(tab === 'dashboard' && roleName === 'admin' ? 9000 : 6500);
    const file = `mobile-${roleName}-${tab}-sweep.png`;
    await screenshot(page, file);
    shots.push(file);
  }

  const sessionState = await page.evaluate(() => ({
    hasSecureToken: Boolean(localStorage.getItem('FlutterSecureStorage.user_token')),
    hasSecureUserData: Boolean(localStorage.getItem('FlutterSecureStorage.user_data')),
    hasBrandingData: Boolean(localStorage.getItem('FlutterSecureStorage.branding_data')),
  }));

  await browser.close();

  return {
    role: roleName,
    mobileBase: MOBILE_BASE,
    screenshots: shots,
    errors: errors.map(sanitizeErrorText),
    loginSucceeded: Boolean(session?.token),
    sessionState,
  };
}

(async () => {
  const report = {
    mobileBase: MOBILE_BASE,
    apiBase: API_BASE,
    generatedAt: new Date().toISOString(),
    roles: {},
  };

  for (const [roleName, creds] of Object.entries(roles)) {
    report.roles[roleName] = await runRole(roleName, creds);
  }

  const outFile = '/Users/shivamsantosh/gymmate_mvp/deploy/qa/mobile-role-sweep-report.json';
  fs.writeFileSync(outFile, JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
})();
