const fs = require('fs');
const path = require('path');
const { chromium, devices } = require('playwright');

const MOBILE_BASE = process.env.GYMMATE_MOBILE_BASE || 'http://127.0.0.1:58967';
const WEB_BASE = process.env.GYMMATE_WEB_BASE || 'http://127.0.0.1:4173';
const API_BASE = process.env.GYMMATE_API_BASE || 'http://127.0.0.1:5050';
const SCREENSHOT_DIR = '/Users/shivamsantosh/gymmate_mvp/deploy/qa/screenshots';
const REPORT_PATH = '/Users/shivamsantosh/gymmate_mvp/deploy/qa/qa-report.json';

const accounts = {
  admin: { email: 'demo_admin@gymmate.local', password: 'DemoAdmin123!' },
  owner: { email: 'demo_owner_iron@gymmate.local', password: 'DemoOwner123!' },
  trainer: { email: 'demo_trainer_iron@gymmate.local', password: 'DemoTrainer123!' },
  member: { email: 'demo_member_iron@gymmate.local', password: 'DemoMember123!' },
};

function sanitizeErrorText(value) {
  return String(value || '')
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[redacted-jwt]')
    .replace(/"token"\s*:\s*"[^"]+"/gi, '"token":"[redacted]"')
    .replace(/"password"\s*:\s*"[^"]+"/gi, '"password":"[redacted]"')
    .slice(0, 500);
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function joinUrl(base, route = '') {
  const normalizedBase = String(base || '').replace(/\/$/, '');
  const normalizedRoute = String(route || '').replace(/^\//, '');
  return normalizedRoute ? `${normalizedBase}/${normalizedRoute}` : normalizedBase;
}

async function apiJson(pathname, options = {}) {
  const res = await fetch(`${API_BASE}${pathname}`, options);
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    throw new Error(`${pathname} -> ${res.status}: ${sanitizeErrorText(JSON.stringify(json))}`);
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

async function getFirstGymId(adminSession) {
  try {
    const res = await fetch(`${API_BASE}/api/gym/list`, {
      headers: { Authorization: `Bearer ${adminSession.token}` },
    });
    const data = await res.json();
    if (!res.ok || !Array.isArray(data) || data.length === 0) {
      return null;
    }
    return data[0].id;
  } catch {
    return null;
  }
}

async function attachErrorCapture(page, record) {
  record.consoleErrors = [];
  record.pageErrors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      record.consoleErrors.push(sanitizeErrorText(msg.text()));
    }
  });
  page.on('pageerror', (error) => {
    record.pageErrors.push(sanitizeErrorText(error.stack || error.message || String(error)));
  });
}

async function setMobileSession(page, payload, { forceOnboarding = false, route = '' } = {}) {
  const user = {
    ...payload.user,
    role: payload.user.normalizedRole || payload.user.role,
    normalizedRole: payload.user.normalizedRole || payload.user.role,
    hasCompletedOnboarding: forceOnboarding
      ? false
      : payload.user.hasCompletedOnboarding ?? false,
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
  await page.goto(WEB_BASE, { waitUntil: 'networkidle' });
  await page.evaluate(({ payload, theme }) => {
    localStorage.clear();
    localStorage.setItem('gymmate_theme', theme);
    localStorage.setItem('gymmate_admin_token', payload.token);
    localStorage.setItem('gymmate_admin_session', JSON.stringify(payload));
    localStorage.setItem('gymmate_logged_in', 'true');
  }, { payload, theme });
}

async function captureMobile(browser, name, route, session, theme, options = {}) {
  console.log(`capturing mobile ${name} (${theme})`);
  const context = await browser.newContext({
    ...devices['iPhone 14 Pro Max'],
    colorScheme: theme,
  });
  const page = await context.newPage();
  const record = { name, theme, type: 'mobile', route };
  await attachErrorCapture(page, record);
  await setMobileSession(page, session, { route, forceOnboarding: options.forceOnboarding });
  await page.waitForTimeout(options.waitMs || 6500);

  if (options.afterLoad) {
    await options.afterLoad(page);
    await page.waitForTimeout(options.afterWaitMs || 1800);
  }

  const filePath = path.join(SCREENSHOT_DIR, `${name}-${theme}.png`);
  await page.screenshot({ path: filePath, fullPage: true });
  record.url = page.url();
  record.screenshot = path.basename(filePath);
  await context.close();
  return record;
}

async function captureWeb(browser, name, route, theme, setupFn) {
  console.log(`capturing web ${name} (${theme})`);
  const context = await browser.newContext({
    viewport: { width: 1512, height: 982 },
    colorScheme: theme,
  });
  const page = await context.newPage();
  const record = { name, theme, type: 'web', route };
  await attachErrorCapture(page, record);
  if (setupFn) {
    await setupFn(page, theme);
  }
  await page.goto(joinUrl(WEB_BASE, route), { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  const filePath = path.join(SCREENSHOT_DIR, `${name}-${theme}.png`);
  await page.screenshot({ path: filePath, fullPage: false });
  record.url = page.url();
  record.screenshot = path.basename(filePath);
  await context.close();
  return record;
}

async function openFirstTrainerClient(page) {
  await page.mouse.click(190, 535);
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

  const firstGymId = await getFirstGymId(sessions.admin);

  for (const theme of ['light', 'dark']) {
    results.push(await captureWeb(browser, 'public-home', '', theme));
    results.push(await captureWeb(browser, 'public-login', 'login', theme));
    results.push(await captureWeb(browser, 'public-register-gym', 'register-gym', theme));

    results.push(
      await captureMobile(
        browser,
        'mobile-onboarding-welcome',
        '',
        sessions.member,
        theme,
        { forceOnboarding: true, waitMs: 4500 },
      ),
    );

    results.push(await captureMobile(browser, 'mobile-owner-dashboard', '', sessions.owner, theme));
    results.push(await captureMobile(browser, 'mobile-owner-invites', '?tab=invites', sessions.owner, theme));
    results.push(await captureMobile(browser, 'mobile-owner-profile', '?tab=profile', sessions.owner, theme));

    results.push(await captureMobile(browser, 'mobile-admin-dashboard', '', sessions.admin, theme, { waitMs: 9000 }));
    results.push(await captureMobile(browser, 'mobile-admin-invites', '?tab=invites', sessions.admin, theme));
    results.push(await captureMobile(browser, 'mobile-admin-profile', '?tab=profile', sessions.admin, theme));

    results.push(await captureMobile(browser, 'mobile-member-dashboard', '', sessions.member, theme));
    results.push(await captureMobile(browser, 'mobile-member-plan', '?tab=plan', sessions.member, theme));
    results.push(await captureMobile(browser, 'mobile-member-coach', '?tab=coach', sessions.member, theme));
    results.push(await captureMobile(browser, 'mobile-member-profile', '?tab=profile', sessions.member, theme));

    results.push(await captureMobile(browser, 'mobile-trainer-dashboard', '', sessions.trainer, theme));
    results.push(await captureMobile(browser, 'mobile-trainer-clients', '?tab=clients', sessions.trainer, theme));
    results.push(await captureMobile(browser, 'mobile-trainer-messages', '?tab=messages', sessions.trainer, theme));
    results.push(await captureMobile(browser, 'mobile-trainer-profile', '?tab=profile', sessions.trainer, theme));
    results.push(
      await captureMobile(
        browser,
        'mobile-trainer-client-detail',
        '?tab=clients',
        sessions.trainer,
        theme,
        { afterLoad: openFirstTrainerClient, afterWaitMs: 2500 },
      ),
    );

    results.push(
      await captureWeb(browser, 'web-owner-dashboard', 'dashboard', theme, async (page, selectedTheme) => {
        await setWebSession(page, sessions.owner, selectedTheme);
      }),
    );
    results.push(
      await captureWeb(browser, 'web-owner-manage-members', 'manage-members', theme, async (page, selectedTheme) => {
        await setWebSession(page, sessions.owner, selectedTheme);
      }),
    );
    results.push(
      await captureWeb(browser, 'web-owner-invites', 'invites', theme, async (page, selectedTheme) => {
        await setWebSession(page, sessions.owner, selectedTheme);
      }),
    );
    results.push(
      await captureWeb(browser, 'web-owner-branding', 'branding', theme, async (page, selectedTheme) => {
        await setWebSession(page, sessions.owner, selectedTheme);
      }),
    );

    results.push(
      await captureWeb(browser, 'web-admin-dashboard', 'dashboard', theme, async (page, selectedTheme) => {
        await setWebSession(page, sessions.admin, selectedTheme);
      }),
    );
    results.push(
      await captureWeb(browser, 'web-admin-manage-members', 'manage-members', theme, async (page, selectedTheme) => {
        await setWebSession(page, sessions.admin, selectedTheme);
      }),
    );
    results.push(
      await captureWeb(browser, 'web-admin-register-gym', 'register-gym', theme, async (page, selectedTheme) => {
        await setWebSession(page, sessions.admin, selectedTheme);
      }),
    );
    if (firstGymId) {
      results.push(
        await captureWeb(browser, 'web-admin-gym-details', `gyms/${firstGymId}`, theme, async (page, selectedTheme) => {
          await setWebSession(page, sessions.admin, selectedTheme);
        }),
      );
    }
  }

  fs.writeFileSync(REPORT_PATH, JSON.stringify(results, null, 2));
  console.log(JSON.stringify(results, null, 2));
  await browser.close();
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
