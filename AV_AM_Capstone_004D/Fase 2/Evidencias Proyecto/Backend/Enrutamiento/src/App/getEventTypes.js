export default async function tiposEvento(fastify) {
  fastify.get('/tipos-evento', async (request, reply) => {
    try {
      return await fastify.sql`
        SELECT id_tipo_evento, nombre_tipo_evento
        FROM tipo_evento
        ORDER BY LOWER(nombre_tipo_evento) ASC;
      `;
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({
        success: false,
        message: 'No se pudieron obtener los tipos de evento.'
      });
    }
  });
}
