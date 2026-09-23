// src/scrapers/passline.js
import createMetascraper from 'metascraper';
import metascraperTitle from 'metascraper-title';
import metascraperDate from 'metascraper-date';
import metascraperDescription from 'metascraper-description';
import metascraperImage from 'metascraper-image';

import { chromium } from 'playwright';

const metascraper = createMetascraper([
  metascraperTitle(),
  metascraperDate(),
  metascraperDescription(),
  metascraperImage()
]);

const LAUNCH_OPTIONS = {
  headless: false,
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--disable-blink-features=AutomationControlled',
    '--enable-webgl',
    '--use-gl=swiftshader', // Permite a Cloudflare ejecutar las pruebas de WebGL en Xvfb
    '--enable-accelerated-2d-canvas'
  ]
};

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

async function esperarYSolverCloudflare(page, timeoutMs = 40000) {
  const startTime = Date.now();

  console.log('[Cloudflare] Esperando a que el desafío cargue completamente...');

  while (Date.now() - startTime < timeoutMs) {
    const title = await page.title();

    // Si el título ya cambió, pasamos exitosamente
    if (!title.includes('Just a moment') && !title.includes('Un momento') && title.trim().length > 0) {
      return true;
    }

    try {
      for (const frame of page.frames()) {
        const url = frame.url();
        if (url.includes('cloudflare') || url.includes('turnstile') || url.includes('challenges')) {
          const checkbox = frame.locator('input[type="checkbox"], .cb-lb, #challenge-stage');

          // Solo intentamos interactuar si la casilla ya es visible y NO está en estado de spinner
          if (await checkbox.isVisible({ timeout: 1000 })) {
            const box = await checkbox.boundingBox();
            if (box) {
              console.log(`[Cloudflare] Widget listo en x:${box.x}, y:${box.y}. Haciendo clic...`);
              
              const targetX = box.x + Math.min(box.width / 2, 20);
              const targetY = box.y + box.height / 2;

              await page.mouse.move(targetX, targetY, { steps: 12 });
              await page.waitForTimeout(400);
              await page.mouse.click(targetX, targetY);

              console.log('[Cloudflare] Clic enviado. Esperando respuesta...');
              await page.waitForTimeout(5000);
            }
          }
        }
      }
    } catch (e) {
      // Ignorar errores de transición mientras la página renderiza
    }

    await page.waitForTimeout(2000);
  }

  throw new Error(`Timeout de ${timeoutMs}ms esperando superar Cloudflare.`);
}

async function crearContextoEvasivo(browser) {
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    userAgent: USER_AGENT,
    locale: 'es-CL,es;q=0.9,en;q=0.8',
    timezoneId: 'America/Santiago',
    extraHTTPHeaders: {
      'sec-ch-ua': '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
      'accept-language': 'es-CL,es;q=0.9,en;q=0.8'
    }
  });

  await context.addInitScript(() => {
    // Eliminar bandera de webdriver
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    
    // Simular plugins y permisos
    Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3, 4, 5] });
    Object.defineProperty(navigator, 'languages', { get: () => ['es-CL', 'es', 'en'] });
    
    // Stub de objeto chrome
    window.chrome = {
      runtime: {},
      loadTimes: function() {},
      csi: function() {},
      app: {}
    };
  });

  return context;
}

export async function obtenerDatosEvento(urlTarget) {
  const browser = await chromium.launch(LAUNCH_OPTIONS);
  const context = await crearContextoEvasivo(browser);
  const page = await context.newPage();

  try {
    await page.goto(urlTarget, { waitUntil: 'domcontentloaded', timeout: 35000 });
    await esperarYSolverCloudflare(page);

    await page.waitForTimeout(1500);

    const html = await page.content();
    const url = page.url();

    const metadata = await metascraper({ html, url });
    await browser.close();

    if (!metadata.title || metadata.title.includes('Un momento') || metadata.title.includes('Just a moment')) {
      throw new Error('Cloudflare bloqueó la extracción de metadata.');
    }

    return metadata;
  } catch (error) {
    await browser.close();
    console.error(`Error extrayendo datos de ${urlTarget}:`, error.message);
    throw error; 
  }
}

export async function obtenerListaEventosChile(pais = 'chile', limite = 15) {
  console.log('[PASO 1] Lanzando Chromium con renderizador SwiftShader...');
  const browser = await chromium.launch(LAUNCH_OPTIONS);

  console.log('[PASO 2] Creando contexto con cabeceras Client Hints...');
  const context = await crearContextoEvasivo(browser);
  const page = await context.newPage();

  try {
    console.log('[PASO 3] Navegando al catálogo de Passline...');
    await page.goto(`https://www.passline.com/busqueda?pais=${pais}`, {
      waitUntil: 'domcontentloaded',
      timeout: 35000
    });

    console.log('[PASO 4] Verificando y resolviendo Cloudflare...');
    await esperarYSolverCloudflare(page);

    console.log('[PASO 5] Buscando enlaces en la página...');
    await page.waitForSelector('a[href*="/eventos/"]', { state: 'attached', timeout: 30000 });

    const todosLosEnlaces = await page.$$eval('a[href*="/eventos/"]', anchors =>
      anchors.map(a => a.href)
    );

    const enlacesUnicos = [...new Set(todosLosEnlaces)];
    console.log(`[PASO 6] ¡Éxito! Enlaces encontrados: ${enlacesUnicos.length}`);

    await browser.close();
    return enlacesUnicos.slice(0, limite);
  } catch (error) {
    await page.screenshot({ path: 'debug_cloudflare.png' });
    console.error('[PASO ERROR] Captura guardada como debug_cloudflare.png. Error:', error.message);
    await browser.close();
    throw error;
  }
}