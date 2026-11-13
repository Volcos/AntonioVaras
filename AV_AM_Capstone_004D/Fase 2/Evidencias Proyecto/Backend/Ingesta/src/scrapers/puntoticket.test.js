import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import {
  extraerComunaPuntoTicket,
  extraerEtiquetaCategoriaPuntoTicket,
  extraerIdExternoPuntoTicket,
  extraerLugarDesdeUrl,
  normalizarFechasPuntoTicket,
  obtenerUrlsEventos
} from './puntoticket.js';
import { geocodificarPorLugar } from '../utils/geoUtils.js';

test('normaliza una fecha puntual y conserva la hora de Chile', () => {
  assert.deepEqual(
    normalizarFechasPuntoTicket('08-11-2026 - 15:00 Hrs. - NOVIEMBRE 15:00'),
    {
      fecha_inicio: '2026-11-08T15:00:00-03:00',
      fecha_termino: null
    }
  );
});

test('normaliza rangos numéricos y usa la hora final indicada', () => {
  assert.deepEqual(
    normalizarFechasPuntoTicket(
      '19-03-2027 al 20-03-2027 - 19:30 Hrs. - MARZO 19:30 - MARZO 20:00'
    ),
    {
      fecha_inicio: '2027-03-19T19:30:00-03:00',
      fecha_termino: '2027-03-20T20:00:00-03:00'
    }
  );
});

test('normaliza rangos en español sin año y con ciclo/año explícitos', () => {
  const anioActual = new Intl.DateTimeFormat('en', {
    timeZone: 'America/Santiago',
    year: 'numeric'
  }).format(new Date());

  assert.deepEqual(
    normalizarFechasPuntoTicket('DESDE EL 22 DE JULIO AL 21 DE NOVIEMBRE'),
    {
      fecha_inicio: `${anioActual}-07-22T00:00:00-04:00`,
      fecha_termino: `${anioActual}-11-21T00:00:00-03:00`
    }
  );
  assert.deepEqual(
    normalizarFechasPuntoTicket('Primer Ciclo: 7 al 18 de diciembre de 2026'),
    {
      fecha_inicio: '2026-12-07T00:00:00-03:00',
      fecha_termino: '2026-12-18T00:00:00-03:00'
    }
  );
});

test('interpreta todas las fechas del JSON de muestra', async () => {
  const archivo = new URL('../../eventos_puntoticket_perfecto.json', import.meta.url);
  const eventos = JSON.parse(await readFile(archivo, 'utf8'));

  for (const evento of eventos) {
    const fechas = normalizarFechasPuntoTicket(evento.fecha_hora);
    assert.ok(fechas.fecha_inicio, `No se interpretó: ${evento.fecha_hora}`);
    assert.ok(Number.isFinite(Date.parse(fechas.fecha_inicio)));

    if (/\bal\b|\bhasta\b/i.test(evento.fecha_hora)) {
      assert.ok(fechas.fecha_termino, `Falta fecha término: ${evento.fecha_hora}`);
      assert.ok(Number.isFinite(Date.parse(fechas.fecha_termino)));
    } else {
      assert.equal(fechas.fecha_termino, null);
    }
  }
});

test('devuelve fechas nulas para texto que no contiene una fecha reconocible', () => {
  assert.deepEqual(normalizarFechasPuntoTicket('Fecha por confirmar'), {
    fecha_inicio: null,
    fecha_termino: null
  });
});

test('extrae y normaliza comunas desde los formatos de dirección de PuntoTicket', () => {
  const casos = [
    ['Estadio El Teniente - Rancagua', 'Rancagua'],
    ['Claro Arena - Las Condes', 'Las Condes'],
    ['Teatro Caupolicán - Santiago Centro', 'Santiago'],
    ['Estadio Santa Laura - Universidad SEK - Independencia', 'Independencia'],
    ['Fortín Cruzado, San Carlos de Apoquindo', 'Las Condes'],
    ['Estadio - San Pedro de Atacama', 'San Pedro de Atacama'],
    ['Estadio - San Pedro de La Paz', 'San Pedro de La Paz'],
    ['Estadio - La Serena', 'La Serena'],
    ['teatro del lago - frutillar', 'Frutillar'],
    ['Club Amanda – Vitacura', 'Vitacura']
  ];

  for (const [direccion, comunaEsperada] of casos) {
    assert.equal(extraerComunaPuntoTicket(direccion), comunaEsperada);
  }
});

test('devuelve null si no hay comuna separada en la dirección', () => {
  assert.equal(extraerComunaPuntoTicket('Teatro Municipal'), null);
  assert.equal(extraerComunaPuntoTicket(null), null);
});

test('mantiene la extracción del recinto desde la URL y los recintos conocidos', async () => {
  assert.equal(
    extraerLugarDesdeUrl('https://www.puntoticket.com/evento/show-teatro-caupolican'),
    'Teatro Caupolican'
  );
  assert.deepEqual(await geocodificarPorLugar('Teatro Caupolicán - Santiago'), {
    latitud: -33.45694,
    longitud: -70.64827
  });
  assert.deepEqual(await geocodificarPorLugar(null), {
    latitud: null,
    longitud: null
  });
});

test('extrae la etiqueta de clasificación desde la descripción de una tarjeta', () => {
  assert.equal(extraerEtiquetaCategoriaPuntoTicket('Teatro Caupolicán / Pop'), 'Pop');
  assert.equal(extraerEtiquetaCategoriaPuntoTicket('Recinto/Conciertos'), 'Conciertos');
  assert.equal(extraerEtiquetaCategoriaPuntoTicket('Teatro Caupolicán'), null);
});

test('obtiene el identificador de PuntoTicket desde la tarjeta o la URL', () => {
  assert.equal(
    extraerIdExternoPuntoTicket('https://www.puntoticket.com/karol-g', 'BIZ378'),
    'BIZ378'
  );
  assert.equal(
    extraerIdExternoPuntoTicket('https://www.puntoticket.com/evento/BIZ378'),
    'BIZ378'
  );
  assert.equal(
    extraerIdExternoPuntoTicket('https://www.puntoticket.com/karol-g'),
    'karol-g'
  );
});

test('deduplica enlaces y conserva clasificaciones de todas las secciones', async () => {
  const tarjetasPorSeccion = {
    '/musica': [
      { href: '/karol-g', id: 'BIZ378', texto: 'Movistar Arena / Urbano' }
    ],
    '/especiales': [
      { href: '/karol-g', id: 'BIZ378', texto: 'Movistar Arena / Conciertos' },
      { href: '/festival', id: null, texto: 'Parque / Festival' }
    ],
    '/todos': [
      { href: '/karol-g', id: 'BIZ378', texto: 'Movistar Arena / Urbano' }
    ]
  };
  let seccionActual = '/';

  const page = {
    async goto(url) {
      seccionActual = new URL(url).pathname;
    },
    async waitForTimeout() {},
    locator() {
      return {
        async evaluateAll(mapper) {
          const anchors = (tarjetasPorSeccion[seccionActual] || []).map(tarjeta => {
            const articulo = {
              getAttribute(nombre) {
                return nombre === 'data-eventid' ? tarjeta.id : null;
              },
              querySelector() {
                return tarjeta.texto ? { innerText: tarjeta.texto } : null;
              }
            };
            return {
              closest() {
                return articulo;
              },
              getAttribute(nombre) {
                if (nombre === 'href') return tarjeta.href;
                if (nombre === 'data-eventid') return tarjeta.id;
                return null;
              }
            };
          });
          return mapper(anchors);
        }
      };
    }
  };

  const eventos = await obtenerUrlsEventos(page);
  assert.equal(eventos.length, 2);
  assert.deepEqual(eventos[0], {
    url: 'https://www.puntoticket.com/karol-g',
    id_externo: 'BIZ378',
    clasificaciones_fuente: [
      { macro_categoria: 'Música', etiqueta: 'Urbano' },
      { etiqueta: 'Conciertos' }
    ]
  });
  assert.deepEqual(eventos[1], {
    url: 'https://www.puntoticket.com/festival',
    id_externo: 'festival',
    clasificaciones_fuente: [
      { etiqueta: 'Festival' }
    ]
  });
});
