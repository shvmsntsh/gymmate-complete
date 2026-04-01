const fs = require('fs');
const path = require('path');
const { chromium, devices } = require('playwright');

const BASE_URL = process.env.GYMMATE_QA_BASE || 'http://localhost:3100';
const SCREENSHOT_DIR = '/Users/shivamsantosh/gymmate_mvp/deploy/qa/screenshots';
const REPORT_PATH = '/Users/shivamsantosh/gymmate_mvp/deploy/qa/qa-report.json';

const accounts = {
  admin: { email: 'demo_admin@gymmate.local', password: 'DemoAdmin123!' },
  owner: { email: 'demo_owner_iron@gymmate.local', password: 'DemoOwner123!' },
  trainer: { email: 'demo_trainer_iron@gymmate.local', password: 'DemoTrainer123!' },
  member: { email: 'demo_member_iron@gymmate.local', password: 'DemoMember123!' },
};

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function toBase64(bytes) {
  let binary = '';
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return Buffer.from(binary, 'binary').toString('base64');
}

async function apiJson(pathname, options = {}) {
  const res = await fetch(`${BASE_URL}${pathname}`, options);
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    throw new Error(`${pathname} -> ${res.status}: ${JSON.stringify(json)}`);
  }
  return json;
}

async function login(creds) {
  return apiJson('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(creds),
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

async function attachErrorCapture(page, record) {
  record.consoleErrors = [];
  record.pageErrors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      record.consoleErrors.push(msg.text());
    }
  });
  page.on('pageerror', (error) => {
    record.pageErrors.push(error.stack || error.message || String(error));
  });
}

async function setMobileSession(page, payload, { forceOnboarding = false } = {}) {
  const user = {
    ...payload.user,
    role: payload.user.normalizedRole || payload.user.role,
    normalizedRole: payload.user.normalizedRole || payload.user.role,
    hasCompletedOnboarding: forceOnboarding
      ? false
      : payload.user.hasCompletedOnboarding ?? false,
  };
  const branding = await getBranding(user.gymId);

  await page.goto(BASE_URL, { waitUntil: 'networkidle' });
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
      has_completed_onboarding: String(Boolean(user.hasCompletedOnboarding)),
      avatar_path: user.avatarPath || '',
      branding_data: JSON.stringify(branding || {}),
    };

    for (const [key, value] of Object.entries(entries)) {
      await writeSecure(key, String(value ?? ''));
    }
  }, { token: payload.token, user, branding });

  await page.reload({ waitUntil: 'networkidle' });
}

async function setWebSession(page, payload, theme) {
  await page.goto(`${BASE_URL}/admin`, { waitUntil: 'networkidle' });
  await page.evaluate(({ payload, theme }) => {
    localStorage.clear();
    localStorage.setItem('gymmate_theme', theme);
    localStorage.setItem('gymmate_admin_token', payload.token);
    localStorage.setItem('gymmate_admin_session', JSON.stringify(payload));
    localStorage.setItem('gymmate_logged_in', 'true');
  }, { payload, theme });
}

async function captureMobile(browser, name, setupFn, theme = 'light') {
  console.log(`capturing mobile ${name} (${theme})`);
  const context = await browser.newContext({
    ...devices['iPhone 14 Pro Max'],
    colorScheme: theme,
  });
  const page = await context.newPage();
  const record = { name, theme, type: 'mobile' };
  await attachErrorCapture(page, record);
  await setupFn(page);
  record.consoleErrors = [];
  record.pageErrors = [];
  await page.waitForTimeout(_mobileSettleDelay(name));
  const filePath = path.join(SCREENSHOT_DIR, `${name}-${theme}.png`);
  await page.screenshot({ path: filePath, fullPage: true });
  record.url = page.url();
  record.screenshot = filePath;
  await context.close();
  return record;
}

async function captureWeb(browser, name, route, setupFn, theme = 'light') {
  console.log(`capturing web ${name} (${theme})`);
  const context = await browser.newContext({
    viewport: { width: 1512, height: 982 },
    colorScheme: theme,
  });
  const page = await context.newPage();
  const record = { name, theme, type: 'web' };
  await attachErrorCapture(page, record);
  await setupFn(page, theme);
  record.consoleErrors = [];
  record.pageErrors = [];
  await page.goto(`${BASE_URL}${route}`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  const filePath = path.join(SCREENSHOT_DIR, `${name}-${theme}.png`);
  await page.screenshot({ path: filePath, fullPage: false });
  record.url = page.url();
  record.screenshot = filePath;
  await context.close();
  return record;
}

function _mobileSettleDelay(name) {
  if (name === 'mobile-admin-dashboard') {
    return 9500;
  }
  if (name === 'mobile-onboarding-welcome') {
    return 4500;
  }
  return 6500;
}

(async () => {
  ensureDir(SCREENSHOT_DIR);
  const browser = await chromium.launch({ headless: true });
  const results = [];

  const sessions = {
    admin: await login(accounts.admin),
    owner: await login(accounts.owner),
    trainer: await login(accounts.trainer),
    member: await login(accounts.member),
  };

  for (const theme of ['light', 'dark']) {
    results.push(
      await captureMobile(browser, 'mobile-entry', async (page) => {
        await page.goto(BASE_URL, { waitUntil: 'networkidle' });
        await page.waitForTimeout(3000);
      }, theme),
    );

    results.push(
      await captureMobile(browser, 'mobile-onboarding-welcome', async (page) => {
        await setMobileSession(page, sessions.member, { forceOnboarding: true });
      }, theme),
    );

    results.push(
      await captureMobile(browser, 'mobile-member-dashboard', async (page) => {
        await setMobileSession(page, sessions.member);
      }, theme),
    );

    results.push(
      await captureMobile(browser, 'mobile-owner-dashboard', async (page) => {
        await setMobileSession(page, sessions.owner);
      }, theme),
    );

    results.push(
      await captureMobile(browser, 'mobile-trainer-dashboard', async (page) => {
        await setMobileSession(page, sessions.trainer);
      }, theme),
    );

    results.push(
      await captureMobile(browser, 'mobile-admin-dashboard', async (page) => {
        await setMobileSession(page, sessions.admin);
      }, theme),
    );

    results.push(
      await captureWeb(browser, 'web-admin-dashboard', '/admin/dashboard', async (page, selectedTheme) => {
        await setWebSession(page, sessions.admin, selectedTheme);
      }, theme),
    );

    results.push(
      await captureWeb(browser, 'web-owner-dashboard', '/admin/dashboard', async (page, selectedTheme) => {
        await setWebSession(page, sessions.owner, selectedTheme);
      }, theme),
    );

    results.push(
      await captureWeb(browser, 'web-owner-invites', '/admin/invites', async (page, selectedTheme) => {
        await setWebSession(page, sessions.owner, selectedTheme);
      }, theme),
    );

    results.push(
      await captureWeb(browser, 'web-owner-branding', '/admin/branding', async (page, selectedTheme) => {
        await setWebSession(page, sessions.owner, selectedTheme);
      }, theme),
    );
  }

  fs.writeFileSync(REPORT_PATH, JSON.stringify(results, null, 2));
  console.log(JSON.stringify(results, null, 2));
  await browser.close();
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
