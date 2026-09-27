// Optional browser smoke run. Use an existing Playwright installation; no game dependency.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs = require('node:fs');
const url = process.env.GAME_URL || 'http://127.0.0.1:8751';
const output = 'build/verification';

async function openGame(page, errors) {
	page.on('pageerror', error => errors.push(String(error)));
	page.on('console', message => {
		if (message.type() === 'error') errors.push(message.text());
	});
	await page.goto(url);
	await page.waitForFunction(() => !document.getElementById('status'), null, { timeout: 90000 });
	await page.locator('#canvas').waitFor({ state: 'visible' });
}

(async () => {
	fs.mkdirSync(output, { recursive: true });
	const browser = await chromium.launch({
		headless: true,
		args: ['--no-sandbox', '--enable-unsafe-swiftshader'],
	});
	const errors = [];
	try {
		const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
		await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
		const page = await context.newPage();
		await openGame(page, errors);
		await page.waitForTimeout(2000);
		await page.screenshot({ path: `${output}/browser-welcome.png` });
		await page.mouse.click(640, 400);
		await page.keyboard.down('w');
		await page.waitForTimeout(500);
		await page.keyboard.down('Space');
		await page.waitForTimeout(180);
		await page.keyboard.up('Space');
		await page.waitForTimeout(540);
		await page.keyboard.up('w');
		await page.waitForTimeout(600);
		await page.screenshot({ path: `${output}/browser-movement.png` });
		await page.keyboard.press('Escape');
		await page.waitForTimeout(200);
		await page.screenshot({ path: `${output}/browser-paused.png` });
		await context.tracing.stop({ path: `${output}/browser-trace.zip` });
		await context.close();

		const mobile = await browser.newContext({
			viewport: { width: 390, height: 844 },
			deviceScaleFactor: 2,
			isMobile: true,
			hasTouch: true,
		});
		await mobile.tracing.start({ screenshots: true, snapshots: true });
		const phone = await mobile.newPage();
		await openGame(phone, errors);
		await phone.waitForTimeout(1000);
		await phone.screenshot({ path: `${output}/browser-mobile-welcome.png` });
		await phone.touchscreen.tap(195, 300);
		await phone.waitForTimeout(800);
		await phone.screenshot({ path: `${output}/browser-mobile.png` });
		await phone.touchscreen.tap(222, 38);
		await phone.waitForTimeout(250);
		await phone.screenshot({ path: `${output}/browser-mobile-paused.png` });
		await mobile.tracing.stop({ path: `${output}/browser-mobile-trace.zip` });
		await mobile.close();
	} finally {
		await browser.close();
	}
	fs.writeFileSync(`${output}/browser.json`, JSON.stringify({
		errors,
		interactions: ['load', 'keyboard move and jump', 'pause', 'mobile start', 'mobile pause target'],
		note: 'Review screenshots for outcomes; full crossing assertions run in level_one_test.tscn',
	}, null, 2));
	if (errors.length) throw new Error(errors.join('\n'));
	console.log('Browser interactions completed without JavaScript or console errors; screenshots and traces saved');
})().catch(error => {
	console.error(error);
	process.exit(1);
});
