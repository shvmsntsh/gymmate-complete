const { chromium } = require('/tmp/gymmate-qa/node_modules/playwright');
const path = require('path');
(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:8090', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  await page.touchscreen.tap(195, 705);
  await page.waitForTimeout(2200);
  await page.screenshot({ path: path.join('/Users/shivamsantosh/gymmate_mvp/deploy/qa/screenshots', 'mobile-touch-role-705.png'), fullPage: true });
  await page.goto('http://127.0.0.1:8090', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1800);
  await page.touchscreen.tap(195, 760);
  await page.waitForTimeout(2200);
  await page.screenshot({ path: path.join('/Users/shivamsantosh/gymmate_mvp/deploy/qa/screenshots', 'mobile-touch-quickjoin-760.png'), fullPage: true });
  await browser.close();
})();
