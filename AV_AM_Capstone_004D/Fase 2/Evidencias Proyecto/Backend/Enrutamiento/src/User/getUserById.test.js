import assert from 'node:assert/strict';
import Fastify from 'fastify';
import { test } from 'node:test';
import obtenerUsuarioPorId from './getUserById.js';

async function crearServidor({ usuarios = [], error } = {}) {
  const consultas = [];
  const app = Fastify();
  app.decorate('sql', async (strings, ...valores) => {
    consultas.push({ consulta: strings.join('?'), valores });
    if (error) {
      throw error;
    }
    return usuarios;
  });
  await app.register(obtenerUsuarioPorId);
  return { app, consultas };
}

test('devuelve los datos del usuario sin consultar ni exponer la contraseña', async () => {
  const usuario = {
    id_usuario: 12,
    nombre_usuario: 'Ana Ejemplo',
    rut: '12345678-9',
    email: 'ana@example.com',
    id_tipo_usuario: 2
  };
  const { app, consultas } = await crearServidor({ usuarios: [usuario] });

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/usuarios/12'
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json().data, usuario);
    assert.equal('contrasena' in response.json().data, false);
    assert.match(consultas[0].consulta, /SELECT id_usuario, nombre_usuario, rut, email, id_tipo_usuario/);
    assert.equal(consultas[0].valores[0], '12');
  } finally {
    await app.close();
  }
});

test('responde 404 si no existe el usuario', async () => {
  const { app } = await crearServidor();

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/usuarios/12'
    });

    assert.equal(response.statusCode, 404);
    assert.equal(response.json().success, false);
  } finally {
    await app.close();
  }
});

test('rechaza un ID inválido antes de consultar la base de datos', async () => {
  const { app, consultas } = await crearServidor();

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/usuarios/abc'
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
      method: 'GET',
      url: '/usuarios/12'
    });

    assert.equal(response.statusCode, 500);
    assert.equal(response.json().success, false);
  } finally {
    await app.close();
  }
});
