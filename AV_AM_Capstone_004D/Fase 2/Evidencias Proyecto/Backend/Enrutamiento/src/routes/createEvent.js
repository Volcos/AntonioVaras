// 1. El esquema se declara AFUERA de la ruta
const crearEventoSchema = {
  body: {
    type: 'object',
    required: ['nombre', 'direccion', 'id_comuna', 'id_tipo_evento'],
    properties: {
      nombre: { type: 'string', minLength: 3, maxLength: 150 },
      descripcion: { type: 'string', maxLength: 1000 },
      direccion: { type: 'string', minLength: 5, maxLength: 200 },
      imagen_url: { type: 'string', format: 'uri' },
      id_comuna: { type: 'integer', minimum: 1 },
      id_tipo_evento: { type: 'integer', minimum: 1 }, // Agregado aquí
      latitud: { type: 'number', minimum: -90.0, maximum: 90.0 },
      longitud: { type: 'number', minimum: -180.0, maximum: 180.0 },
      organizador: { type: 'string', maxLength: 150 },
      fuente_informacion: { type: 'string', maxLength: 255 }
    },
    additionalProperties: false
  }
};

export default async function crearEvento(fastify, options) {
  // 2. Se inyecta el esquema como opción en fastify.post
  fastify.post('/eventos', { schema: crearEventoSchema }, async (request, reply) => {
    try {
      const datos = request.body;

      // 3. Ya no necesitas el 'if': Fastify ya validó campos requeridos y tipos

      const [eventoNuevo] = await fastify.sql`
        INSERT INTO evento (
          nombre, 
          descripcion, 
          direccion, 
          imagen_url, 
          id_comuna, 
          id_tipo_evento, 
          latitud, 
          longitud, 
          organizador, 
          fuente_informacion
        ) VALUES (
          ${datos.nombre.trim()}, 
          ${datos.descripcion ? datos.descripcion.trim() : null}, 
          ${datos.direccion.trim()},
          ${datos.imagen_url || null}, 
          ${datos.id_comuna}, 
          ${datos.id_tipo_evento}, 
          ${datos.latitud || null}, 
          ${datos.longitud || null}, 
          ${datos.organizador ? datos.organizador.trim() : null},
          ${datos.fuente_informacion || null}
        ) RETURNING *;
      `;

      reply.code(201);
      return {
        success: true,
        data: eventoNuevo
      };
    } catch (err) {
      fastify.log.error(err);

      // Manejo específico si envían una comuna o tipo_evento inexistente
      if (err.code === '23503') {
        reply.code(400);
        return {
          success: false,
          message: 'El id_comuna o id_tipo_evento no existe en el sistema.'
        };
      }

      reply.code(500);
      return {
        success: false,
        message: 'No se pudo registrar el evento'
      };
    }
  });
}