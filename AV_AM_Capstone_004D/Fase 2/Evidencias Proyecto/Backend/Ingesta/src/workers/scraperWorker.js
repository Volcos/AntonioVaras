// src/workers/scraperWorker.js
import { Worker } from 'bullmq';
import { redisConnection } from '../queues/connection.js';
import { obtenerDatosEvento } from '../scrapers/passline.js';
import { obtenerDetalleEventoTM } from '../APIs/ticketmaster.js';

export const scraperWorker = new Worker(
  'scraper-children',
  async (job) => {
    // Si viene de Ticketmaster
    if (job.data.provider === 'ticketmaster') {
      console.log(`[Hijo - ${job.id}] Consultando API TM ID: ${job.data.id}`);
      const data = await obtenerDetalleEventoTM(job.data.id);
      console.log(`[Hijo - ${job.id}] ¡Éxito! Extraído TM: ${data.title}`);
      return data;
    }

    // Flujo predeterminado (Passline por scraping con Playwright)
    console.log(`[Hijo - ${job.id}] Procesando URL: ${job.data.url}`);
    const metadata = await obtenerDatosEvento(job.data.url);
    console.log(`[Hijo - ${job.id}] ¡Éxito! Extraído: ${metadata.title || 'Sin título'}`);
    return metadata;
  },
  {
    connection: redisConnection,
    concurrency: 5 // Al ser peticiones HTTP de API, puedes tolerar mayor concurrencia
  }
);

scraperWorker.on('failed', (job, err) => {
  console.error(`[Hijo - ${job?.id}] Falló con el error: ${err.message}`);
});