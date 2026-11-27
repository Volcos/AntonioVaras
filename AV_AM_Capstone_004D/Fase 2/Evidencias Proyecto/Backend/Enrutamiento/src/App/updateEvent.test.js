import assert from 'node:assert/strict';
import Fastify from 'fastify';
import { test } from 'node:test';
import actualizarEvento from './updateEvent.js';

async function crearServidor({ comunas, tiposEvento, evento, error } = {}) {
  const consultas = [];
  const app = Fastify();
  app.decorate('sql', async (strings, ...valores) => {
    const consulta = strings.join('?');
    consultas.push({ consulta, valores });

    if (error) {
      throw error;
    }
    if (consulta.includes('SELECT id_comuna')) {
      return comunas ?? [{ id_comuna: 86, nombre_comuna: 'Santiago' }];
    }
    if (consulta.includes('SELECT id_tipo_evento')) {
      return tiposEvento ?? [{ id_tipo_evento: 1, nombre_tipo_evento: 'Música' }];
    }
    if (consulta.includes('UPDATE evento')) {
      return evento ? [evento] : [];
    }
    throw new Error('Consulta SQL inesperada.');
  });
  await app.register(actualizarEvento);
  return { app, consultas };
}

const eventoValido = {
  nombre: 'Evento actualizado',
  descripcion: 'Descripción actualizada',
  direccion: 'Teatro Municipal',
  comuna: 'santiago',
  tipo_evento: 'música',
  fechas: [
    {
      fecha_inicio: '2026-11-12T20:00:00-03:00',
      fecha_termino: null,
      precio_desde: 15000
    }
  ],
  url_pagina_compra: 'https://ejemplo.cl/compra',
  latitud: -33.45,
  longitud: -70.66,
  organizador: 'Organizador'
};

test('actualiza el evento, sus funciones y la URL de compra', async () => {
  const actualizado = { id_evento: 42, nombre: eventoValido.nombre };
  const { app, consultas } = await crearServidor({ evento: actualizado });

  try {
    const response = await app.inject({
      method: 'PUT',
      url: '/eventos/42',
      payload: eventoValido
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json().data, actualizado);
    const actualizacion = consultas.find(({ consulta }) => consulta.includes('UPDATE evento'));
    assert.ok(actualizacion);
    assert.match(actualizacion.consulta, /DELETE FROM fecha_evento/);
    assert.match(actualizacion.consulta, /INSERT INTO fecha_evento/);
    assert.match(actualizacion.consulta, /INSERT INTO evento_fuente/);
    assert.equal(actualizacion.valores.includes('42'), true);
    assert.equal(actualizacion.valores.includes(86), true);
    assert.equal(actualizacion.valores.includes(1), true);
    assert.ok(actualizacion.valores.includes(JSON.stringify(eventoValido.fechas)));
  } finally {
    await app.close();
  }
});

test('devuelve 404 si el evento no existe', async () => {
  const { app } = await crearServidor();

  try {
    const response = await app.inject({
      method: 'PUT',
      url: '/eventos/42',
      payload: eventoValido
    });

    assert.equal(response.statusCode, 404);
    assert.equal(response.json().success, false);
  } finally {
    await app.close();
  }
});

test('rechaza un ID o fechas inválidas antes de consultar la base', async () => {
  const { app, consultas } = await crearServidor();

  try {
    const respuestaId = await app.inject({
      method: 'PUT',
      url: '/eventos/invalido',
      payload: eventoValido
    });
    const respuestaFechas = await app.inject({
      method: 'PUT',
      url: '/eventos/42',
      payload: { ...eventoValido, fechas: [] }
    });

    assert.equal(respuestaId.statusCode, 400);
    assert.equal(respuestaFechas.statusCode, 400);
    assert.equal(consultas.length, 0);
  } finally {
    await app.close();
  }
});

test('devuelve 400 si no existe la comuna o el tipo de evento', async () => {
  const { app, consultas } = await crearServidor({ comunas: [] });

  try {
    const response = await app.inject({
      method: 'PUT',
      url: '/eventos/42',
      payload: eventoValido
    });

    assert.equal(response.statusCode, 400);
    assert.equal(response.json().success, false);
    assert.equal(consultas.some(({ consulta }) => consulta.includes('UPDATE evento')), false);
  } finally {
    await app.close();
  }
});
