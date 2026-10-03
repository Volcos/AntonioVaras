export default async function getAllEvents(fastify, options) {
    fastify.get('/AllEvents', async (request, reply)=>{
        try {
            const result = await fastify.sql`
            SELECT e.nombre, 
                e.descripcion, 
                e.direccion, 
                e.imagen_url,
                e.estado,
                c.nombre_comuna
            FROM evento e JOIN comuna c ON c.id_comuna = e.id_comuna;
            `;
            return result;
        } catch (err) {
            fastify.log.error(err);
            reply.code(500);
            return {
                status: 'error',
                message: 'Error al realizar la consulta'
            };
        }
    });
}