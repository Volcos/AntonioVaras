// src/queues/scraperFlow.js
import { FlowProducer } from 'bullmq';
import { redisConnection } from './connection.js';
import { obtenerListaEventosChile } from '../scrapers/passline.js';

const flowProducer = new FlowProducer({ connection: redisConnection });

export async function dispararFlujoScraping() {
  console.log('Buscando catálogo de eventos...');
  
  // 1. Obtener las URLs de los eventos (ej. 5 de prueba)
  const enlaces = await obtenerListaEventosChile('chile', 5);

  if (enlaces.length === 0) {
    console.log('No se encontraron enlaces para procesar.');
    return;
  }

  console.log(`Se encontraron ${enlaces.length} eventos. Creando el flujo...`);

  // 2. Mapear cada URL a la definición de un Job Hijo
  const hijos = enlaces.map((url, index) => ({
    name: `extraer-evento-${index}`,
    queueName: 'scraper-children',
    data: { url },
    opts: {
      attempts: 3, // Reintentar hasta 3 veces si falla
      backoff: { type: 'exponential', delay: 3000 } // Espera 3s, 6s, 12s... entre reintentos
    }
  }));

  // 3. Crear la estructura árbol en BullMQ
  await flowProducer.add({
    name: 'consolidar-eventos-passline',
    queueName: 'scraper-parent',
    children: hijos
  });

  console.log('¡Flujo enviado a Redis con éxito!');
}