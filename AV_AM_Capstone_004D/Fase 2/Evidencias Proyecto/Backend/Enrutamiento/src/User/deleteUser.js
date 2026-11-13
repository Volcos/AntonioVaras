import { verifyPassword } from './passwordUtils.js';

const eliminarUsuarioSchema = {
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
    required: ['contrasena'],
    properties: {
      contrasena: { type: 'string', minLength: 6, maxLength: 100 }
    },
    additionalProperties: false
  }
};

export default async function eliminarUsuario(fastify) {
  fastify.delete('/usuarios/:id', { schema: eliminarUsuarioSchema }, async (request, reply) => {
    try {
      const [usuario] = await fastify.sql`
        SELECT contrasena
        FROM usuario
        WHERE id_usuario = ${request.params.id};
      `;

      if (!usuario) {
        return reply.code(404).send({
          success: false,
          message: 'No se encontró un usuario con ese ID.'
        });
      }

      if (!await verifyPassword(request.body.contrasena, usuario.contrasena)) {
        return reply.code(401).send({
          success: false,
          message: 'La contraseña es incorrecta.'
        });
      }

      const [usuarioEliminado] = await fastify.sql`
        DELETE FROM usuario
        WHERE id_usuario = ${request.params.id}
          AND contrasena = ${usuario.contrasena}
        RETURNING id_usuario;
      `;

      if (!usuarioEliminado) {
        return reply.code(404).send({
          success: false,
          message: 'No se encontró el usuario o sus credenciales cambiaron.'
        });
      }

      return reply.code(200).send({
        success: true,
        message: 'La cuenta y sus registros de interés fueron eliminados.'
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({
        success: false,
        message: 'No se pudo eliminar el usuario.'
      });
    }
  });
}
