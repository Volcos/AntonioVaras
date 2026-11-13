import assert from 'node:assert/strict';
import Fastify from 'fastify';
import { test } from 'node:test';
import crearEvento from './createEvent.js';

async function crearServidor({ comunas, tiposEvento } = {}) {
  const consultas = [];
  const app = Fastify();
  app.decorate('sql', async (strings, ...valores) => {
    const consulta = strings.join('?');
    consultas.push({ consulta, valores });

    if (consulta.includes('SELECT id_comuna')) {
      return comunas ?? [{ id_comuna: 86, nombre_comuna: 'Santiago' }];
    }
    if (consulta.includes('SELECT id_tipo_evento')) {
      return tiposEvento ?? [{ id_tipo_evento: 1, nombre_tipo_evento: 'Música' }];
    }
    if (consulta.includes('WITH evento_insertado')) {
      const fechas = JSON.parse(valores[9]);
      return [{
        id_evento: 101,
        id_comuna: valores[4],
        id_tipo_evento: valores[5],
        fechas: fechas.map((fecha, index) => ({
          id_fecha: 201 + index,
          ...fecha
        })),
        nombre_comuna: valores[10],
        nombre_tipo_evento: valores[11]
      }];
    }
    throw new Error('Consulta SQL inesperada.');
  });
  await app.register(crearEvento);
  return { app, consultas };
}

const eventoValido = {
  nombre: 'Evento de prueba',
  direccion: 'Teatro Municipal',
  comuna: 'santiago',
  tipo_evento: 'música',
  fechas: [
    {
      fecha_inicio: '2026-11-12T20:00:00-03:00',
      fecha_termino: null,
      precio_desde: 15000
    },
    {
      fecha_inicio: '2026-11-13T20:00:00-03:00',
      fecha_termino: '2026-11-13T22:00:00-03:00',
      precio_desde: 18000
    }
  ]
};

test('resuelve comuna y tipo por nombre e inserta todas las funciones del evento', async () => {
  const { app, consultas } = await crearServidor();
  try {
    const response = await app.inject({
      method: 'POST',
      url: '/eventos',
      payload: eventoValido
    });

    assert.equal(response.statusCode, 201);
    assert.equal(response.json().data.id_comuna, 86);
    assert.equal(response.json().data.id_tipo_evento, 1);
    assert.equal(response.json().data.fechas.length, 2);
    assert.ok(consultas.some(({ consulta }) => consulta.includes('INSERT INTO fecha_evento')));
    const insercion = consultas.find(({ consulta }) => consulta.includes('WITH evento_insertado'));
    assert.equal(insercion.valores[4], 86);
    assert.equal(insercion.valores[5], 1);
    assert.deepEqual(JSON.parse(insercion.valores[9]), eventoValido.fechas);
    assert.match(insercion.consulta, /jsonb_to_recordset/);
    assert.match(insercion.consulta, /precio_desde/);
  } finally {
    await app.close();
  }
});

test('devuelve 400 si la comuna o el tipo de evento no existe', async () => {
  const { app, consultas } = await crearServidor({ comunas: [] });
  try {
    const response = await app.inject({
      method: 'POST',
      url: '/eventos',
      payload: eventoValido
    });

    assert.equal(response.statusCode, 400);
    assert.match(response.json().message, /comuna/);
    assert.equal(
      consultas.some(({ consulta }) => consulta.includes('WITH evento_insertado')),
      false
    );
  } finally {
    await app.close();
  }
});

test('rechaza fechas ausentes o vacías antes de consultar la base', async () => {
  const { app, consultas } = await crearServidor();
  try {
    const { fechas, ...sinFechas } = eventoValido;
    const response = await app.inject({
      method: 'POST',
      url: '/eventos',
      payload: sinFechas
    });

    assert.equal(response.statusCode, 400);
    assert.equal(consultas.length, 0);

    const responseFechasVacias = await app.inject({
      method: 'POST',
      url: '/eventos',
      payload: { ...eventoValido, fechas: [] }
    });

    assert.equal(responseFechasVacias.statusCode, 400);
    assert.equal(consultas.length, 0);
  } finally {
    await app.close();
  }
});

test('rechaza una función con fecha inválida o precio negativo', async () => {
  const { app, consultas } = await crearServidor();
  try {
    const responseFechaInvalida = await app.inject({
      method: 'POST',
      url: '/eventos',
      payload: {
        ...eventoValido,
        fechas: [{ fecha_inicio: 'fecha inválida' }]
      }
    });
    const responsePrecioNegativo = await app.inject({
      method: 'POST',
      url: '/eventos',
      payload: {
        ...eventoValido,
        fechas: [{
          fecha_inicio: '2026-11-12T20:00:00-03:00',
          precio_desde: -1
        }]
      }
    });

    assert.equal(responseFechaInvalida.statusCode, 400);
    assert.equal(responsePrecioNegativo.statusCode, 400);
    assert.equal(consultas.length, 0);
  } finally {
    await app.close();
  }
});
