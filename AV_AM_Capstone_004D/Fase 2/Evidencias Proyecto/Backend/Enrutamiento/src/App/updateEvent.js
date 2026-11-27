const dateTime = { type: 'string', format: 'date-time' };
const eventSchema = {
  params: {
    type: 'object',
    required: ['id'],
    properties: {
      id: { type: 'string', pattern: '^[1-9][0-9]*$', maxLength: 10 }
    },
    additionalProperties: false
  },
  body: {
    type: 'object',
    required: ['nombre', 'direccion', 'comuna', 'tipo_evento', 'fechas'],
    properties: {
      nombre: { type: 'string', minLength: 3, maxLength: 150 },
      descripcion: { type: ['string', 'null'], maxLength: 1000 },
      direccion: { type: 'string', minLength: 5, maxLength: 200 },
      imagen_url: {
        anyOf: [{ type: 'string', format: 'uri' }, { type: 'null' }]
      },
      url_pagina_compra: {
        anyOf: [
          { type: 'string', format: 'uri', maxLength: 300 },
          { type: 'null' }
        ]
      },
      comuna: { type: 'string', minLength: 1, maxLength: 100 },
      tipo_evento: { type: 'string', minLength: 1, maxLength: 100 },
      fechas: {
        type: 'array',
        minItems: 1,
        items: {
          type: 'object',
          required: ['fecha_inicio'],
          properties: {
            id_fecha: {
              anyOf: [{ type: 'integer', minimum: 1 }, { type: 'null' }]
            },
            fecha_inicio: dateTime,
            fecha_termino: {
              anyOf: [dateTime, { type: 'null' }]
            },
            precio_desde: {
              anyOf: [
                { type: 'number', minimum: 0 },
                { type: 'null' }
              ]
            }
          },
          additionalProperties: false
        }
      },
      latitud: {
        anyOf: [
          { type: 'number', minimum: -90, maximum: 90 },
          { type: 'null' }
        ]
      },
      longitud: {
        anyOf: [
          { type: 'number', minimum: -180, maximum: 180 },
          { type: 'null' }
        ]
      },
      organizador: { type: ['string', 'null'], maxLength: 150 }
    },
    additionalProperties: false
  }
};

export default async function actualizarEvento(fastify) {
  fastify.put('/eventos/:id', { schema: eventSchema }, async (request, reply) => {
    const { id } = request.params;
    const datos = request.body;

    try {
      const [comunas, tiposEvento] = await Promise.all([
        fastify.sql`
          SELECT id_comuna, nombre_comuna
          FROM comuna
          WHERE LOWER(BTRIM(nombre_comuna)) = LOWER(BTRIM(${datos.comuna.trim()}));
        `,
        fastify.sql`
          SELECT id_tipo_evento, nombre_tipo_evento
          FROM tipo_evento
          WHERE LOWER(BTRIM(nombre_tipo_evento)) = LOWER(BTRIM(${datos.tipo_evento.trim()}));
        `
      ]);

      if (!comunas.length || !tiposEvento.length) {
        const missing = [
          !comunas.length && 'comuna',
          !tiposEvento.length && 'tipo de evento'
        ].filter(Boolean);
        return reply.code(400).send({
          success: false,
          message: `No existe ${missing.join(' ni ')} en el sistema.`
        });
      }

      const fechasActuales = await fastify.sql`
        SELECT id_fecha
        FROM fecha_evento
        WHERE id_evento = ${id};
      `;
      const currentDateIds = new Set(
        fechasActuales.map((fecha) => Number(fecha.id_fecha))
      );
      const submittedDateIds = datos.fechas
        .map((fecha) => fecha.id_fecha)
        .filter((dateId) => dateId != null);

      if (
        submittedDateIds.some((dateId) => !currentDateIds.has(dateId)) ||
        new Set(submittedDateIds).size !== submittedDateIds.length
      ) {
        return reply.code(400).send({
          success: false,
          message: 'Las fechas enviadas no pertenecen a este evento.'
        });
      }

      const datesJson = JSON.stringify(datos.fechas);
      const results = await fastify.sql.transaction([
        fastify.sql`
          UPDATE evento
          SET nombre = ${datos.nombre.trim()},
              descripcion = ${datos.descripcion?.trim() || null},
              direccion = ${datos.direccion.trim()},
              imagen_url = ${datos.imagen_url || null},
              id_comuna = ${comunas[0].id_comuna},
              id_tipo_evento = ${tiposEvento[0].id_tipo_evento},
              latitud = ${datos.latitud ?? null},
              longitud = ${datos.longitud ?? null},
              organizador = ${datos.organizador?.trim() || null}
          WHERE id_evento = ${id}
          RETURNING id_evento;
        `,
        fastify.sql`
          UPDATE fecha_evento AS existente
          SET fecha_inicio = solicitada.fecha_inicio,
              fecha_termino = solicitada.fecha_termino,
              precio_desde = solicitada.precio_desde
          FROM jsonb_to_recordset(${datesJson}::jsonb) AS solicitada(
            id_fecha bigint,
            fecha_inicio timestamptz,
            fecha_termino timestamptz,
            precio_desde numeric
          )
          WHERE existente.id_evento = ${id}
            AND existente.id_fecha = solicitada.id_fecha;
        `,
        fastify.sql`
          DELETE FROM fecha_evento
          WHERE id_evento = ${id}
            AND NOT EXISTS (
              SELECT 1
              FROM jsonb_to_recordset(${datesJson}::jsonb) AS solicitada(
                id_fecha bigint,
                fecha_inicio timestamptz,
                fecha_termino timestamptz,
                precio_desde numeric
              )
              WHERE solicitada.id_fecha = fecha_evento.id_fecha
            );
        `,
        fastify.sql`
          INSERT INTO fecha_evento (
            id_evento, fecha_inicio, fecha_termino, precio_desde
          )
          SELECT ${id},
                 solicitada.fecha_inicio,
                 solicitada.fecha_termino,
                 solicitada.precio_desde
          FROM jsonb_to_recordset(${datesJson}::jsonb) AS solicitada(
            id_fecha bigint,
            fecha_inicio timestamptz,
            fecha_termino timestamptz,
            precio_desde numeric
          )
          WHERE solicitada.id_fecha IS NULL;
        `,
        fastify.sql`
          UPDATE evento_fuente
          SET url_compra = ${datos.url_pagina_compra?.trim() || null}
          WHERE id_evento = ${id}
            AND id_fuente = (
              SELECT id_fuente
              FROM fuente
              WHERE LOWER(nombre_fuente) = LOWER('PanoramAPP')
              LIMIT 1
            );
        `,
        fastify.sql`
          SELECT evento.*,
                 comuna.nombre_comuna,
                 tipo_evento.nombre_tipo_evento,
                 COALESCE(
                   (
                     SELECT jsonb_agg(
                       jsonb_build_object(
                         'id_fecha', fecha.id_fecha,
                         'fecha_inicio', fecha.fecha_inicio,
                         'fecha_termino', fecha.fecha_termino,
                         'precio_desde', fecha.precio_desde
                       )
                       ORDER BY fecha.fecha_inicio, fecha.id_fecha
                     )
                     FROM fecha_evento AS fecha
                     WHERE fecha.id_evento = evento.id_evento
                   ),
                   '[]'::jsonb
                 ) AS fechas,
                 (
                   SELECT evento_fuente.url_compra
                   FROM evento_fuente
                   JOIN fuente USING (id_fuente)
                   WHERE evento_fuente.id_evento = evento.id_evento
                     AND LOWER(fuente.nombre_fuente) = LOWER('PanoramAPP')
                   LIMIT 1
                 ) AS url_pagina_compra
          FROM evento
          JOIN comuna USING (id_comuna)
          JOIN tipo_evento USING (id_tipo_evento)
          WHERE evento.id_evento = ${id};
        `
      ]);

      if (!results[0]?.length) {
        return reply.code(404).send({
          success: false,
          message: 'No se encontró un evento con ese ID.'
        });
      }
      if (!results[5]?.length) {
        throw new Error('La actualización no devolvió el evento actualizado.');
      }

      return reply.code(200).send({
        success: true,
        data: results[5][0]
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({
        success: false,
        message: 'No se pudo actualizar el evento.'
      });
    }
  });
}
