import assert from 'node:assert/strict';
import Fastify from 'fastify';
import { test } from 'node:test';
import crearUsuario from './createUser.js';
import logUser from './logUser.js';
import { hashPassword, verifyPassword } from './passwordUtils.js';

const datosUsuario = {
  nombre: 'Ana Ejemplo',
  rut: '12345678-9',
  email: 'ana@example.com',
  contrasena: 'clave segura',
  tipo_usuario: 'participante'
};

test('almacena un hash y no devuelve la contraseña al crear el usuario', async () => {
  const consultas = [];
  const app = Fastify();
  app.decorate('sql', async (strings, ...valores) => {
    consultas.push({ consulta: strings.join('?'), valores });
    if (strings.join('').includes('FROM tipo_usuario')) {
      return [{ id_tipo_usuario: 2, nombre_tipo_usuario: 'participante' }];
    }
    return [{
      id_usuario: 1,
      nombre_usuario: valores[0],
      rut: valores[1],
      email: valores[2],
      contrasena: valores[3],
      id_tipo_usuario: valores[4]
    }];
  });
  await app.register(crearUsuario);

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/usuarios',
      payload: datosUsuario
    });
    const consultaInsercion = consultas.find(({ consulta }) => consulta.includes('INSERT INTO usuario'));
    const hashAlmacenado = consultaInsercion.valores[3];

    assert.equal(response.statusCode, 201);
    assert.notEqual(hashAlmacenado, datosUsuario.contrasena);
    assert.equal(await verifyPassword(datosUsuario.contrasena, hashAlmacenado), true);
    assert.equal('contrasena' in response.json().data, false);
    assert.match(consultaInsercion.consulta, /nombre_usuario,\s*rut,\s*email,\s*contrasena,\s*id_tipo_usuario/);
    assert.equal(consultaInsercion.valores[4], 2);
    assert.ok(consultas.some(({ consulta }) => consulta.includes('FROM tipo_usuario')));
  } finally {
    await app.close();
  }
});

test('valida los campos obligatorios antes de consultar la base', async () => {
  let consultas = 0;
  const app = Fastify();
  app.decorate('sql', async () => {
    consultas += 1;
    return [];
  });
  await app.register(crearUsuario);

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/usuarios',
      payload: { nombre: datosUsuario.nombre }
    });

    test('rechaza un tipo de usuario que no existe', async () => {
      const consultas = [];
      const app = Fastify();
      app.decorate('sql', async (strings, ...valores) => {
        consultas.push({ consulta: strings.join('?'), valores });
        return [];
      });
      await app.register(crearUsuario);

      try {
        const response = await app.inject({
          method: 'POST',
          url: '/usuarios',
          payload: datosUsuario
        });

        assert.equal(response.statusCode, 400);
        assert.equal(consultas.length, 1);
        assert.equal(consultas[0].consulta.includes('INSERT INTO usuario'), false);
      } finally {
        await app.close();
      }
    });

    assert.equal(response.statusCode, 400);
    assert.equal(consultas, 0);
  } finally {
    await app.close();
  }
});

test('autentica contra el hash y no devuelve el hash al usuario', async () => {
  const storedPassword = await hashPassword(datosUsuario.contrasena);
  const app = Fastify();
  app.decorate('sql', async () => [{
    id_usuario: 1,
    nombre_usuario: datosUsuario.nombre,
    email: datosUsuario.email,
    contrasena: storedPassword,
    tipo_usuario: datosUsuario.tipo_usuario
  }]);
  await app.register(logUser);

  try {
    const responseCorrecta = await app.inject({
      method: 'POST',
      url: '/login',
      payload: {
        nombre: datosUsuario.nombre,
        contrasena: datosUsuario.contrasena
      }
    });
    const responseIncorrecta = await app.inject({
      method: 'POST',
      url: '/login',
      payload: {
        nombre: datosUsuario.nombre,
        contrasena: 'otra contraseña'
      }
    });

    assert.equal(responseCorrecta.statusCode, 200);
    assert.equal('contrasena' in responseCorrecta.json().data, false);
    assert.equal(responseIncorrecta.statusCode, 401);
  } finally {
    await app.close();
  }
});

test('rechaza hashes no válidos y mantiene espacios significativos en la contraseña', async () => {
  const password = ' clave segura ';
  const storedHash = await hashPassword(password);

  assert.equal(await verifyPassword(password, storedHash), true);
  assert.equal(await verifyPassword(password.trim(), storedHash), false);
  assert.equal(await verifyPassword(password, 'contraseña en texto plano'), false);
  assert.equal(await verifyPassword(password, null), false);
});
