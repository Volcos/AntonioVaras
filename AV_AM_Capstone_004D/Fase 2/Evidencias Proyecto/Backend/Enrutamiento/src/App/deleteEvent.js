const eliminarEventoSchema = {
  params: {
    type: 'object',
    required: ['id'],
    properties: {
      id: { type: 'string', pattern: '^[1-9][0-9]*$', maxLength: 10 }
    },
    additionalProperties: false
  }
};

export default async function eliminarEvento(fastify) {
  fastify.delete('/eventos/:id', { schema: eliminarEventoSchema }, async (request, reply) => {
    try {
      const [eventoEliminado] = await fastify.sql`
        DELETE FROM evento
        WHERE id_evento = ${request.params.id}
        RETURNING id_evento, nombre;
      `;

      if (!eventoEliminado) {
        return reply.code(404).send({
          success: false,
          message: 'No se encontró un evento con ese ID.'
        });
      }

      return reply.code(200).send({
        success: true,
        message: 'El evento y sus registros relacionados fueron eliminados.',
        data: eventoEliminado
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({
        success: false,
        message: 'No se pudo eliminar el evento.'
      });
    }
  });
}
