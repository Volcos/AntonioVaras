const fechaDateTime = { type: 'string', format: 'date-time' };
const fechaEventoSchema = {
  type: 'object',
  required: ['fecha_inicio'],
  properties: {
    fecha_inicio: fechaDateTime,
    fecha_termino: {
      anyOf: [fechaDateTime, { type: 'null' }]
    },
    precio_desde: {
      anyOf: [
        { type: 'number', minimum: 0 },
        { type: 'null' }
      ]
    }
  },
  additionalProperties: false
};

const actualizarEventoSchema = {
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
        anyOf: [
          { type: 'string', format: 'uri' },
          { type: 'null' }
        ]
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
        items: fechaEventoSchema
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

function resolverReferencia(filas, columnaId) {
  if (filas.length !== 1) {
    return { id: null, duplicada: filas.length > 1 };
  }
  return { id: filas[0][columnaId], duplicada: false };
}

export default async function actualizarEvento(fastify) {
  fastify.put('/eventos/:id', { schema: actualizarEventoSchema }, async (request, reply) => {
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
      const comuna = resolverReferencia(comunas, 'id_comuna');
      const tipoEvento = resolverReferencia(tiposEvento, 'id_tipo_evento');

      if (comuna.duplicada || tipoEvento.duplicada) {
        fastify.log.error(
          { comuna: datos.comuna, tipo_evento: datos.tipo_evento },
          'Referencias duplicadas al actualizar evento'
        );
        return reply.code(500).send({
          success: false,
          message: 'No se pudo resolver la comuna o el tipo de evento.'
        });
      }

      if (!comuna.id || !tipoEvento.id) {
        const referenciasFaltantes = [
          !comuna.id && 'comuna',
          !tipoEvento.id && 'tipo de evento'
        ].filter(Boolean);
        return reply.code(400).send({
          success: false,
          message: `No existe ${referenciasFaltantes.join(' ni ')} en el sistema.`
        });
      }

      const [eventoActualizado] = await fastify.sql`
        WITH evento_actualizado AS (
          UPDATE evento
          SET
            nombre = ${datos.nombre.trim()},
            descripcion = ${datos.descripcion?.trim() || null},
            direccion = ${datos.direccion.trim()},
            imagen_url = ${datos.imagen_url || null},
            id_comuna = ${comuna.id},
            id_tipo_evento = ${tipoEvento.id},
            latitud = ${datos.latitud ?? null},
            longitud = ${datos.longitud ?? null},
            organizador = ${datos.organizador?.trim() || null}
          WHERE id_evento = ${request.params.id}
          RETURNING *
        ),
        fechas_eliminadas AS (
          DELETE FROM fecha_evento
          WHERE id_evento IN (SELECT id_evento FROM evento_actualizado)
          RETURNING id_fecha
        ),
        fechas_insertadas AS (
          INSERT INTO fecha_evento (
            id_evento,
            fecha_inicio,
            fecha_termino,
            precio_desde
          )
          SELECT
            evento_actualizado.id_evento,
            fecha.fecha_inicio,
            fecha.fecha_termino,
            fecha.precio_desde
          FROM evento_actualizado
          CROSS JOIN jsonb_to_recordset(${JSON.stringify(datos.fechas)}::jsonb) AS fecha(
            fecha_inicio timestamptz,
            fecha_termino timestamptz,
            precio_desde numeric
          )
          RETURNING id_fecha, id_evento, fecha_inicio, fecha_termino, precio_desde
        ),
        fuente_manual_insertada AS (
          INSERT INTO fuente (nombre_fuente)
          SELECT 'PanoramAPP'
          WHERE ${Boolean(datos.url_pagina_compra)}
            AND EXISTS (SELECT 1 FROM evento_actualizado)
            AND NOT EXISTS (
              SELECT 1 FROM fuente
              WHERE LOWER(nombre_fuente) = LOWER('PanoramAPP')
            )
          RETURNING id_fuente
        ),
        fuente_resuelta AS (
          SELECT id_fuente FROM fuente_manual_insertada
          UNION ALL
          SELECT id_fuente FROM fuente
          WHERE LOWER(nombre_fuente) = LOWER('PanoramAPP')
            AND NOT EXISTS (SELECT 1 FROM fuente_manual_insertada)
          LIMIT 1
        ),
        fuente_anterior_actualizada AS (
          UPDATE evento_fuente ef
          SET
            id_externo = ${`manual-${request.params.id}`},
            url_compra = ${datos.url_pagina_compra?.trim() || null}
          FROM fuente f, evento_actualizado e
          WHERE ef.id_evento = e.id_evento
            AND ef.id_fuente = f.id_fuente
            AND LOWER(f.nombre_fuente) = LOWER('PanoramAPP')
            AND ${Boolean(datos.url_pagina_compra)}
          RETURNING ef.id_evento
        ),
        fuente_anterior_eliminada AS (
          DELETE FROM evento_fuente ef
          USING fuente f, evento_actualizado e
          WHERE ef.id_evento = e.id_evento
            AND ef.id_fuente = f.id_fuente
            AND LOWER(f.nombre_fuente) = LOWER('PanoramAPP')
            AND NOT ${Boolean(datos.url_pagina_compra)}
          RETURNING ef.id_evento
        ),
        fuente_agregada AS (
          INSERT INTO evento_fuente (id_evento, id_fuente, id_externo, url_compra)
          SELECT
            e.id_evento,
            f.id_fuente,
            ${`manual-${request.params.id}`},
            ${datos.url_pagina_compra?.trim() || null}
          FROM evento_actualizado e
          CROSS JOIN fuente_resuelta f
          WHERE ${Boolean(datos.url_pagina_compra)}
            AND NOT EXISTS (SELECT 1 FROM fuente_anterior_actualizada)
          RETURNING id_evento
        )
        SELECT
          evento_actualizado.*,
          (
            SELECT jsonb_agg(
              jsonb_build_object(
                'id_fecha', fechas_insertadas.id_fecha,
                'fecha_inicio', fechas_insertadas.fecha_inicio,
                'fecha_termino', fechas_insertadas.fecha_termino,
                'precio_desde', fechas_insertadas.precio_desde
              )
              ORDER BY fechas_insertadas.fecha_inicio, fechas_insertadas.id_fecha
            )
            FROM fechas_insertadas
            WHERE fechas_insertadas.id_evento = evento_actualizado.id_evento
          ) AS fechas,
          ${comunas[0].nombre_comuna} AS nombre_comuna,
          ${tiposEvento[0].nombre_tipo_evento} AS nombre_tipo_evento
        FROM evento_actualizado;
      `;

      if (!eventoActualizado) {
        return reply.code(404).send({
          success: false,
          message: 'No se encontró un evento con ese ID.'
        });
      }

      return reply.code(200).send({
        success: true,
        data: eventoActualizado
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
