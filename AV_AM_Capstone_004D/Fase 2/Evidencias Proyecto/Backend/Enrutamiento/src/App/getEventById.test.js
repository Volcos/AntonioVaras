import assert from 'node:assert/strict';
import Fastify from 'fastify';
import { test } from 'node:test';
import obtenerEventoPorId from './getEventById.js';

async function crearServidor({ eventos = [], error } = {}) {
  const consultas = [];
  const app = Fastify();
  app.decorate('sql', async (strings, ...valores) => {
    consultas.push({ consulta: strings.join('?'), valores });
    if (error) {
      throw error;
    }
    return eventos;
  });
  await app.register(obtenerEventoPorId);
  return { app, consultas };
}

test('devuelve los datos editables del evento, sus fechas y la URL de compra', async () => {
  const evento = {
    id_evento: 42,
    nombre: 'Concierto',
    descripcion: 'Descripción',
    direccion: 'Teatro Municipal',
    imagen_url: 'https://ejemplo.cl/imagen.jpg',
    id_comuna: 86,
    nombre_comuna: 'Santiago',
    id_tipo_evento: 1,
    nombre_tipo_evento: 'Música',
    latitud: -33.45,
    longitud: -70.66,
    organizador: 'Productora',
    fechas: [{
      id_fecha: 100,
      fecha_inicio: '2026-12-15T23:00:00.000Z',
      fecha_termino: '2026-12-16T01:00:00.000Z',
      precio_desde: 15000
    }],
    url_pagina_compra: 'https://ejemplo.cl/entradas'
  };
  const { app, consultas } = await crearServidor({ eventos: [evento] });

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/eventos/42'
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json(), { success: true, data: evento });
    assert.match(consultas[0].consulta, /FROM evento e/);
    assert.match(consultas[0].consulta, /FROM fecha_evento fe/);
    assert.match(consultas[0].consulta, /url_pagina_compra/);
    assert.equal(consultas[0].valores[0], '42');
  } finally {
    await app.close();
  }
});

test('responde 404 si no existe el evento', async () => {
  const { app } = await crearServidor();

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/eventos/42'
    });

    assert.equal(response.statusCode, 404);
    assert.equal(response.json().success, false);
  } finally {
    await app.close();
  }
});

test('rechaza un ID inválido antes de consultar la base', async () => {
  const { app, consultas } = await crearServidor();

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/eventos/no-es-un-id'
    });

    assert.equal(response.statusCode, 400);
    assert.equal(consultas.length, 0);
  } finally {
    await app.close();
  }
});

test('devuelve 500 y registra el error si falla la consulta', async () => {
  const { app } = await crearServidor({ error: new Error('Database failure') });

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/eventos/42'
    });

    assert.equal(response.statusCode, 500);
    assert.equal(response.json().success, false);
  } finally {
    await app.close();
  }
});
