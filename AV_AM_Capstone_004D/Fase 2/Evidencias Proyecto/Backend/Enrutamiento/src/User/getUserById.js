const obtenerUsuarioSchema = {
  params: {
    type: 'object',
    required: ['id'],
    properties: {
      id: { type: 'string', pattern: '^[1-9][0-9]*$', maxLength: 10 }
    },
    additionalProperties: false
  }
};

export default async function obtenerUsuarioPorId(fastify) {
  fastify.get('/usuarios/:id', { schema: obtenerUsuarioSchema }, async (request, reply) => {
    try {
      const [usuario] = await fastify.sql`
        SELECT id_usuario, nombre_usuario, rut, email, id_tipo_usuario
        FROM usuario
        WHERE id_usuario = ${request.params.id};
      `;

      if (!usuario) {
        return reply.code(404).send({
          success: false,
          message: 'No se encontró un usuario con ese ID.'
        });
      }

      return reply.code(200).send({
        success: true,
        data: usuario
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({
        success: false,
        message: 'No se pudo obtener el usuario.'
      });
    }
  });
}
