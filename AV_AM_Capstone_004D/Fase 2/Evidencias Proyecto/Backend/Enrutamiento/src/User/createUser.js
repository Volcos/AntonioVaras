import { hashPassword } from './passwordUtils.js';

const crearUsuarioSchema = {
    body: {
        type: 'object',
        required: ['nombre', 'rut', 'email', 'contrasena', 'tipo_usuario'],
        properties: {
            nombre: { type: 'string', minLength: 3, maxLength: 150 },
            rut: { type: 'string', minLength: 9, maxLength: 10 },
            email: { type: 'string', format: 'email' },
            contrasena: { type: 'string', minLength: 6, maxLength: 100 },
            tipo_usuario: { type: 'string', enum: ['organizador', 'participante'] }
        },
        additionalProperties: false
    }
};

export default async function crearUsuario(fastify) {
  fastify.post('/usuarios', { schema: crearUsuarioSchema }, async (request, reply) => {
    try {
      const datos = request.body;
      const tiposUsuario = await fastify.sql`
        SELECT id_tipo_usuario, nombre_tipo_usuario
        FROM tipo_usuario
        WHERE LOWER(BTRIM(nombre_tipo_usuario)) = LOWER(BTRIM(${datos.tipo_usuario.trim()}));
      `;

      if (tiposUsuario.length === 0) {
        return reply.code(400).send({
          success: false,
          message: 'El tipo de usuario proporcionado no existe.'
        });
      }

      if (tiposUsuario.length > 1) {
        fastify.log.error(
          { tipo_usuario: datos.tipo_usuario },
          'Tipo de usuario duplicado al crear cuenta'
        );
        return reply.code(500).send({
          success: false,
          message: 'No se pudo resolver el tipo de usuario.'
        });
      }

      const contrasenaHash = await hashPassword(datos.contrasena);

      const [usuarioNuevo] = await fastify.sql`
        INSERT INTO usuario (
          nombre_usuario,
          rut,
          email,
          contrasena,
          id_tipo_usuario
        ) VALUES (
          ${datos.nombre.trim()},
          ${datos.rut.trim()},
          ${datos.email.trim()},
          ${contrasenaHash},
          ${tiposUsuario[0].id_tipo_usuario}
        ) RETURNING *;
      `;

      if (!usuarioNuevo) {
        throw new Error('La inserción del usuario no devolvió el registro creado.');
      }

      const usuarioPublico = { ...usuarioNuevo };
      delete usuarioPublico.contrasena;

      return reply.code(201).send({
        success: true,
        data: usuarioPublico
      });
    } catch (err) {
        fastify.log.error(err);

        if (err.code === '23505') {
            reply.code(400); 
            return {
                success: false,
                message: 'El RUT o el correo electrónico ya están registrados.'
            };
        }

        if (err.code === '23503') {
            reply.code(400);
            return {
                success: false,
                message: 'El tipo de usuario proporcionado no es válido.'
            };
        }

        if (err.code === '22001') {
            reply.code(400);
            return {
                success: false,
                message: 'Uno de los campos excede la longitud máxima permitida.'
            };
        }

        reply.code(500);
        return {
            success: false,
            message: 'Error interno del servidor.'
        };
    }
  });
}