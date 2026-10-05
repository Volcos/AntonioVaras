export default async function getAllEvents(fastify, options) {
    fastify.get('/AllEvents', async (request, reply)=>{
        try {
            const result = await fastify.sql`
            SELECT 
            e.id_evento AS id,
            e.nombre,
            COALESCE(e.descripcion, '') AS descripcion,
            TO_CHAR(MIN(fe.fecha), 'YYYY-MM-DD') AS fecha_inicio,
            TO_CHAR(MAX(fe.fecha), 'YYYY-MM-DD') AS fecha_termino,
            TO_CHAR(MIN(fe.fecha), 'HH24:MI') AS hora,
            CONCAT(e.direccion, ', ', c.nombre_comuna) AS localizacion,
            e.latitud AS latitude,
            e.longitud AS longitude,
            e.imagen_url AS imagen,
            e.fuente_informacion AS fuente_info,
            COALESCE(e.organizador, 'Sin organizador') AS organizador
            FROM evento e
            JOIN comuna c ON e.id_comuna = c.id_comuna
            LEFT JOIN fecha_evento fe ON e.id_evento = fe.id_evento
            GROUP BY 
            e.id_evento, 
            e.nombre, 
            e.descripcion, 
            e.direccion, 
            c.nombre_comuna, 
            e.latitud, 
            e.longitud, 
            e.imagen_url, 
            e.fuente_informacion, 
            e.organizador
            ORDER BY MIN(fe.fecha) ASC NULLS LAST;
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