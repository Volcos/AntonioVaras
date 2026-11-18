import { verifyPassword } from './passwordUtils.js';

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

export default async function logUser(fastify) {
    fastify.post('/login', {
        schema: logUserSchema,
        config: {
            rateLimit: {
                max: 5,
                timeWindow: '1 minute'
            }
        }
    }, async (request, reply) => {
        try {
            const { nombre, contrasena } = request.body;   
            
            const [usuario] = await fastify.sql`
                SELECT * FROM usuario
                WHERE nombre_usuario = ${nombre.trim()};
            `;

            if (!usuario || !await verifyPassword(contrasena, usuario.contrasena)) {
                return reply.code(401).send({
                    success: false,
                    message: 'Nombre de usuario o contraseña incorrectos.'
                });
            }

            const usuarioPublico = { ...usuario };
            delete usuarioPublico.contrasena;
            const token = fastify.jwt.sign({
                id_usuario: usuario.id_usuario,
                nombre_usuario: usuario.nombre_usuario
            });

            return reply.code(200).send({
                success: true,
                token,
                data: usuarioPublico
            });
        } catch (err) {
            fastify.log.error(err);
            reply.code(500);
            return {
                success: false,
                message: 'Error al procesar la solicitud de inicio de sesión.'
            };
        }
    });

    fastify.get('/me', {
        onRequest: [fastify.authenticate]
    }, async (request, reply) => {
        return reply.code(200).send({
            success: true,
            data: request.user
        });
    });
}