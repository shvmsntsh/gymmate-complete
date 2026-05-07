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

async function apiJson(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  let body = {};
  try {
    body = await response.json();
  } catch {
    body = { raw: await response.text().catch(() => '') };
  }
  return { status: response.status, body };
}

async function fillFirstInputs(page, values) {
  const inputs = page.locator('input');
  for (let index = 0; index < values.length; index += 1) {
    await inputs.nth(index).fill(values[index]);
  }
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
  const registerButtonVisible = await adminMobilePage
    .locator('form button[type="submit"], .v-form button[type="submit"]')
    .first()
    .isVisible()
    .catch(() => false);

  const adminPage = await adminDesktop.newPage();
  const adminErrors = [];
  attachConsole(adminPage, adminErrors);
  await adminPage.goto('http://127.0.0.1:4173/login', { waitUntil: 'networkidle' });
  await fillFirstInputs(adminPage, ['qa_superadmin@gymmate.local', 'QaAdmin123!']);
  const adminLoginButton = adminPage.locator('form button[type="submit"], .v-form button[type="submit"]').first();
  if (!(await adminLoginButton.count())) {
    throw new Error('Admin form login button not found');
  }
  await adminLoginButton.click();
  await adminPage.waitForTimeout(2500);
  await shot(adminPage, 'admin-dashboard-desktop.png');

  const gymEmail = `qa_auto_${Date.now()}@gymmate.local`;
  const gymContact = `98${String(Date.now()).slice(-8)}`;
  await adminPage.goto('http://127.0.0.1:4173/register-gym', { waitUntil: 'networkidle' });
  await adminPage.waitForTimeout(1000);
  const inputs = adminPage.locator('input');
  await inputs.nth(0).fill('QA Auto Lift Club');
  await inputs.nth(1).fill(gymEmail);
  await inputs.nth(2).fill('QaOwner123!');
  await inputs.nth(3).fill('101 Chrome Lane');
  await inputs.nth(4).fill(gymContact);
  await inputs.nth(5).fill('Strength,Recovery');
  const adminRegisterButton = adminPage.locator('form button[type="submit"], .v-form button[type="submit"]').first();
  if (!(await adminRegisterButton.count())) {
    throw new Error('Admin register submit button not found');
  }
  await adminRegisterButton.click();
  await adminPage.waitForTimeout(2500);
  await shot(adminPage, 'admin-register-success.png');
  const adminRegisterText = (await adminPage.locator('body').innerText()).slice(0, 3000);

  const ownerLoginResp = await apiJson('http://127.0.0.1:5050/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email: gymEmail, password: 'QaOwner123!' }),
  });

  const ownerToken = ownerLoginResp.body?.token;
  const pilot = {
    ownerLoginStatus: ownerLoginResp.status,
    planUi: {},
    staffUi: {},
    memberFlow: {},
  };

  if (ownerToken) {
    await adminPage.evaluate(() => localStorage.clear()).catch(() => {});
    await adminPage.goto('http://127.0.0.1:4173/login', { waitUntil: 'networkidle' });
    await fillFirstInputs(adminPage, [gymEmail, 'QaOwner123!']);
    await adminPage.locator('form button[type="submit"], .v-form button[type="submit"]').first().click();
    await adminPage.waitForTimeout(2200);
    await shot(adminPage, 'pilot-owner-dashboard.png');

    await adminPage.goto('http://127.0.0.1:4173/membership', { waitUntil: 'networkidle' });
    await adminPage.waitForTimeout(1200);
    const plansTab = await firstVisible(adminPage, ['button:has-text("Plans")', 'text=Plans']);
    if (plansTab) await plansTab.click();
    await adminPage.waitForTimeout(800);
    const newPlan = await firstVisible(adminPage, ['button:has-text("New Plan")', 'button:has-text("Create Plan")']);
    if (newPlan) {
      await newPlan.click();
      await adminPage.waitForTimeout(500);
      const dialog = adminPage.locator('.v-dialog').last();
      const dialogInputs = dialog.locator('input');
      await dialogInputs.nth(0).fill(`Monthly Pack ${Date.now()}`);
      await dialogInputs.nth(1).fill('30');
      await dialogInputs.nth(2).fill('1500');
      await dialogInputs.nth(3).fill('7');
      await dialog.locator('textarea').first().fill('Monthly');
      for (const label of ['Gym access', 'Biometric access', 'Locker access']) {
        const checkbox = dialog.locator(`label:has-text("${label}")`).first();
        if (await checkbox.count()) await checkbox.click();
      }
      await dialog.locator('button:has-text("Create plan")').first().click();
      await adminPage.waitForTimeout(1800);
    }
    await shot(adminPage, 'pilot-membership-plan-created.png');
    pilot.planUi.text = (await adminPage.locator('body').innerText()).slice(0, 3000);
    pilot.planUi.errors = [...adminErrors];

    const editButton = adminPage.locator('.plan-card button').first();
    if (await editButton.count()) {
      await editButton.click();
      await adminPage.waitForTimeout(800);
      await shot(adminPage, 'pilot-membership-plan-edit.png');
      pilot.planUi.editDialogText = (await adminPage.locator('.v-dialog').last().innerText().catch(() => '')).slice(0, 1200);
      await adminPage.keyboard.press('Escape').catch(() => {});
    }

    await adminPage.goto('http://127.0.0.1:4173/staff', { waitUntil: 'networkidle' });
    await adminPage.waitForTimeout(1200);
    await shot(adminPage, 'pilot-staff-empty-state.png');
    pilot.staffUi.text = (await adminPage.locator('body').innerText()).slice(0, 2500);

    const templates = await apiJson('http://127.0.0.1:5050/api/owner/membership-templates', {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    let template = templates.body?.templates?.[0];
    if (!template) {
      const createdTemplate = await apiJson('http://127.0.0.1:5050/api/owner/membership-templates', {
        method: 'POST',
        headers: { Authorization: `Bearer ${ownerToken}` },
        body: JSON.stringify({
          name: 'Monthly Pack API',
          shortDescription: 'Monthly',
          durationDays: 30,
          price: 1500,
          renewalLeadDays: 7,
          active: true,
          visibleToMembers: true,
          includedFeatures: {
            gymAccess: true,
            biometricAccess: true,
            lockerAccess: true,
            guestPasses: 0,
          },
          availableAddOns: {},
          rules: { freezeLimitDays: 0 },
        }),
      });
      template = createdTemplate.body?.template;
    }

    const memberEmail = `qa_member_${Date.now()}@gymmate.local`;
    const memberPhone = `97${String(Date.now()).slice(-8)}`;
    const invite = await apiJson('http://127.0.0.1:5050/api/invite/generate', {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        role: 'gym_member',
        name: 'Pilot Member',
        email: memberEmail,
        phone_number: memberPhone,
      }),
    });
    const memberInviteCode = invite.body?.code || invite.body?.inviteCode;
    const memberRegistration = memberInviteCode
      ? await apiJson('http://127.0.0.1:5050/api/auth/register', {
          method: 'POST',
          body: JSON.stringify({
            name: 'Pilot Member',
            email: memberEmail,
            password: 'QaMember123!',
            phone_number: memberPhone,
            inviteCode: memberInviteCode,
          }),
        })
      : { status: 0, body: { message: 'No invite code generated' } };
    const memberId = memberRegistration.body?.user?.id || memberRegistration.body?.user?._id;
    const assigned = memberId && template?.id
      ? await apiJson(`http://127.0.0.1:5050/api/owner/members/${memberId}/memberships`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${ownerToken}` },
          body: JSON.stringify({
            templateId: template.id,
            paymentStatus: 'unpaid',
            paymentMethod: 'cash',
            notes: 'Pilot smoke assignment',
          }),
        })
      : { status: 0, body: { message: 'Missing member or template' } };
    const assignedMembershipId = assigned.body?.membership?.id;
    const recordedPayment = assignedMembershipId
      ? await apiJson('http://127.0.0.1:5050/api/owner/payments', {
          method: 'POST',
          headers: { Authorization: `Bearer ${ownerToken}` },
          body: JSON.stringify({
            memberId,
            membershipId: assignedMembershipId,
            amount: 1500,
            mode: 'cash',
            reference: 'PILOT-CASH-001',
            note: 'Pilot smoke payment',
            activate: true,
          }),
        })
      : { status: 0, body: { message: 'Missing assigned membership' } };
    const memberLogin = await apiJson('http://127.0.0.1:5050/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email: memberEmail, password: 'QaMember123!' }),
    });
    const memberMembership = memberLogin.body?.token
      ? await apiJson('http://127.0.0.1:5050/api/member/me/membership', {
          headers: { Authorization: `Bearer ${memberLogin.body.token}` },
        })
      : { status: 0, body: { message: 'Member login failed' } };
    const memberReceipt = memberLogin.body?.token
      ? await apiJson('http://127.0.0.1:5050/api/member/me/membership/receipt', {
          headers: { Authorization: `Bearer ${memberLogin.body.token}` },
        })
      : { status: 0, body: { message: 'Member login failed' } };
    pilot.memberFlow = {
      inviteStatus: invite.status,
      registerStatus: memberRegistration.status,
      assignStatus: assigned.status,
      paymentStatus: recordedPayment.status,
      loginStatus: memberLogin.status,
      membershipStatus: memberMembership.status,
      receiptStatus: memberReceipt.status,
      membership: memberMembership.body?.membership || null,
      receipt: memberReceipt.body?.receipt || null,
    };
  }

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
    pilot,
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
