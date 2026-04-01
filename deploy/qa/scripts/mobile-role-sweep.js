const { chromium } = require('/tmp/gymmate-qa/node_modules/playwright');
const fs = require('fs');
const path = require('path');

const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const outDir = '/Users/shivamsantosh/gymmate_mvp/deploy/qa/screenshots';
fs.mkdirSync(outDir, { recursive: true });

const APP_URL = process.env.APP_URL || 'http://127.0.0.1:8090';
const API_URL = process.env.API_URL || 'http://127.0.0.1:5050';

const qaRoles = {
  owner: {
    email: 'qa_owner_iron@gymmate.local',
    password: 'QaOwner123!',
    nav: [
      { name: 'dashboard', x: 65, y: 790 },
      { name: 'invites', x: 195, y: 790 },
      { name: 'profile', x: 325, y: 790 },
    ],
  },
  trainer: {
    email: 'qa_trainer_iron@gymmate.local',
    password: 'QaTrainer123!',
    nav: [
      { name: 'dashboard', x: 65, y: 790 },
      { name: 'trainees', x: 195, y: 790 },
      { name: 'profile', x: 325, y: 790 },
    ],
  },
  member: {
    email: 'qa_member_iron@gymmate.local',
    password: 'QaMember123!',
    nav: [
      { name: 'dashboard', x: 39, y: 790 },
      { name: 'progress', x: 117, y: 790 },
      { name: 'plan', x: 195, y: 790 },
      { name: 'coach', x: 273, y: 790 },
      { name: 'profile', x: 351, y: 790 },
    ],
  },
  admin: {
    email: 'qa_superadmin@gymmate.local',
    password: 'QaAdmin123!',
    nav: [
      { name: 'dashboard', x: 65, y: 790 },
      { name: 'invites', x: 195, y: 790 },
      { name: 'profile', x: 325, y: 790 },
    ],
  },
};

const demoRoles = {
  owner: {
    email: 'demo_owner_iron@gymmate.local',
    password: 'DemoOwner123!',
    nav: qaRoles.owner.nav,
  },
  trainer: {
    email: 'demo_trainer_iron@gymmate.local',
    password: 'DemoTrainer123!',
    nav: qaRoles.trainer.nav,
  },
  member: {
    email: 'demo_member_iron@gymmate.local',
    password: 'DemoMember123!',
    nav: qaRoles.member.nav,
  },
  admin: {
    email: 'demo_admin@gymmate.local',
    password: 'DemoAdmin123!',
    nav: qaRoles.admin.nav,
  },
};

const roles = process.env.ACCOUNT_SET === 'demo' ? demoRoles : qaRoles;

function attachConsole(page, bucket) {
  page.on('console', (msg) => {
    const type = msg.type();
    if (type === 'error' || type === 'warning') {
      bucket.push(`[${type}] ${msg.text()}`);
    }
  });
  page.on('pageerror', (err) => {
    bucket.push(`[pageerror] ${err.message}`);
  });
}

async function login(email, password) {
  const response = await fetch(`${API_URL}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const body = await response.json();
  if (!response.ok) {
    throw new Error(`Login failed for ${email}: ${body.message || response.status}`);
  }
  return body;
}

async function screenshot(page, name) {
  await page.screenshot({ path: path.join(outDir, name), fullPage: true });
}

async function clickSubmitCluster(page) {
  const points = [
    [195, 590],
    [195, 575],
    [195, 605],
    [170, 590],
    [220, 590],
  ];

  for (const [x, y] of points) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(500);
  }
}

async function tapNavTarget(page, x, y) {
  const points = [
    [x, y],
    [x, y - 8],
    [x, y + 8],
  ];

  for (const [px, py] of points) {
    await page.touchscreen.tap(px, py);
    await page.waitForTimeout(350);
  }

  await page.mouse.click(x, y);
  await page.waitForTimeout(1200);
}

async function runRole(roleName, creds) {
  const browser = await chromium.launch({
    headless: true,
    executablePath: chromePath,
  });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 2,
  });

  const page = await context.newPage();
  const errors = [];
  const loginTraffic = [];
  attachConsole(page, errors);
  page.on('request', (req) => {
    if (req.url().includes('/api/auth/login')) {
      loginTraffic.push({ type: 'request', postData: req.postData() });
    }
  });
  page.on('response', async (res) => {
    if (res.url().includes('/api/auth/login')) {
      loginTraffic.push({
        type: 'response',
        status: res.status(),
        body: await res.text(),
      });
    }
  });

  await page.goto(APP_URL, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2600);
  await page.touchscreen.tap(195, 705);
  await page.waitForTimeout(1600);
  await page.touchscreen.tap(190, 345);
  await page.keyboard.type(creds.email);
  await page.waitForTimeout(300);
  await page.touchscreen.tap(190, 433);
  await page.keyboard.type(creds.password);
  await page.waitForTimeout(300);
  await clickSubmitCluster(page);
  await page.waitForTimeout(5200);
  await screenshot(page, `mobile-${roleName}-dashboard-sweep.png`);

  const shots = [`mobile-${roleName}-dashboard-sweep.png`];

  for (const item of creds.nav.slice(1)) {
    await tapNavTarget(page, item.x, item.y);
    const file = `mobile-${roleName}-${item.name}-sweep.png`;
    await screenshot(page, file);
    shots.push(file);
  }

  const storage = await page.evaluate(() => ({
    keys: Object.keys(localStorage),
    role: localStorage.getItem('user_role'),
    gymName: localStorage.getItem('gym_name'),
  }));

  await browser.close();

  return {
    role: roleName,
    email: creds.email,
    url: APP_URL,
    screenshots: shots,
    errors,
    loginTraffic,
    storage,
  };
}

async function runLoginForm(roleName, email, password) {
  const browser = await chromium.launch({
    headless: true,
    executablePath: chromePath,
  });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 2,
  });
  const page = await context.newPage();
  const errors = [];
  attachConsole(page, errors);

  await page.goto(APP_URL, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2600);
  await page.touchscreen.tap(195, 705);
  await page.waitForTimeout(1600);
  await screenshot(page, `mobile-${roleName}-login-before-sweep.png`);

  await page.touchscreen.tap(190, 345);
  await page.keyboard.type(email);
  await page.waitForTimeout(300);
  await page.touchscreen.tap(190, 433);
  await page.keyboard.type(password);
  await screenshot(page, `mobile-${roleName}-login-filled-sweep.png`);

  await clickSubmitCluster(page);
  await page.waitForTimeout(4200);
  await screenshot(page, `mobile-${roleName}-login-result-sweep.png`);

  const storage = await page.evaluate(() => ({
    role: localStorage.getItem('user_role'),
    hasToken: Boolean(localStorage.getItem('user_token')),
    gymName: localStorage.getItem('gym_name'),
  }));

  await browser.close();

  return {
    role: roleName,
    screenshots: [
      `mobile-${roleName}-login-before-sweep.png`,
      `mobile-${roleName}-login-filled-sweep.png`,
      `mobile-${roleName}-login-result-sweep.png`,
    ],
    errors,
    storage,
  };
}

(async () => {
  const report = {
    appUrl: APP_URL,
    apiUrl: API_URL,
    generatedAt: new Date().toISOString(),
    formLogins: {},
    roles: {},
  };

  report.formLogins.owner = await runLoginForm('owner', roles.owner.email, roles.owner.password);
  report.formLogins.member = await runLoginForm('member', roles.member.email, roles.member.password);

  for (const [roleName, creds] of Object.entries(roles)) {
    report.roles[roleName] = await runRole(roleName, creds);
  }

  const outFile = '/Users/shivamsantosh/gymmate_mvp/deploy/qa/mobile-role-sweep-report.json';
  fs.writeFileSync(outFile, JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
})();
