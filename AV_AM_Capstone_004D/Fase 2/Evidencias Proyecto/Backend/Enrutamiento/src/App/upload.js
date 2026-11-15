// src/routes/upload.js
import path from 'node:path';
import crypto from 'node:crypto';
import { pipeline } from 'node:stream/promises';
import { Storage } from '@google-cloud/storage';

// Inicializa el cliente de GCS.
// - En local: leerá GOOGLE_APPLICATION_CREDENTIALS desde tu .env
// - En Cloud Run: usará automáticamente la cuenta de servicio del contenedor
const storage = new Storage();

// Reemplaza por el nombre exacto de tu bucket (o léelo desde process.env.GCS_BUCKET_NAME)
const BUCKET_NAME = process.env.GCS_BUCKET_NAME || 'panoramapp-eventos-img';
const bucket = storage.bucket(BUCKET_NAME);

const TIPOS_PERMITIDOS = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp'
]);

export default async function uploadRoutes(fastify, options) {
  fastify.post('/upload/imagen', async (request, reply) => {
    try {
      // 1. Obtener el archivo de la petición multipart/form-data
      const archivo = await request.file();

      if (!archivo) {
        return reply.code(400).send({
          success: false,
          message: 'No se adjuntó ningún archivo en la petición.'
        });
      }

      // 2. Validar el tipo MIME real del archivo
      if (!TIPOS_PERMITIDOS.has(archivo.mimetype)) {
        // Consumir/drenar el stream para evitar que la conexión quede colgada
        archivo.file.resume();
        return reply.code(400).send({
          success: false,
          message: 'Formato no soportado. Solo se permiten imágenes JPG, PNG o WebP.'
        });
      }

      // 3. Generar ruta y nombre único dentro del bucket (ej: eventos/uuid.jpg)
      const extension = path.extname(archivo.filename)?.toLowerCase() || '.jpg';
      const rutaDestino = `eventos/${crypto.randomUUID()}${extension}`;
      const blob = bucket.file(rutaDestino);

      // 4. Crear el stream de escritura hacia el bucket
      const writeStream = blob.createWriteStream({
        resumable: false, // Ideal para archivos pequeños/medianos (< 10 MB)
        metadata: {
          contentType: archivo.mimetype,
          cacheControl: 'public, max-age=31536000'
        }
      });

      // 5. Transferir los bytes desde la petición HTTP directo a Google Cloud Storage
      await pipeline(archivo.file, writeStream);

      // Verificar si el archivo excedió el límite de tamaño configurado
      if (archivo.file.truncated) {
        await blob.delete().catch(() => {}); // Eliminar archivo incompleto del bucket
        return reply.code(413).send({
          success: false,
          message: 'La imagen supera el peso máximo permitido (5 MB).'
        });
      }

      // 6. Devolver la URL pública lista para guardar en la columna `imagen_url` de Neon
      const publicUrl = `https://storage.googleapis.com/${BUCKET_NAME}/${rutaDestino}`;

      return reply.code(201).send({
        success: true,
        imagen_url: publicUrl
      });

    } catch (error) {
      request.log.error(error, 'Error subiendo imagen a Cloud Storage');
      return reply.code(500).send({
        success: false,
        message: 'Error interno al procesar la subida de la imagen.'
      });
    }
  });
}