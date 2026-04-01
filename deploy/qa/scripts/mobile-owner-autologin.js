const { chromium } = require('/tmp/gymmate-qa/node_modules/playwright');
const path = require('path');
(async () => {
  const login = await fetch('http://127.0.0.1:5050/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'qa_owner_iron@gymmate.local', password: 'QaOwner123!' })
  }).then(r => r.json());

  const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:8090', { waitUntil: 'networkidle' });
  await page.evaluate((payload) => {
    localStorage.clear();
    localStorage.setItem('user_token', payload.token);
    localStorage.setItem('user_data', JSON.stringify(payload.user));
    localStorage.setItem('user_id', payload.user.id);
    localStorage.setItem('user_role', payload.user.role);
    localStorage.setItem('user_name', payload.user.name || '');
    localStorage.setItem('user_email', payload.user.email || '');
    localStorage.setItem('gym_name', payload.user.gymName || '');
    localStorage.setItem('has_completed_onboarding', String(payload.user.hasCompletedOnboarding ?? false));
    localStorage.setItem('avatar_path', payload.user.avatarPath || '');
    localStorage.setItem('branding_data', JSON.stringify({}));
  }, login);
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForTimeout(3500);
  await page.screenshot({ path: path.join('/Users/shivamsantosh/gymmate_mvp/deploy/qa/screenshots', 'mobile-owner-autologin.png'), fullPage: true });
  const storageKeys = await page.evaluate(() => Object.keys(localStorage));
  console.log(JSON.stringify({ url: page.url(), storageKeys }, null, 2));
  await browser.close();
})();
