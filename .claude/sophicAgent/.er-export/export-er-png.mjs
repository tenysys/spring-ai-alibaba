import { chromium } from 'playwright';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import fs from 'node:fs/promises';

const baseDir = 'E:/java/workplace/spring-ai-alibaba/.claude/sophicAgent';
const htmlPath = path.join(baseDir, '数据库ER图.html');
const outputDir = path.join(baseDir, 'er-png');

const targets = [
  { id: 'all', file: '00_总体主干.png' },
  { id: 'auth', file: '01_账号权限域.png' },
  { id: 'app', file: '02_应用与设计器域.png' },
  { id: 'runtime', file: '03_运行时域.png' },
  { id: 'asset', file: '04_能力资产域.png' },
  { id: 'governance', file: '05_治理观测与运营域.png' }
];

async function waitForMermaid(page, expectedCount) {
  await page.waitForLoadState('networkidle');
  await page.waitForFunction(
    (count) => document.querySelectorAll('.diagram-wrap svg').length >= count,
    expectedCount,
    { timeout: 120000 }
  );
}

async function main() {
  await fs.mkdir(outputDir, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({
    viewport: { width: 2200, height: 1600 },
    deviceScaleFactor: 4
  });

  const url = pathToFileURL(htmlPath).href;
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await waitForMermaid(page, 6);

  await page.addStyleTag({
    content: `
      .hint, .footer { display: none !important; }
    `
  });

  for (const target of targets) {
    const locator = page.locator(`#${target.id}`);
    await locator.scrollIntoViewIfNeeded();
    await locator.screenshot({
      path: path.join(outputDir, target.file)
    });
  }

  await browser.close();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
