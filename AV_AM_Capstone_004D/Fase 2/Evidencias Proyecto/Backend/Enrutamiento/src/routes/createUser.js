const { crearUsuarioSchema } = {
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

export default async function crearUsuario(fastify, options) {
  fastify.post('/usuarios', { schema: crearUsuarioSchema }, async (request, reply) => {
    try {
      const datos = request.body;

      const [usuarioNuevo] = await fastify.sql`
        INSERT INTO usuario (
          $1, $2, $3, $4, $5
        ) VALUES (
          ${datos.nombre.trim()}, 
          ${datos.rut.trim()}, 
          ${datos.email.trim()}, 
          ${datos.contrasena.trim()}, 
          ${datos.tipo_usuario}
        ) RETURNING *;
      `;

      reply.code(201);
      return {
        success: true,
        data: usuarioNuevo
      };    
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