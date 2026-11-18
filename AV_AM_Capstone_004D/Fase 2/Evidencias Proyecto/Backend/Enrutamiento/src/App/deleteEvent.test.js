import assert from 'node:assert/strict';
import Fastify from 'fastify';
import { test } from 'node:test';
import eliminarEvento from './deleteEvent.js';

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
  await app.register(eliminarEvento);
  return { app, consultas };
}

test('elimina el evento y devuelve el identificador y nombre', async () => {
  const evento = { id_evento: 42, nombre: 'Concierto de prueba' };
  const { app, consultas } = await crearServidor({ eventos: [evento] });

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: '/eventos/42'
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json().data, evento);
    assert.match(consultas[0].consulta, /DELETE FROM evento/);
    assert.match(consultas[0].consulta, /RETURNING id_evento, nombre/);
    assert.equal(consultas[0].valores[0], '42');
  } finally {
    await app.close();
  }
});

test('responde 404 si no existe el evento', async () => {
  const { app } = await crearServidor();

  try {
    const response = await app.inject({
      method: 'DELETE',
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
      method: 'DELETE',
      url: '/eventos/no-es-un-id'
    });

    assert.equal(response.statusCode, 400);
    assert.equal(consultas.length, 0);
  } finally {
    await app.close();
  }
});

test('responde 500 y registra el error si falla la consulta', async () => {
  const { app } = await crearServidor({ error: new Error('Database failure') });

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: '/eventos/42'
    });

    assert.equal(response.statusCode, 500);
    assert.equal(response.json().success, false);
  } finally {
    await app.close();
  }
});
