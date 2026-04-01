const { chromium } = require('/tmp/gymmate-qa/node_modules/playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:8090', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  const points = [
    { name: 'login', x: 195, y: 611 },
    { name: 'create', x: 195, y: 678 },
    { name: 'quickJoin', x: 195, y: 726 },
  ];
  const result = await page.evaluate((pts) => pts.map((pt) => ({
    ...pt,
    hits: document.elementsFromPoint(pt.x, pt.y).map((el) => ({ tag: el.tagName, id: el.id, cls: el.className }))
  })), points);
  console.log(JSON.stringify(result, null, 2));
  await browser.close();
})();
