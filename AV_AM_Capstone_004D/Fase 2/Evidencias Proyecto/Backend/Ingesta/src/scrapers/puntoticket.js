import { writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
import { normalizarFechasPuntoTicket } from '../utils/dateNormalizer.js';
import {
  extraerCoordenadasGooGl,
  extraerLugarDesdeUrl,
  geocodificarPorLugar
} from '../utils/geoUtils.js';

export { normalizarFechasPuntoTicket } from '../utils/dateNormalizer.js';
export { extraerLugarDesdeUrl } from '../utils/geoUtils.js';

const URLS_SEMILLA = [
  'https://www.puntoticket.com/',
  'https://www.puntoticket.com/musica',
  'https://www.puntoticket.com/teatro',
  'https://www.puntoticket.com/deportes',
  'https://www.puntoticket.com/familia',
  'https://www.puntoticket.com/especiales',
  'https://www.puntoticket.com/todos'
];

const MACRO_CATEGORIAS = new Map([
  ['musica', 'Música'],
  ['teatro', 'Teatro'],
  ['deportes', 'Deportes'],
  ['familia', 'Familia']
]);

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

function quitarAcentos(texto) {
  return texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

export function extraerComunaPuntoTicket(direccion) {
  if (typeof direccion !== 'string' || !direccion.trim()) {
    return null;
  }

  const partes = direccion
    .split(/\s*[,–—-]\s*/)
    .map(parte => parte.trim())
    .filter(Boolean);
  if (partes.length < 2) {
    return null;
  }

  let comuna = partes[partes.length - 1].replace(/\s*,?\s*Chile$/i, '').trim();
  const comunaSinAcentos = quitarAcentos(comuna).toLocaleLowerCase('es-CL');

  const equivalencias = new Map([
    ['santiago centro', 'Santiago'],
    ['san carlos de apoquindo', 'Las Condes'],
    ['san carlos de apoquind', 'Las Condes'],
    ['san pedro de la paz', 'San Pedro de La Paz'],
    ['padre las casas', 'Padre Las Casas']
  ]);
  const equivalencia = equivalencias.get(comunaSinAcentos);
  if (equivalencia) {
    return equivalencia;
  }

  const palabras = comuna
    .toLocaleLowerCase('es-CL')
    .replace(/(^|[\s'-])([a-záéíóúñ])/g, (_, separador, letra) =>
      `${separador}${letra.toLocaleUpperCase('es-CL')}`
    )
    .split(/\s+/);
  const conectores = new Set(['De', 'Del', 'La', 'Las', 'Los', 'Y']);
  comuna = palabras
    .map((palabra, indice) =>
      indice > 0 && conectores.has(palabra)
        ? palabra.toLocaleLowerCase('es-CL')
        : palabra
    )
    .join(' ');

  return comuna;
}

export function extraerEtiquetaCategoriaPuntoTicket(textoTarjeta) {
  if (typeof textoTarjeta !== 'string') {
    return null;
  }

  const textoNormalizado = textoTarjeta.replace(/\s+/g, ' ').trim();
  const indiceSeparador = textoNormalizado.lastIndexOf('/');
  if (indiceSeparador < 0) {
    return null;
  }

  return textoNormalizado.slice(indiceSeparador + 1).trim() || null;
}

export function extraerIdExternoPuntoTicket(url, idTarjeta = null) {
  if (typeof idTarjeta === 'string' && idTarjeta.trim()) {
    return idTarjeta.trim();
  }

  const segmentos = new URL(url).pathname.split('/').filter(Boolean);
  const indiceEvento = segmentos.findIndex(segmento => segmento.toLowerCase() === 'evento');
  const identificador = indiceEvento >= 0 ? segmentos[indiceEvento + 1] : segmentos.at(-1);
  return identificador ? decodeURIComponent(identificador) : null;
}

/*
OBTENER LAS URLs
*/


export async function obtenerUrlsEventos(page) {
  const eventosPorUrl = new Map();
  console.log('Buscando eventos en secciones principales...');

  for (const url of URLS_SEMILLA) {
    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });
      await page.waitForTimeout(1500);

      const links = await page.locator(
        'article.event-item a[href], a[href*="/evento/"]'
      ).evaluateAll(anchors =>
        anchors.map(anchor => {
          const articulo = anchor.closest('article.event-item');
          const textoTarjeta = articulo
            ?.querySelector('.evento--box .descripcion')
            ?.innerText;
          return {
            href: anchor.getAttribute('href'),
            idTarjeta: anchor.getAttribute('data-eventid') ||
              articulo?.getAttribute('data-eventid') ||
              null,
            textoTarjeta: textoTarjeta || null
          };
        }).filter(link => link.href)
      );

      const macroCategoria = MACRO_CATEGORIAS.get(new URL(url).pathname.replace(/^\/|\/$/g, '').toLowerCase()) || null;
      for (const link of links) {
        const urlEvento = new URL(link.href, 'https://www.puntoticket.com').href;
        const eventoExistente = eventosPorUrl.get(urlEvento) || {
          id_externo: extraerIdExternoPuntoTicket(urlEvento, link.idTarjeta),
          clasificaciones_fuente: []
        };
        const clasificacion = {
          ...(macroCategoria ? { macro_categoria: macroCategoria } : {}),
          etiqueta: extraerEtiquetaCategoriaPuntoTicket(link.textoTarjeta)
        };
        const clasificacionesCoincidentes = eventoExistente.clasificaciones_fuente.filter(
          existente => existente.etiqueta === clasificacion.etiqueta
        );
        const yaExiste = clasificacion.macro_categoria
          ? clasificacionesCoincidentes.some(
              existente => existente.macro_categoria === clasificacion.macro_categoria
            )
          : clasificacionesCoincidentes.length > 0;
        if (clasificacion.macro_categoria && clasificacionesCoincidentes.some(
          existente => !existente.macro_categoria
        )) {
          eventoExistente.clasificaciones_fuente = eventoExistente.clasificaciones_fuente.filter(
            existente =>
              existente.etiqueta !== clasificacion.etiqueta || existente.macro_categoria
          );
        }
        if (!yaExiste) {
          eventoExistente.clasificaciones_fuente.push(clasificacion);
        }
        eventoExistente.id_externo ||= extraerIdExternoPuntoTicket(urlEvento, link.idTarjeta);
        eventosPorUrl.set(urlEvento, eventoExistente);
      }
    } catch (error) {
      console.error(`Error al cargar ${url}: ${error.message}`);
    }
  }

  return [...eventosPorUrl].map(([url, evento]) => ({
    url,
    id_externo: evento.id_externo,
    clasificaciones_fuente: evento.clasificaciones_fuente
  }));
}
/*
EXTRAER EL DETALLE DE CADA EVENTO
*/


export async function extraerDetalleEstructurado(page, url, opciones = {}) {
  const {
    clasificacionesFuente = [],
    idExterno = null
  } = opciones;
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

    const fechasNormalizadas = normalizarFechasPuntoTicket(fechaHora);


    /**
     * OBTENER DIRECCION
     */
    let lugar = null;
    let urlMapa = null;

    const mapLink = page
      .locator("a[href*='maps.app.goo.gl'], a[href*='google.com/maps']")
      .first();

    if ((await mapLink.count()) > 0) {
      urlMapa = await mapLink.getAttribute('href');
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


    let coordenadas = urlMapa 
      ? await extraerCoordenadasGooGl(urlMapa) 
      : { latitud: null, longitud: null };


    if ((!coordenadas.latitud || !coordenadas.longitud) && lugar) {
      coordenadas = await geocodificarPorLugar(lugar);
    }

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

    const id_evento = extraerIdExternoPuntoTicket(url, idExterno);


    /**
     * OBTENER ORGANIZADOR
     */

    let organizador = null;

    // Busca un span o texto que contenga "Produce:"
    const elementosProduce = page.locator('span.heading, span, p, div').filter({
      hasText: /Produce\s*:/i
    });

    // Recorre los candidatos desde el más específico (o buscamos la línea exacta)
    for (let i = 0; i < (await elementosProduce.count()); i += 1) {
      const texto = await elementosProduce.nth(i).innerText();

      // Busca "Produce:" y captura SOLO lo que sigue en esa misma línea (máximo 80 caracteres)
      const match = texto.match(/Produce\s*:\s*([^\n\r]{2,80})/i);

      if (match && match[1]) {
        organizador = match[1].trim();
        break; // Apenas encuentra el nombre limpio, sale del bucle
      }
    }
    /*
    id_evento - listo
    nombre - listo
    descripción - listo
    dirección - listo
    imagen_url - listo
    fecha_hora - listo
    latitud - listo
    longitud - listo
    id_tipo_evento - 
    organizador -  listo
    url_pagina_compra - listo
    fechas {}***
    */


    return {
      id_externo: id_evento,
      clasificaciones_fuente: clasificacionesFuente,
      nombre: titulo,
      descripcion: textoDescripcion.slice(0, 5).join('\n'),
      direccion: lugar,
      comuna: extraerComunaPuntoTicket(lugar),
      imagen_url: imagen,
      fecha_hora: fechaHora || null,
      fecha_inicio: fechasNormalizadas.fecha_inicio,
      fecha_termino: fechasNormalizadas.fecha_termino,
      longitud: coordenadas.longitud,
      latitud: coordenadas.latitud,
      organizador: organizador,
      url_pagina_compra: url
    };
  } catch (error) {
    console.error(`Error procesando ${url}: ${error.message}`);
    return null;
  }
}

export async function ejecutarScraperPuntoTicket({ guardarArchivo = true } = {}) {
  const browser = await chromium.launch({ headless: true });

  try {
    const context = await browser.newContext({ userAgent: USER_AGENT });
    const page = await context.newPage();
    const eventosListado = await obtenerUrlsEventos(page);
    console.log(`\nTotal de eventos encontrados: ${eventosListado.length}`);

    const resultados = [];
    for (const eventoListado of eventosListado) {
      const datos = await extraerDetalleEstructurado(
        page,
        eventoListado.url,
        {
          clasificacionesFuente: eventoListado.clasificaciones_fuente,
          idExterno: eventoListado.id_externo
        }
      );
      if (datos) {
        resultados.push(datos);
      }
      await page.waitForTimeout(1000);
    }

    if (guardarArchivo) {
      const directorioScraper = dirname(fileURLToPath(import.meta.url));
      const archivoSalida = resolve(directorioScraper, '../../eventos_puntoticket_perfecto.json');
      await writeFile(archivoSalida, `${JSON.stringify(resultados, null, 4)}\n`, 'utf8');
      console.log(`\nProceso completado. Revisa ${archivoSalida}.`);
    }

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
