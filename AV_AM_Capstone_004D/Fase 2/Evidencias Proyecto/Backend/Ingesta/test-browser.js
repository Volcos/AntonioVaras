// test-browser.js
import { chromium } from 'playwright';

console.log('1. Intentando lanzar Chromium...');

try {
  const browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--disable-software-rasterizer'
    ]
  });

  console.log('2. ¡Chromium abierto con éxito!');
  const page = await browser.newPage();
  
  console.log('3. Navegando a una página simple...');
  await page.goto('https://example.com');
  console.log('4. Título obtenido:', await page.title());

  await browser.close();
  console.log('5. Navegador cerrado correctamente.');
} catch (error) {
  console.error('Error en el navegador:', error);
}