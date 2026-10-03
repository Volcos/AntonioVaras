
// export default async function statusRoute(fastify,options){
//     fastify.get('/status', async (request, reply)=> {
//         return { status: 'ok', uptime: process.uptime()};
//     })
// }

export default async function statusDB(fastify, options) {
    fastify.get('/status', async (request, reply)=>{
        try {
            const result = await fastify.sql`SELECT version(), NOW()`;
            return {
            status: 'Online',
            db: 'Conectado a neon',
            servertime: result[0].now,
            db_version: result[0].version
            };
        } catch (err) {
            fastify.log.error(err);
            reply.code(500);
            return {
                status: 'error',
                message: 'fallo al conectar a Neon'
            };
        }
    });
}