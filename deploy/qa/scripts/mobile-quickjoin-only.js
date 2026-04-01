const { chromium } = require('/tmp/gymmate-qa/node_modules/playwright');
const path = require('path');
(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
  const page = await context.newPage();
  const errors = [];
  page.on('console', msg => {
    const type = msg.type();
    if (type === 'error' || type === 'warning') errors.push(`[${type}] ${msg.text()}`);
  });
  page.on('pageerror', err => errors.push(`[pageerror] ${err.message}`));
  await page.goto('http://127.0.0.1:8090', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  await page.touchscreen.tap(195, 785);
  await page.waitForTimeout(2500);
  await page.screenshot({ path: path.join('/Users/shivamsantosh/gymmate_mvp/deploy/qa/screenshots', 'mobile-touch-quickjoin-785.png'), fullPage: true });
  console.log(JSON.stringify({ errors, url: page.url() }, null, 2));
  await browser.close();
})();
