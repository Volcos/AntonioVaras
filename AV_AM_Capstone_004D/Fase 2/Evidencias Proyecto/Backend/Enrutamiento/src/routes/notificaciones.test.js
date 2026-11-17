import assert from 'node:assert/strict';
import Fastify from 'fastify';
import fastifyJwt from '@fastify/jwt';
import { test } from 'node:test';
import rutasNotificaciones from './notificaciones.js';

async function crearServidor({ consultar } = {}) {
    const consultas = [];
    const app = Fastify();
    app.decorate('sql', async (strings, ...valores) => {
        const consulta = strings.join('?');
        consultas.push({ consulta, valores });
        return consultar ? consultar(consulta, valores) : [];
    });
    await app.register(fastifyJwt, { secret: 'test-secret' });
    app.decorate('authenticate', async function (request, reply) {
        try {
            await request.jwtVerify();
        } catch (error) {
            return reply.code(401).send({
                success: false,
                message: 'Sesión inválida o expirada. Inicia sesión nuevamente.'
            });
        }
    });
    await app.register(rutasNotificaciones);

    return {
        app,
        consultas,
        authorization: `Bearer ${app.jwt.sign({ id_usuario: 17 })}`
    };
}

test('registra dispositivos autenticados y exige un token FCM', async () => {
    const { app, consultas, authorization } = await crearServidor();

    try {
        const sinToken = await app.inject({
            method: 'POST',
            url: '/usuarios/dispositivo',
            headers: { authorization },
            payload: { plataforma: 'ios' }
        });
        const registro = await app.inject({
            method: 'POST',
            url: '/usuarios/dispositivo',
            headers: { authorization },
            payload: { fcm_token: 'token-fcm', plataforma: 'ios' }
        });

        assert.equal(sinToken.statusCode, 400);
        assert.equal(registro.statusCode, 200);
        assert.deepEqual(registro.json(), {
            success: true,
            message: 'Dispositivo registrado.'
        });
        assert.match(consultas[0].consulta, /ON CONFLICT \(fcm_token\) DO UPDATE/);
        assert.deepEqual(consultas[0].valores, [17, 'token-fcm', 'ios']);
    } finally {
        await app.close();
    }
});

test('programa el recordatorio a las 10:00 si el evento comienza a medianoche', async () => {
    const fechaInicio = new Date(2026, 2, 20, 0, 0, 0, 0);
    const fechaNotificacionEsperada = new Date(fechaInicio);
    fechaNotificacionEsperada.setHours(10, 0, 0, 0);
    const { app, consultas, authorization } = await crearServidor({
        consultar: (consulta) => consulta.includes('SELECT id_fecha, fecha_inicio')
            ? [{ id_fecha: 29, fecha_inicio: fechaInicio }]
            : []
    });

    try {
        const response = await app.inject({
            method: 'POST',
            url: '/fechas/29/recordatorio',
            headers: { authorization },
            payload: {}
        });

        assert.equal(response.statusCode, 200);
        assert.deepEqual(response.json(), {
            success: true,
            message: 'Recordatorio programado.',
            fecha_notificacion: fechaNotificacionEsperada.toISOString()
        });
        assert.match(consultas[1].consulta, /ON CONFLICT \(id_usuario, id_fecha\) DO UPDATE/);
        assert.equal(consultas[1].valores[0], 17);
        assert.equal(consultas[1].valores[1], '29');
        assert.equal(consultas[1].valores[2].getTime(), fechaNotificacionEsperada.getTime());
    } finally {
        await app.close();
    }
});

test('rechaza solicitudes no autenticadas y protege el worker con la clave cron', async () => {
    const cronSecretOriginal = process.env.CRON_SECRET;
    process.env.CRON_SECRET = 'test-cron-secret';
    const { app, consultas } = await crearServidor();

    try {
        const sinSesion = await app.inject({
            method: 'DELETE',
            url: '/usuarios/dispositivo',
            payload: { fcm_token: 'token-fcm' }
        });
        const sinClaveCron = await app.inject({
            method: 'POST',
            url: '/tasks/notificaciones',
            headers: { 'x-cron-key': 'incorrecta' }
        });

        assert.equal(sinSesion.statusCode, 401);
        assert.equal(sinClaveCron.statusCode, 401);
        assert.equal(consultas.length, 0);
    } finally {
        if (cronSecretOriginal === undefined) {
            delete process.env.CRON_SECRET;
        } else {
            process.env.CRON_SECRET = cronSecretOriginal;
        }
        await app.close();
    }
});
