import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buscarEventosTicketmaster,
  normalizarEventoTicketmaster,
  obtenerDetalleEventoTM
} from './ticketmaster.js';

test('normaliza un evento de Ticketmaster al contrato común de ingesta', () => {
  const evento = normalizarEventoTicketmaster({
    id: 'TM123',
    name: 'Concierto de prueba',
    info: 'Descripción',
    dates: {
      start: {
        localDate: '2027-02-28',
        localTime: '21:00:00',
        dateTime: '2027-03-01T00:00:00Z'
      }
    },
    images: [
      { ratio: '3_2', url: 'https://example.com/other.jpg' },
      { ratio: '16_9', url: 'https://example.com/event.jpg' }
    ],
    url: 'https://example.com/tickets',
    classifications: [{ segment: { name: 'Music' }, genre: { name: 'Rock' } }],
    _embedded: {
      venues: [{
        name: 'Estadio Nacional',
        address: { line1: 'Av. Grecia 2001' },
        city: { name: 'Ñuñoa' },
        country: { countryCode: 'CL' },
        location: { latitude: '-33.46', longitude: '-70.61' }
      }]
    },
    promoters: [{ name: 'Promotor de prueba' }]
  });

  assert.deepEqual(evento, {
    id_externo: 'TM123',
    nombre: 'Concierto de prueba',
    descripcion: 'Descripción',
    fecha_inicio: '2027-03-01T00:00:00Z',
    fecha_termino: null,
    imagen_url: 'https://example.com/event.jpg',
    url_pagina_compra: 'https://example.com/tickets',
    direccion: 'Estadio Nacional - Av. Grecia 2001 - Ñuñoa - CL',
    comuna: 'Ñuñoa',
    latitud: -33.46,
    longitud: -70.61,
    organizador: 'Promotor de prueba',
    clasificaciones_fuente: [{ macro_categoria: 'Música' }]
  });
});

test('usa la fecha local y el huso horario si falta dateTime', () => {
  const evento = normalizarEventoTicketmaster({
    id: 'TM124',
    name: 'Evento local',
    dates: { start: { localDate: '2027-02-28', localTime: '21:00:00' } },
    _embedded: { venues: [{ country: { countryCode: 'CL' } }] }
  });

  assert.equal(evento.fecha_inicio, '2027-02-28T21:00:00-03:00');
});

test('no inventa macro-categoría para clasificaciones ambiguas', () => {
  const evento = normalizarEventoTicketmaster({
    id: 'TM125',
    name: 'Evento cultural',
    classifications: [
      { segment: { name: 'Arts & Theatre' }, genre: { name: 'Comedy' } }
    ]
  });

  assert.deepEqual(evento.clasificaciones_fuente, []);
});

test('clasifica en Familia cuando Ticketmaster lo especifica en family', () => {
  const evento = normalizarEventoTicketmaster({
    id: 'TM126',
    name: 'Evento familiar',
    classifications: [{
      segment: { name: 'Arts & Theatre' },
      genre: { name: "Children's Theatre" },
      family: { name: 'Family' }
    }]
  });

  assert.deepEqual(evento.clasificaciones_fuente, [{ macro_categoria: 'Familia' }]);
});

test('deduplica IDs devueltos por la consulta de Ticketmaster', async t => {
  const apiKeyOriginal = process.env.TICKETMASTER_API_KEY;
  const fetchOriginal = globalThis.fetch;
  process.env.TICKETMASTER_API_KEY = 'test-key';
  globalThis.fetch = async url => {
    const parsedUrl = new URL(url);
    assert.equal(parsedUrl.searchParams.get('countryCode'), 'CL');
    assert.equal(parsedUrl.searchParams.get('size'), '20');
    assert.equal(parsedUrl.searchParams.get('apikey'), 'test-key');
    return {
      ok: true,
      async json() {
        return {
          _embedded: {
            events: [{ id: 'TM1' }, { id: 'TM1' }, {}, { id: 'TM2' }]
          }
        };
      }
    };
  };
  t.after(() => {
    globalThis.fetch = fetchOriginal;
    if (apiKeyOriginal === undefined) {
      delete process.env.TICKETMASTER_API_KEY;
    } else {
      process.env.TICKETMASTER_API_KEY = apiKeyOriginal;
    }
  });

  assert.deepEqual(await buscarEventosTicketmaster('cl', '20'), ['TM1', 'TM2']);
});

test('obtiene y normaliza detalle de evento por ID', async t => {
  const apiKeyOriginal = process.env.TICKETMASTER_API_KEY;
  const fetchOriginal = globalThis.fetch;
  process.env.TICKETMASTER_API_KEY = 'test-key';
  globalThis.fetch = async url => {
    const parsedUrl = new URL(url);
    assert.equal(parsedUrl.pathname, '/discovery/v2/events/TM%2F123.json');
    assert.equal(parsedUrl.searchParams.get('apikey'), 'test-key');
    return {
      ok: true,
      async json() {
        return { id: 'TM/123', name: 'Evento API', dates: { start: { dateTime: '2027-01-01T20:00:00Z' } } };
      }
    };
  };
  t.after(() => {
    globalThis.fetch = fetchOriginal;
    if (apiKeyOriginal === undefined) {
      delete process.env.TICKETMASTER_API_KEY;
    } else {
      process.env.TICKETMASTER_API_KEY = apiKeyOriginal;
    }
  });

  const evento = await obtenerDetalleEventoTM('TM/123');
  assert.equal(evento.id_externo, 'TM/123');
  assert.equal(evento.nombre, 'Evento API');
  assert.equal(evento.fecha_inicio, '2027-01-01T20:00:00Z');
});
