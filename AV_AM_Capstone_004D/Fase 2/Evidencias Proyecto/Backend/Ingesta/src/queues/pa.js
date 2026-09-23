// src/scrapers/passline.js

export async function obtenerDatosEvento(urlTarget) {
  const browser = await chromium.launch({ headless: HEADLESS_MODE });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 }
  });
  const page = await context.newPage();

  try {
    await page.goto(urlTarget, { waitUntil: 'domcontentloaded' });

    // 1. Esperar a que el título deje de ser "Just a moment" O "Un momento"
    await page.waitForFunction(
      () => !document.title.includes('Just a moment') && !document.title.includes('Un momento'),
      { timeout: 20000 }
    );

    // 2. Dar 1.5 segundos extra para renderizado del DOM
    await page.waitForTimeout(1500);

    const html = await page.content();
    const url = page.url();

    const metadata = await metascraper({ html, url });
    await browser.close();

    // 3. Validación de seguridad para BullMQ: 
    // Si metascraper extrajo "Un momento...", lanzamos error para forzar reintento
    if (!metadata.title || metadata.title.includes('Un momento') || metadata.title.includes('Just a moment')) {
      throw new Error('Cloudflare bloqueó la extracción de metadata.');
    }

    return metadata;
  } catch (error) {
    await browser.close();
    console.error(`Error extrayendo datos de ${urlTarget}:`, error.message);
    // Al lanzar el error, BullMQ marcará este Job como fallido y lo reintentará
    throw error; 
  }
}