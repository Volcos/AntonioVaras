const obtenerEventoSchema = {
  params: {
    type: 'object',
    required: ['id'],
    properties: {
      id: { type: 'string', pattern: '^[1-9][0-9]*$', maxLength: 10 }
    },
    additionalProperties: false
  }
};

export default async function obtenerEventoPorId(fastify) {
  fastify.get('/eventos/:id', { schema: obtenerEventoSchema }, async (request, reply) => {
    try {
      const [evento] = await fastify.sql`
        SELECT
          e.*,
          c.nombre_comuna,
          te.nombre_tipo_evento,
          COALESCE(
            (
              SELECT jsonb_agg(
                jsonb_build_object(
                  'id_fecha', fe.id_fecha,
                  'fecha_inicio', fe.fecha_inicio,
                  'fecha_termino', fe.fecha_termino,
                  'precio_desde', fe.precio_desde
                )
                ORDER BY fe.fecha_inicio, fe.id_fecha
              )
              FROM fecha_evento fe
              WHERE fe.id_evento = e.id_evento
            ),
            '[]'::jsonb
          ) AS fechas,
          (
            SELECT ef.url_compra
            FROM evento_fuente ef
            JOIN fuente f ON f.id_fuente = ef.id_fuente
            WHERE ef.id_evento = e.id_evento
              AND LOWER(BTRIM(f.nombre_fuente)) = LOWER('PanoramAPP')
              AND ef.id_externo = CONCAT('manual-', e.id_evento)
            LIMIT 1
          ) AS url_pagina_compra
        FROM evento e
        JOIN comuna c ON c.id_comuna = e.id_comuna
        JOIN tipo_evento te ON te.id_tipo_evento = e.id_tipo_evento
        WHERE e.id_evento = ${request.params.id};
      `;

      if (!evento) {
        return reply.code(404).send({
          success: false,
          message: 'No se encontró un evento con ese ID.'
        });
      }

      return reply.code(200).send({
        success: true,
        data: evento
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({
        success: false,
        message: 'No se pudo obtener el evento.'
      });
    }
  });
}
