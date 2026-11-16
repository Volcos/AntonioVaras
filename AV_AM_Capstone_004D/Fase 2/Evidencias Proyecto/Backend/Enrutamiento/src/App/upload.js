// src/routes/upload.js
import path from 'node:path';
import crypto from 'node:crypto';
import { pipeline } from 'node:stream/promises';
import { Storage } from '@google-cloud/storage';

const storage = new Storage();
const BUCKET_NAME = process.env.GCS_BUCKET_NAME || 'panoramapp-eventos-img';
const bucket = storage.bucket(BUCKET_NAME);

const TIPOS_PERMITIDOS = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp'
]);

/**
 * Función auxiliar para extraer la ruta interna del objeto dentro del bucket
 * De: "https://storage.googleapis.com/panoramapp-eventos-img/eventos/123.jpg"
 * A:  "eventos/123.jpg"
 */
function extraerRutaDesdeUrl(imagenUrl) {
  if (!imagenUrl || typeof imagenUrl !== 'string') return null;
  const prefijo = `https://storage.googleapis.com/${BUCKET_NAME}/`;
  if (!imagenUrl.startsWith(prefijo)) return null;
  return imagenUrl.slice(prefijo.length);
}

export default async function uploadRoutes(fastify, options) {
  // ---------------------------------------------------------------------------
  // 1. SUBIR IMAGEN (POST /api/upload/imagen)
  // ---------------------------------------------------------------------------
  fastify.post('/upload/imagen', async (request, reply) => {
    try {
      const archivo = await request.file();
      if (!archivo) {
        return reply.code(400).send({ success: false, message: 'No se adjuntó ningún archivo.' });
      }

      if (!TIPOS_PERMITIDOS.has(archivo.mimetype)) {
        archivo.file.resume();
        return reply.code(400).send({ success: false, message: 'Formato no soportado.' });
      }

      const extension = path.extname(archivo.filename)?.toLowerCase() || '.jpg';
      const rutaDestino = `eventos/${crypto.randomUUID()}${extension}`;
      const blob = bucket.file(rutaDestino);

      await pipeline(
        archivo.file,
        blob.createWriteStream({
          resumable: false,
          metadata: {
            contentType: archivo.mimetype,
            cacheControl: 'public, max-age=31536000'
          }
        })
      );

      if (archivo.file.truncated) {
        await blob.delete().catch(() => {});
        return reply.code(413).send({ success: false, message: 'La imagen supera los 5 MB.' });
      }

      return reply.code(201).send({
        success: true,
        imagen_url: `https://storage.googleapis.com/${BUCKET_NAME}/${rutaDestino}`
      });
    } catch (error) {
      request.log.error(error, 'Error subiendo imagen');
      return reply.code(500).send({ success: false, message: 'Error al subir la imagen.' });
    }
  });

  // ---------------------------------------------------------------------------
  // 2. ELIMINAR IMAGEN DEL BUCKET (DELETE /api/upload/imagen)
  // ---------------------------------------------------------------------------
  fastify.delete('/upload/imagen', async (request, reply) => {
    try {
      const { imagen_url } = request.body || {};
      const rutaArchivo = extraerRutaDesdeUrl(imagen_url);

      // Seguridad: Si la URL es externa (ej. PuntoTicket o Ticketmaster), no intentamos borrarla
      if (!rutaArchivo) {
        return reply.code(400).send({
          success: false,
          message: 'La URL proporcionada no pertenece al bucket de almacenamiento.'
        });
      }

      const [respuestaBorrado] = await bucket.file(rutaArchivo).delete({ ignoreNotFound: true });
      const existiaPreviamente = respuestaBorrado.status !== 404;

      return reply.code(200).send({
        success: true,
        existia_previamente: existiaPreviamente,
        message: existiaPreviamente
          ? 'Imagen eliminada correctamente del bucket.'
          : 'La imagen no existía en el bucket.'
      });
    } catch (error) {
      request.log.error(error, 'Error eliminando imagen');
      return reply.code(500).send({ success: false, message: 'Error al eliminar la imagen.' });
    }
  });

  // ---------------------------------------------------------------------------
  // 3. REEMPLAZAR IMAGEN EN UN SOLO PASO (PUT /api/upload/imagen)
  // ---------------------------------------------------------------------------
  fastify.put('/upload/imagen', async (request, reply) => {
    try {
      // Leemos los campos del multipart (el archivo nuevo y el campo de texto url_anterior)
      const parts = request.parts();
      let urlAnterior = null;
      let nuevaUrl = null;

      for await (const part of parts) {
        if (part.type === 'field' && part.fieldname === 'url_anterior') {
          urlAnterior = part.value;
        } else if (part.type === 'file') {
          if (!TIPOS_PERMITIDOS.has(part.mimetype)) {
            part.file.resume();
            return reply.code(400).send({ success: false, message: 'Formato no soportado.' });
          }

          const extension = path.extname(part.filename)?.toLowerCase() || '.jpg';
          const rutaDestino = `eventos/${crypto.randomUUID()}${extension}`;
          const blob = bucket.file(rutaDestino);

          await pipeline(
            part.file,
            blob.createWriteStream({
              resumable: false,
              metadata: {
                contentType: part.mimetype,
                cacheControl: 'public, max-age=31536000'
              }
            })
          );

          if (part.file.truncated) {
            await blob.delete().catch(() => {});
            return reply.code(413).send({ success: false, message: 'La imagen supera los 5 MB.' });
          }

          nuevaUrl = `https://storage.googleapis.com/${BUCKET_NAME}/${rutaDestino}`;
        }
      }

      if (!nuevaUrl) {
        return reply.code(400).send({ success: false, message: 'No se envió la nueva imagen.' });
      }

      // Una vez subida la nueva con éxito, borramos la anterior si pertenecía a nuestro bucket
      const rutaAnterior = extraerRutaDesdeUrl(urlAnterior);
      if (rutaAnterior) {
        await bucket.file(rutaAnterior).delete({ ignoreNotFound: true });
      }

      return reply.code(200).send({
        success: true,
        imagen_url: nuevaUrl
      });
    } catch (error) {
      request.log.error(error, 'Error reemplazando imagen');
      return reply.code(500).send({ success: false, message: 'Error al reemplazar la imagen.' });
    }
  });
}