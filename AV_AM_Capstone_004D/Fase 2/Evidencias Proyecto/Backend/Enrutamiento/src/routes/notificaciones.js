import { initializeApp, getApps, applicationDefault } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

function inicializarFirebase() {
  if (getApps().length === 0) {
    initializeApp({
      credential: applicationDefault()
    });
  }
}
export default async function rutasNotificaciones(fastify) {
    fastify.post('/usuarios/dispositivo', {
        onRequest: [fastify.authenticate]
    }, async (request, reply) => {
        const { fcm_token, plataforma } = request.body || {};
        if (typeof fcm_token !== 'string' || !fcm_token.trim()) {
            return reply.code(400).send({
                success: false,
                message: 'El token FCM es obligatorio.'
            });
        }

        try {
            await fastify.sql`
                INSERT INTO public.usuario_dispositivo (id_usuario, fcm_token, plataforma)
                VALUES (${request.user.id_usuario}, ${fcm_token.trim()}, ${plataforma ?? null})
                ON CONFLICT (fcm_token) DO UPDATE
                SET id_usuario = EXCLUDED.id_usuario,
                    plataforma = COALESCE(EXCLUDED.plataforma, public.usuario_dispositivo.plataforma),
                    actualizado_en = CURRENT_TIMESTAMP;
            `;

            return reply.code(200).send({
                success: true,
                message: 'Dispositivo registrado.'
            });
        } catch (error) {
            fastify.log.error(error);
            return reply.code(500).send({
                success: false,
                message: 'No se pudo registrar el dispositivo.'
            });
        }
    });

    fastify.delete('/usuarios/dispositivo', {
        onRequest: [fastify.authenticate]
    }, async (request, reply) => {
        const { fcm_token } = request.body || {};

        try {
            if (fcm_token) {
                await fastify.sql`
                    DELETE FROM public.usuario_dispositivo
                    WHERE id_usuario = ${request.user.id_usuario}
                      AND fcm_token = ${fcm_token};
                `;
            }

            return reply.code(200).send({
                success: true,
                message: 'Dispositivo desvinculado.'
            });
        } catch (error) {
            fastify.log.error(error);
            return reply.code(500).send({
                success: false,
                message: 'No se pudo desvincular el dispositivo.'
            });
        }
    });

    fastify.post('/fechas/:id_fecha/recordatorio', {
        onRequest: [fastify.authenticate]
    }, async (request, reply) => {
        const { id_usuario } = request.user;
        const { id_fecha } = request.params;
        const { activar = true, horas_antes = 24 } = request.body || {};

        if (typeof activar !== 'boolean') {
            return reply.code(400).send({
                success: false,
                message: 'El estado del recordatorio debe ser booleano.'
            });
        }

        if (activar && (typeof horas_antes !== 'number' || !Number.isFinite(horas_antes) || horas_antes < 0)) {
            return reply.code(400).send({
                success: false,
                message: 'Las horas de anticipación deben ser un número no negativo.'
            });
        }

        try {
            const [fechaEvento] = await fastify.sql`
                SELECT id_fecha, fecha_inicio
                FROM public.fecha_evento
                WHERE id_fecha = ${id_fecha};
            `;

            if (!fechaEvento) {
                return reply.code(404).send({
                    success: false,
                    message: 'Fecha de evento no encontrada.'
                });
            }

            if (!activar) {
                await fastify.sql`
                    UPDATE public.registro_interes
                    SET recordatorio = FALSE,
                        fecha_notificacion = NULL
                    WHERE id_usuario = ${id_usuario}
                      AND id_fecha = ${id_fecha};
                `;

                return reply.code(200).send({
                    success: true,
                    message: 'Recordatorio desactivado.'
                });
            }

            const fechaInicio = new Date(fechaEvento.fecha_inicio);
            if (!Number.isFinite(fechaInicio.getTime())) {
                throw new Error('La fecha de inicio del evento no es válida.');
            }

            const fechaNotificacion = new Date(fechaInicio);
            if (fechaInicio.getHours() === 0 && fechaInicio.getMinutes() === 0) {
                fechaNotificacion.setHours(10, 0, 0, 0);
            } else {
                fechaNotificacion.setTime(fechaInicio.getTime() - horas_antes * 60 * 60 * 1000);
            }

            await fastify.sql`
                INSERT INTO public.registro_interes (
                    id_usuario,
                    id_fecha,
                    recordatorio,
                    fecha_notificacion,
                    recordatorio_enviado
                ) VALUES (
                    ${id_usuario},
                    ${id_fecha},
                    TRUE,
                    ${fechaNotificacion},
                    FALSE
                )
                ON CONFLICT (id_usuario, id_fecha) DO UPDATE
                SET recordatorio = TRUE,
                    fecha_notificacion = EXCLUDED.fecha_notificacion,
                    recordatorio_enviado = FALSE;
            `;

            return reply.code(200).send({
                success: true,
                message: 'Recordatorio programado.',
                fecha_notificacion: fechaNotificacion
            });
        } catch (error) {
            fastify.log.error(error);
            return reply.code(500).send({
                success: false,
                message: 'No se pudo actualizar el recordatorio.'
            });
        }
    });

    fastify.post('/tasks/notificaciones', async (request, reply) => {
        if (!process.env.CRON_SECRET || request.headers['x-cron-key'] !== process.env.CRON_SECRET) {
            return reply.code(401).send({
                success: false,
                message: 'No autorizado.'
            });
        }

        let procesados = 0;
        let enviados = 0;

        try {
            inicializarFirebase();
            const pendientes = await fastify.sql`
                SELECT
                    ri.id_registro,
                    ud.fcm_token,
                    e.id_evento,
                    e.nombre AS nombre_evento,
                    e.direccion
                FROM public.registro_interes ri
                INNER JOIN public.fecha_evento fe ON fe.id_fecha = ri.id_fecha
                INNER JOIN public.evento e ON e.id_evento = fe.id_evento
                INNER JOIN public.usuario_dispositivo ud ON ud.id_usuario = ri.id_usuario
                WHERE ri.recordatorio = TRUE
                  AND ri.recordatorio_enviado = FALSE
                  AND ri.fecha_notificacion <= CURRENT_TIMESTAMP
                ORDER BY ri.fecha_notificacion, ri.id_registro
                LIMIT 100;
            `;

            for (const pendiente of pendientes) {
                procesados += 1;
                try {
                    inicializarFirebase();
                    await getMessaging().send({
                        token: item.fcm_token,
                        notification: {
                            title: '¡Tu evento está por comenzar!',
                            body: `${item.nombre_evento} en ${item.direccion}`
                        },
                        data: {
                            id_evento: String(item.id_evento),
                            tipo: 'RECORDATORIO_EVENTO'
                        }
                    });
                    enviados += 1;

                    await fastify.sql`
                        UPDATE public.registro_interes
                        SET recordatorio_enviado = TRUE
                        WHERE id_registro = ${pendiente.id_registro};
                    `;
                } catch (error) {
                    fastify.log.error({ err: error, id_registro: pendiente.id_registro });
                    if (error.code === 'messaging/registration-token-not-registered') {
                        try {
                            await fastify.sql`
                                DELETE FROM public.usuario_dispositivo
                                WHERE fcm_token = ${pendiente.fcm_token};
                            `;
                        } catch (deleteError) {
                            fastify.log.error(deleteError);
                        }
                    }
                }
            }

            return reply.code(200).send({
                success: true,
                procesados,
                enviados
            });
        } catch (error) {
            fastify.log.error(error);
            return reply.code(500).send({
                success: false,
                message: 'No se pudieron procesar las notificaciones.'
            });
        }
    });
}
