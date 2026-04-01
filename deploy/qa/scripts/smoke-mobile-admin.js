const { chromium } = require('/tmp/gymmate-qa/node_modules/playwright');
const fs = require('fs');
const path = require('path');

const outDir = '/Users/shivamsantosh/gymmate_mvp/deploy/qa/screenshots';
fs.mkdirSync(outDir, { recursive: true });

const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

async function shot(page, name) {
  await page.screenshot({ path: path.join(outDir, name), fullPage: true });
}

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

async function firstVisible(page, selectors) {
  for (const selector of selectors) {
    const locator = page.locator(selector).first();
    if (await locator.count()) {
      try {
        if (await locator.isVisible()) return locator;
      } catch {}
    }
  }
  return null;
}

(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: chromePath });
  const mobile = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
  const adminMobile = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
  const adminDesktop = await browser.newContext({ viewport: { width: 1440, height: 1000 } });

  const mobilePage = await mobile.newPage();
  const mobileErrors = [];
  attachConsole(mobilePage, mobileErrors);
  await mobilePage.goto('http://127.0.0.1:8090', { waitUntil: 'networkidle' });
  await mobilePage.waitForTimeout(2500);
  await shot(mobilePage, 'mobile-entry.png');

  const mobileInfo = {
    url: mobilePage.url(),
    text: (await mobilePage.locator('body').innerText()).slice(0, 4000),
    hasExtraPreview: (await mobilePage.locator('text=Gym life, all in one place').count()) > 0,
    hasQuickJoin: (await mobilePage.locator('text=/Quick Join/i').count()) > 0,
    errors: [...mobileErrors],
  };

  const quickJoin = await firstVisible(mobilePage, ['text=Quick Join by Phone', 'text=Quick Join With Phone']);
  if (quickJoin) {
    await quickJoin.click();
    await mobilePage.waitForTimeout(1500);
    await shot(mobilePage, 'mobile-quick-join.png');
    mobileInfo.quickJoinText = (await mobilePage.locator('body').innerText()).slice(0, 2500);
    mobileInfo.quickJoinErrors = [...mobileErrors];
    await mobilePage.goBack({ waitUntil: 'networkidle' }).catch(() => {});
    await mobilePage.waitForTimeout(1000);
  }

  const createAccount = await firstVisible(mobilePage, ['text=Create Account']);
  if (createAccount) {
    await createAccount.click();
    await mobilePage.waitForTimeout(1500);
    await shot(mobilePage, 'mobile-role-setup.png');
    mobileInfo.roleSetupText = (await mobilePage.locator('body').innerText()).slice(0, 2500);
    mobileInfo.roleSetupErrors = [...mobileErrors];
  }

  const adminMobilePage = await adminMobile.newPage();
  const adminMobileErrors = [];
  attachConsole(adminMobilePage, adminMobileErrors);
  await adminMobilePage.goto('http://127.0.0.1:4173/register-gym', { waitUntil: 'networkidle' });
  await adminMobilePage.waitForTimeout(1200);
  await shot(adminMobilePage, 'admin-register-mobile.png');
  const registerButtonVisible = await adminMobilePage.locator('button:has-text("Register Gym")').first().isVisible().catch(() => false);

  const adminPage = await adminDesktop.newPage();
  const adminErrors = [];
  attachConsole(adminPage, adminErrors);
  await adminPage.goto('http://127.0.0.1:4173/login', { waitUntil: 'networkidle' });
  await adminPage.fill('input[type="email"]', 'qa_superadmin@gymmate.local');
  await adminPage.fill('input[type="password"]', 'QaAdmin123!');
  const adminLoginButton = adminPage.locator('form button[type="submit"], .v-form button[type="submit"]').first();
  if (!(await adminLoginButton.count())) {
    throw new Error('Admin form login button not found');
  }
  await adminLoginButton.click();
  await adminPage.waitForTimeout(2500);
  await shot(adminPage, 'admin-dashboard-desktop.png');

  const gymEmail = `qa_auto_${Date.now()}@gymmate.local`;
  await adminPage.goto('http://127.0.0.1:4173/register-gym', { waitUntil: 'networkidle' });
  await adminPage.waitForTimeout(1000);
  const inputs = adminPage.locator('input');
  await inputs.nth(0).fill('QA Auto Lift Club');
  await inputs.nth(1).fill(gymEmail);
  await inputs.nth(2).fill('QaOwner123!');
  await inputs.nth(3).fill('101 Chrome Lane');
  await inputs.nth(4).fill('9999999999');
  await inputs.nth(5).fill('Strength,Recovery');
  const adminRegisterButton = adminPage.locator('form button[type="submit"], .v-form button[type="submit"]').first();
  if (!(await adminRegisterButton.count())) {
    throw new Error('Admin register submit button not found');
  }
  await adminRegisterButton.click();
  await adminPage.waitForTimeout(2500);
  await shot(adminPage, 'admin-register-success.png');
  const adminRegisterText = (await adminPage.locator('body').innerText()).slice(0, 3000);

  const ownerLoginResp = await fetch('http://127.0.0.1:5050/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: gymEmail, password: 'QaOwner123!' }),
  }).then(async (r) => ({ status: r.status, body: await r.text() }));

  const mobileOwnerPage = await mobile.newPage();
  const mobileOwnerErrors = [];
  attachConsole(mobileOwnerPage, mobileOwnerErrors);
  await mobileOwnerPage.goto('http://127.0.0.1:8090', { waitUntil: 'networkidle' });
  await mobileOwnerPage.waitForTimeout(2000);
  const loginEntry = await firstVisible(mobileOwnerPage, ['text=Log In', 'text=Resume Training']);
  if (loginEntry) {
    await loginEntry.click();
    await mobileOwnerPage.waitForTimeout(1500);
    await shot(mobileOwnerPage, 'mobile-login-screen.png');
    const loginInputs = mobileOwnerPage.locator('input');
    if (await loginInputs.count() >= 2) {
      await loginInputs.nth(0).fill(gymEmail);
      await loginInputs.nth(1).fill('QaOwner123!');
      const loginSubmit = await firstVisible(mobileOwnerPage, ['text=Log In', 'text=Resume Training']);
      if (loginSubmit) {
        await loginSubmit.click();
        await mobileOwnerPage.waitForTimeout(3500);
        await shot(mobileOwnerPage, 'mobile-owner-after-login.png');
      }
    }
  }

  const report = {
    mobileInfo,
    adminMobile: {
      registerButtonVisible,
      text: (await adminMobilePage.locator('body').innerText()).slice(0, 2000),
      errors: adminMobileErrors,
    },
    adminDesktop: {
      dashboardText: (await adminPage.locator('body').innerText()).slice(0, 3000),
      errors: adminErrors,
      registerText: adminRegisterText,
    },
    ownerLoginResp,
    mobileOwner: {
      url: mobileOwnerPage.url(),
      text: (await mobileOwnerPage.locator('body').innerText()).slice(0, 3000),
      errors: mobileOwnerErrors,
    },
  };

  fs.writeFileSync('/Users/shivamsantosh/gymmate_mvp/deploy/qa/smoke-report.json', JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
  await browser.close();
})();
