const logUserSchema = {
    body: {
        type: 'object',
        required: ['nombre', 'contrasena'],
        properties: {
            nombre: { type: 'string', minLength: 3, maxLength: 100 },
            contrasena: { type: 'string', minLength: 6, maxLength: 100 }
        },
        additionalProperties: false
    }
};

export default async function logUser(fastify, options) {
    fastify.post('/login', { schema: logUserSchema }, async (request, reply) => {
        try {
            const { nombre, contrasena } = request.body;   
            
            const [usuario] = await fastify.sql`
                SELECT * FROM usuario
                WHERE nombre_usuario = ${nombre.trim()} AND contrasena = ${contrasena.trim()};
            `;

            if (!usuario) {
                reply.code(401);
                return {
                    success: false,
                    message: 'Nombre de usuario o contraseña incorrectos.'
                };
            }

            reply.code(200);
            return {
                success: true,
                data: usuario
            };
        } catch (err) {
            fastify.log.error(err);
            reply.code(500);
            return {
                success: false,
                message: 'Error al procesar la solicitud de inicio de sesión.'
            };
        }
    });
}