// Teste da versão Web no navegador (spec 012, RF92): abre o jogo exportado,
// passa por título, opções, caso, cidade e mapa clicando como um jogador e
// falha se o motor registrar erro — ex.: classe que ficou fora do modelo
// Web enxuto. Capturas de cada etapa em <saída>/ pra conferir no artefato.
// Roda no CI: node tests/web_smoke.js <url> <saída>  (playwright@1.49.1)
const { chromium } = require('playwright');

const [url, out] = process.argv.slice(2);
// Avisos do navegador que não são do jogo.
const IGNORED = [/AudioContext was not allowed/, /WebGL/i, /GPU stall/i, /favicon/];

(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
  const problems = [];
  page.on('console', (m) => {
    const text = m.text();
    if (IGNORED.some((re) => re.test(text))) return;
    if (m.type() === 'error' || /SCRIPT ERROR|^ERROR:|Cannot get class|not available/.test(text)) problems.push(text);
  });
  page.on('pageerror', (e) => problems.push('pageerror: ' + e.message));

  await page.goto(url);
  await page.waitForFunction(() => {
    const s = document.getElementById('status');
    if (!s) return true;
    const st = getComputedStyle(s);
    return st.display === 'none' || st.visibility === 'hidden' || st.opacity === '0';
  }, null, { timeout: 180000 });
  await page.waitForTimeout(4000);

  const steps = [
    ['01_titulo', async () => {}],
    ['02_cracha', async () => { await page.mouse.click(640, 390); await page.keyboard.type('Teste CI'); await page.mouse.click(640, 463); }],
    ['03_opcoes', async () => { await page.mouse.click(1172, 545); }],
    ['04_briefing', async () => { await page.keyboard.press('Escape'); await page.waitForTimeout(800); await page.mouse.click(592, 545); }],
    ['05_cidade', async () => { await page.mouse.click(867, 435); await page.waitForTimeout(800); await page.mouse.click(1087, 668); }],
    ['06_mapa', async () => { await page.mouse.click(867, 450); await page.waitForTimeout(800); await page.mouse.click(1113, 247); }],
    ['07_voo', async () => { await page.mouse.click(867, 418); await page.waitForTimeout(800); await page.mouse.click(145, 662); await page.waitForTimeout(600); }],
  ];
  for (const [name, act] of steps) {
    await act();
    await page.waitForTimeout(2500);
    await page.screenshot({ path: `${out}/${name}.png` });
  }
  await browser.close();

  if (problems.length) {
    console.error('Erros do motor na versão Web:\n  ' + problems.slice(0, 20).join('\n  '));
    process.exit(1);
  }
  console.log('Web: título, opções, caso, cidade e mapa sem erro do motor.');
})().catch((e) => { console.error(e); process.exit(1); });
