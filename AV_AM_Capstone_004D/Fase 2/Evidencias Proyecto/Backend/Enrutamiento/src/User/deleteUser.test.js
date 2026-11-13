import assert from 'node:assert/strict';
import Fastify from 'fastify';
import { test } from 'node:test';
import eliminarUsuario from './deleteUser.js';
import { hashPassword } from './passwordUtils.js';

async function crearServidor({ usuario, error } = {}) {
  const consultas = [];
  const app = Fastify();
  app.decorate('sql', async (strings, ...valores) => {
    const consulta = strings.join('?');
    consultas.push({ consulta, valores });

    if (error) {
      throw error;
    }
    if (consulta.includes('SELECT contrasena')) {
      return usuario ? [usuario] : [];
    }
    if (consulta.includes('DELETE FROM usuario')) {
      return usuario ? [{ id_usuario: valores[0] }] : [];
    }
    throw new Error('Consulta SQL inesperada.');
  });
  await app.register(eliminarUsuario);
  return { app, consultas };
}

test('elimina la cuenta al confirmar la contraseña y no devuelve el hash', async () => {
  const passwordHash = await hashPassword('clave segura');
  const { app, consultas } = await crearServidor({
    usuario: { contrasena: passwordHash }
  });

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: '/usuarios/12',
      payload: { contrasena: 'clave segura' }
    });

    assert.equal(response.statusCode, 200);
    assert.equal(response.json().success, true);
    assert.equal(JSON.stringify(response.json()).includes(passwordHash), false);
    assert.equal(consultas.length, 2);
    assert.match(consultas[1].consulta, /DELETE FROM usuario/);
    assert.equal(consultas[1].valores[0], '12');
    assert.equal(consultas[1].valores[1], passwordHash);
  } finally {
    await app.close();
  }
});

test('devuelve 404 si el usuario no existe', async () => {
  const { app, consultas } = await crearServidor();

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: '/usuarios/12',
      payload: { contrasena: 'clave segura' }
    });

    assert.equal(response.statusCode, 404);
    assert.equal(consultas.length, 1);
  } finally {
    await app.close();
  }
});

test('rechaza la contraseña incorrecta sin borrar la cuenta', async () => {
  const { app, consultas } = await crearServidor({
    usuario: { contrasena: await hashPassword('clave segura') }
  });

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: '/usuarios/12',
      payload: { contrasena: 'clave equivocada' }
    });

    assert.equal(response.statusCode, 401);
    assert.equal(consultas.length, 1);
  } finally {
    await app.close();
  }
});

test('rechaza ID o cuerpo inválidos antes de consultar la base', async () => {
  const { app, consultas } = await crearServidor();

  try {
    const responseId = await app.inject({
      method: 'DELETE',
      url: '/usuarios/abc',
      payload: { contrasena: 'clave segura' }
    });
    const responseBody = await app.inject({
      method: 'DELETE',
      url: '/usuarios/12',
      payload: {}
    });

    assert.equal(responseId.statusCode, 400);
    assert.equal(responseBody.statusCode, 400);
    assert.equal(consultas.length, 0);
  } finally {
    await app.close();
  }
});

test('devuelve 500 si ocurre un error de base de datos', async () => {
  const { app } = await crearServidor({ error: new Error('Database failure') });

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: '/usuarios/12',
      payload: { contrasena: 'clave segura' }
    });

    assert.equal(response.statusCode, 500);
  } finally {
    await app.close();
  }
});
