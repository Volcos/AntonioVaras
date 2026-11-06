export default async function eventos(fastify, options) {
    fastify.get('/eventos', async (request, reply) => {
    try {
        const { lat, lng, radio_km } = request.query;

        // CASO 1: El frontend envió coordenadas -> Búsqueda cercana con PostGIS
        if (lat && lng) {
        const userLat = parseFloat(lat);
        const userLng = parseFloat(lng);
        const radiusMeters = (parseFloat(radio_km) || 10) * 1000;

        const eventosCercanos = await fastify.sql`
            SELECT 
            e.id_evento AS id,
            e.nombre,
            COALESCE(e.descripcion, '') AS descripcion,
            TO_CHAR(MIN(fe.fecha_inicio) AT TIME ZONE 'America/Santiago', 'YYYY-MM-DD') AS fecha_inicio,
            TO_CHAR(MAX(COALESCE(fe.fecha_termino, fe.fecha_inicio)) AT TIME ZONE 'America/Santiago', 'YYYY-MM-DD') AS fecha_termino,
            TO_CHAR(MIN(fe.fecha_inicio) AT TIME ZONE 'America/Santiago', 'HH24:MI') AS hora,
            CASE
                WHEN RIGHT(LOWER(TRIM(e.direccion)), LENGTH(c.nombre_comuna)) = LOWER(c.nombre_comuna)
                  OR (
                    c.nombre_comuna = 'Santiago'
                    AND RIGHT(LOWER(TRIM(e.direccion)), LENGTH('Santiago Centro')) = LOWER('Santiago Centro')
                  )
                THEN TRIM(e.direccion)
                ELSE CONCAT_WS(', ', NULLIF(TRIM(e.direccion), ''), c.nombre_comuna)
            END AS localizacion,
            e.latitud AS latitude,
            e.longitud AS longitude,
            e.imagen_url AS imagen,
            STRING_AGG(DISTINCT f.nombre_fuente, ', ') AS fuente_info,
            COALESCE(e.organizador, '') AS organizador,
            ROUND(
                (ST_Distance(
                ST_SetSRID(ST_MakePoint(e.longitud, e.latitud), 4326)::geography,
                ST_SetSRID(ST_MakePoint(${userLng}, ${userLat}), 4326)::geography
                ) / 1000)::numeric, 
                2
            ) AS distancia_km
            FROM evento e
            JOIN comuna c ON e.id_comuna = c.id_comuna
            LEFT JOIN fecha_evento fe ON e.id_evento = fe.id_evento
            LEFT JOIN evento_fuente ef ON e.id_evento = ef.id_evento
            LEFT JOIN fuente f ON ef.id_fuente = f.id_fuente
            WHERE e.latitud IS NOT NULL 
            AND e.longitud IS NOT NULL
            AND ST_DWithin(
                ST_SetSRID(ST_MakePoint(e.longitud, e.latitud), 4326)::geography,
                ST_SetSRID(ST_MakePoint(${userLng}, ${userLat}), 4326)::geography,
                ${radiusMeters}
            )
            GROUP BY 
            e.id_evento, e.nombre, e.descripcion, e.direccion, c.nombre_comuna, 
            e.latitud, e.longitud, e.imagen_url, e.organizador
            ORDER BY distancia_km ASC;
        `;

        return eventosCercanos;
        }

        // CASO 2: Consulta estándar sin GPS -> Todos los eventos
        const eventos = await fastify.sql`
        SELECT 
            e.id_evento AS id,
            e.nombre,
            COALESCE(e.descripcion, '') AS descripcion,
            TO_CHAR(MIN(fe.fecha_inicio) AT TIME ZONE 'America/Santiago', 'YYYY-MM-DD') AS fecha_inicio,
            TO_CHAR(MAX(COALESCE(fe.fecha_termino, fe.fecha_inicio)) AT TIME ZONE 'America/Santiago', 'YYYY-MM-DD') AS fecha_termino,
            TO_CHAR(MIN(fe.fecha_inicio) AT TIME ZONE 'America/Santiago', 'HH24:MI') AS hora,
            CASE
                WHEN RIGHT(LOWER(TRIM(e.direccion)), LENGTH(c.nombre_comuna)) = LOWER(c.nombre_comuna)
                  OR (
                    c.nombre_comuna = 'Santiago'
                    AND RIGHT(LOWER(TRIM(e.direccion)), LENGTH('Santiago Centro')) = LOWER('Santiago Centro')
                  )
                THEN TRIM(e.direccion)
                ELSE CONCAT_WS(', ', NULLIF(TRIM(e.direccion), ''), c.nombre_comuna)
            END AS localizacion,
            e.latitud AS latitude,
            e.longitud AS longitude,
            e.imagen_url AS imagen,
            STRING_AGG(DISTINCT f.nombre_fuente, ', ') AS fuente_info,
            COALESCE(e.organizador, '') AS organizador
        FROM evento e
        JOIN comuna c ON e.id_comuna = c.id_comuna
        LEFT JOIN fecha_evento fe ON e.id_evento = fe.id_evento
        LEFT JOIN evento_fuente ef ON e.id_evento = ef.id_evento
        LEFT JOIN fuente f ON ef.id_fuente = f.id_fuente
        GROUP BY 
            e.id_evento, e.nombre, e.descripcion, e.direccion, c.nombre_comuna, 
            e.latitud, e.longitud, e.imagen_url, e.organizador
        ORDER BY MIN(fe.fecha_inicio) ASC NULLS LAST;
        `;

        return eventos;

    } catch (err) {
        fastify.log.error(err);
        reply.code(500);
        return { status: 'error', message: 'Error al obtener eventos' };
    }
    });
}
