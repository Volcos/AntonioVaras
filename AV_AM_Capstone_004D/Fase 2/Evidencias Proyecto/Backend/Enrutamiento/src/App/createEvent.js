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

const crearEventoSchema = {
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
  if (filas.length === 0) {
    return { id: null, duplicada: false };
  }
  if (filas.length > 1) {
    return { id: null, duplicada: true };
  }
  return { id: filas[0][columnaId], duplicada: false };
}

export default async function crearEvento(fastify) {
  fastify.post('/eventos', { schema: crearEventoSchema }, async (request, reply) => {
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
          'Referencias duplicadas al crear evento'
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

      const [eventoNuevo] = await fastify.sql`
        WITH evento_insertado AS (
          INSERT INTO evento (
            nombre,
            descripcion,
            direccion,
            imagen_url,
            id_comuna,
            id_tipo_evento,
            latitud,
            longitud,
            organizador
          ) VALUES (
            ${datos.nombre.trim()},
            ${datos.descripcion?.trim() || null},
            ${datos.direccion.trim()},
            ${datos.imagen_url || null},
            ${comuna.id},
            ${tipoEvento.id},
            ${datos.latitud ?? null},
            ${datos.longitud ?? null},
            ${datos.organizador?.trim() || null}
          )
          RETURNING *
        ),
        fecha_insertada AS (
          INSERT INTO fecha_evento (
            id_evento,
            fecha_inicio,
            fecha_termino,
            precio_desde
          )
          SELECT
            evento_insertado.id_evento,
            fecha.fecha_inicio,
            fecha.fecha_termino,
            fecha.precio_desde
          FROM evento_insertado
          CROSS JOIN jsonb_to_recordset(${JSON.stringify(datos.fechas)}::jsonb) AS fecha(
            fecha_inicio timestamptz,
            fecha_termino timestamptz,
            precio_desde numeric
          )
          RETURNING id_fecha, id_evento, fecha_inicio, fecha_termino, precio_desde
        )
        SELECT
          evento_insertado.*,
          (
            SELECT jsonb_agg(
              jsonb_build_object(
                'id_fecha', fecha_insertada.id_fecha,
                'fecha_inicio', fecha_insertada.fecha_inicio,
                'fecha_termino', fecha_insertada.fecha_termino,
                'precio_desde', fecha_insertada.precio_desde
              )
              ORDER BY fecha_insertada.fecha_inicio, fecha_insertada.id_fecha
            )
            FROM fecha_insertada
            WHERE fecha_insertada.id_evento = evento_insertado.id_evento
          ) AS fechas,
          ${comunas[0].nombre_comuna} AS nombre_comuna,
          ${tiposEvento[0].nombre_tipo_evento} AS nombre_tipo_evento
        FROM evento_insertado
      `;

      if (!eventoNuevo) {
        throw new Error('La inserción del evento no devolvió el registro creado.');
      }

      if (datos.url_pagina_compra) {
        await fastify.sql`
          WITH fuente_manual AS (
            INSERT INTO fuente (nombre_fuente)
            SELECT 'PanoramAPP'
            WHERE NOT EXISTS (
              SELECT 1 FROM fuente
              WHERE LOWER(nombre_fuente) = LOWER('PanoramAPP')
            )
            RETURNING id_fuente
          ),
          fuente_resuelta AS (
            SELECT id_fuente FROM fuente_manual
            UNION ALL
            SELECT id_fuente FROM fuente
            WHERE LOWER(nombre_fuente) = LOWER('PanoramAPP')
              AND NOT EXISTS (SELECT 1 FROM fuente_manual)
            LIMIT 1
          )
          INSERT INTO evento_fuente (id_evento, id_fuente, id_externo, url_compra)
          SELECT
            ${eventoNuevo.id_evento},
            id_fuente,
            ${`manual-${eventoNuevo.id_evento}`},
            ${datos.url_pagina_compra.trim()}
          FROM fuente_resuelta;
        `;
      }

      return reply.code(201).send({
        success: true,
        data: eventoNuevo
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({
        success: false,
        message: 'No se pudo registrar el evento.'
      });
    }
  });
}
