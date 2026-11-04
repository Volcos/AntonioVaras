import { writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const URLS_SEMILLA = [
  'https://www.puntoticket.com/',
  'https://www.puntoticket.com/musica',
  'https://www.puntoticket.com/teatro',
  'https://www.puntoticket.com/deportes'
];

const DESCARTE = [
  'precio total incluye cargo',
  'descuentos aplican solo',
  'utilizamos cookies',
  'para más información',
  'layout.',
  'mis datos',
  'compra tu entrada',
  'música\ndeportes',
  'vigencia hasta'
];

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/*
OBTENER LAS URLs
*/


export async function obtenerUrlsEventos(page) {
  const urlsEventos = new Set();
  console.log('Buscando eventos en secciones principales...');

  for (const url of URLS_SEMILLA) {
    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });
      await page.waitForTimeout(1500);

      const links = await page.locator("a[href*='/evento/']").evaluateAll(anchors =>
        anchors.map(anchor => anchor.getAttribute('href')).filter(Boolean)
      );

      for (const href of links) {
        urlsEventos.add(new URL(href, 'https://www.puntoticket.com').href);
      }
    } catch (error) {
      console.error(`Error al cargar ${url}: ${error.message}`);
    }
  }

  return [...urlsEventos];
}
/*
EXTRAER EL LUGAR DESDE LA URL
*/
export function extraerLugarDesdeUrl(url) {
  const match = url.match(/\/evento\/([^/?#]+)/i);
  if (!match) {
    return null;
  }

  const slugLimpio = match[1].replace(
    /-(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)-\d{4}$/i,
    ''
  );
  const partes = slugLimpio.split('-');
  const palabrasRecinto = new Set([
    'teatro',
    'estadio',
    'movistar',
    'arena',
    'club',
    'centro',
    'caupolican',
    'fortin'
  ]);
  const indiceRecinto = partes.findIndex(parte => palabrasRecinto.has(parte.toLowerCase()));

  if (indiceRecinto === -1) {
    return null;
  }

  return partes
    .slice(indiceRecinto)
    .map(parte => parte.charAt(0).toUpperCase() + parte.slice(1).toLowerCase())
    .join(' ');
}


/**
 * FUNCIÓN PARA EXTRAER LONGITUD Y LATIDUD
 */


async function extraerCoordenadasGooGl(urlCorta) {
  try {
    // fetch sigue la redirección automáticamente por defecto
    const respuesta = await fetch(urlCorta, {
      headers: { 'User-Agent': 'Mozilla/5.0' }
    });

    // respuesta.url contiene la URL larga final después de redirigir
    const urlLarga = respuesta.url;

    // 1. Intentar formato !3d(lat)!4d(lng)
    const matchPin = urlLarga.match(/!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)/);
    if (matchPin) {
      return {
        latitud: parseFloat(matchPin[1]),
        longitud: parseFloat(matchPin[2])
      };
    }

    // 2. Intentar formato @lat,lng o q=lat,lng
    const matchAt = urlLarga.match(/[@q=](-?\d+\.\d+),(-?\d+\.\d+)/);
    if (matchAt) {
      return {
        latitud: parseFloat(matchAt[1]),
        longitud: parseFloat(matchAt[2])
      };
    }

    return { latitud: null, longitud: null };
  } catch (error) {
    console.error('Error al resolver link corto de Maps:', error.message);
    return { latitud: null, longitud: null };
  }
}


/*
EXTRAER EL DETALLE DE CADA EVENTO
*/


export async function extraerDetalleEstructurado(page, url) {
  console.log(`Procesando: ${url}`);

  try {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 20000 });
    await page.evaluate(() => {
      document
        .querySelectorAll('nav, header, footer, .menu, .navbar, .calendar, .datepicker, .v-calendar')
        .forEach(element => element.remove());
    });


    /*
    OBTENER TITULO
    */


    const h1 = page.locator('h1').first();
    const titulo = (await h1.count()) > 0 ? (await h1.innerText()).trim() : 'Sin título';
    
    
    /* 
    OBTENER IMAGEN 
    */


    let imagen = null;
    const selectoresImagen = [
      'img.img_artist_thumb',
      "img[src*='calugalistado'], img[src*='caluga']",
      "img[src*='ptocdn.net/images/eventos/'], img[src*='ptocdn.net/event-resources/images/']"
    ];

    for (const selector of selectoresImagen) {
      const img = page.locator(selector).first();
      if ((await img.count()) > 0) {
        imagen = await img.getAttribute('src');
        if (imagen) {
          imagen = imagen.trim();
          break;
        }
      }
    }


    /**
     * OBTENER FECHA Y HORA
     */


    let fechaHora = null;
    const textosTime = (await page.locator('time').allInnerTexts())
      .map(texto => texto.trim())
      .filter(Boolean);

    if (textosTime.length > 0) {
      fechaHora = textosTime.join(' - ');
    }

    if (!fechaHora) {
      const elementosFecha = page.locator(
        '.date, .fecha, span[class*="date"], div[class*="date"]'
      );
      for (let i = 0; i < (await elementosFecha.count()); i += 1) {
        const texto = (await elementosFecha.nth(i).innerText()).trim();
        const textoLower = texto.toLowerCase();
        if (
          texto &&
          !DESCARTE.some(frase => textoLower.includes(frase)) &&
          !texto.includes('SELECCIONA')
        ) {
          fechaHora = texto;
          break;
        }
      }
    }

    if (!fechaHora) {
      const bloques = page.locator('p, span, li, b, strong');
      const patronFecha =
        /(\d{1,2}\s+de\s+[a-z]+|\d{1,2}[-/]\d{1,2}[-/]\d{2,4}|\d{2}:\d{2}\s*hrs)/i;

      for (let i = 0; i < (await bloques.count()); i += 1) {
        const texto = (await bloques.nth(i).innerText()).trim();
        const textoLower = texto.toLowerCase();
        if (
          patronFecha.test(texto) &&
          texto.length < 80 &&
          !DESCARTE.some(frase => textoLower.includes(frase))
        ) {
          fechaHora = texto;
          break;
        }
      }
    }

    if (fechaHora) {
      fechaHora = fechaHora
        .replace(/\s+/g, ' ')
        .trim()
        .replace(/^SELECCIONA FUNCIÓN\s*/i, '')
        .replace(/(\s*n\d+)+/g, '');
    }


    /**
     * OBTENER DIRECCION
     */
    let lugar = null;
    const mapLink = page
      .locator("a[href*='maps.app.goo.gl'], a[href*='google.com/maps']")
      .first();
    if ((await mapLink.count()) > 0) {
      const textoMap = (await mapLink.innerText()).trim();
      if (textoMap && textoMap.length < 80) {
        lugar = textoMap;
      }
    }

    if (!lugar) {
      const elemAddress = page.locator('address').first();
      if ((await elemAddress.count()) > 0) {
        const lugarAddress = await elemAddress.evaluate(node => {
          for (const child of node.childNodes) {
            if (child.nodeType === 3 && child.textContent.trim()) {
              return child.textContent.trim();
            }
          }
          return node.innerText.split('\n')[0].trim();
        });
        const lugarLower = lugarAddress.toLowerCase();
        if (
          lugarAddress &&
          lugarAddress.length < 80 &&
          !DESCARTE.some(frase => lugarLower.includes(frase))
        ) {
          lugar = lugarAddress;
        }
      }
    }

    if (!lugar) {
      const elementosLugar = page.locator(
        '.venue, .recinto, .place, span[class*="place"], div[class*="place"]'
      );
      for (let i = 0; i < (await elementosLugar.count()); i += 1) {
        const texto = (await elementosLugar.nth(i).innerText()).trim();
        const textoLower = texto.toLowerCase();
        if (
          texto &&
          texto.length < 60 &&
          !DESCARTE.some(frase => textoLower.includes(frase))
        ) {
          lugar = texto;
          break;
        }
      }
    }

    if (!lugar) {
      lugar = extraerLugarDesdeUrl(url);
    }
    if (lugar) {
      lugar = lugar.replace(/\s+/g, ' ').trim();
    }


    /**
     * OBTENER LONGITUD Y LATITUD
     */


    const coordenadas = await extraerCoordenadasGooGl(url);
    /**
     * OBTENER DESCRIPCION
     */

    
    const parrafos = page.locator('p, div.description p, div.event-detail p');
    const textoDescripcion = [];
    for (let i = 0; i < (await parrafos.count()); i += 1) {
      const texto = (await parrafos.nth(i).innerText()).trim();
      const textoLower = texto.toLowerCase();
      if (
        texto.length > 15 &&
        !DESCARTE.some(frase => textoLower.includes(frase)) &&
        !textoDescripcion.includes(texto) &&
        texto !== fechaHora &&
        texto !== lugar
      ) {
        textoDescripcion.push(texto);
      }
    }


    /**
     * OBTENER ID DEL EVENTO
     */

    const url_cortada = url.split('/evento/');
    const id_evento = url_cortada[1];

    /*
    id_evento - listo
    nombre - listo
    descripción - listo
    dirección - listo
    imagen_url - listo
    latitud - 
    longitud -
    id_tipo_evento -
    organizador -
    url_pagina_compra -
    fechas {}***
    */


    return {
      url,
      titulo,
      imagen,
      fecha_hora: fechaHora || null,
      lugar,
      descripcion: textoDescripcion.slice(0, 5).join('\n'),
      id_evento,
      longitud: coordenadas,
      latitud: coordenadas.latitud,
    };
  } catch (error) {
    console.error(`Error procesando ${url}: ${error.message}`);
    return null;
  }
}

export async function ejecutarScraperPuntoTicket() {
  const browser = await chromium.launch({ headless: true });

  try {
    const context = await browser.newContext({ userAgent: USER_AGENT });
    const page = await context.newPage();
    const urls = await obtenerUrlsEventos(page);
    console.log(`\nTotal de eventos encontrados: ${urls.length}`);

    const resultados = [];
    for (const url of urls) {
      const datos = await extraerDetalleEstructurado(page, url);
      if (datos) {
        resultados.push(datos);
      }
      await page.waitForTimeout(1000);
    }

    const archivoSalida = resolve(process.cwd(), 'eventos_puntoticket_perfecto.json');
    await writeFile(archivoSalida, `${JSON.stringify(resultados, null, 4)}\n`, 'utf8');
    console.log(`\nProceso completado. Revisa ${archivoSalida}.`);
    return resultados;
  } finally {
    await browser.close();
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  ejecutarScraperPuntoTicket().catch(error => {
    console.error('Error ejecutando el scraper de PuntoTicket:', error);
    process.exitCode = 1;
  });
}


