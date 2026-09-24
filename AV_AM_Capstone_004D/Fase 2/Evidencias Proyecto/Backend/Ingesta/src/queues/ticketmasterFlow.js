// src/queues/ticketmasterFlow.js
import { FlowProducer } from 'bullmq';
import { redisConnection } from './connection.js';
import { buscarEventosTicketmaster } from '../APIs/ticketmaster.js';

const flowProducer = new FlowProducer({ connection: redisConnection });

export async function dispararFlujoTicketmaster(countryCode = 'CL', limite = 10) {
  console.log(`[TM Flow] Buscando catálogo en Ticketmaster (${countryCode})...`);

  const eventIds = await buscarEventosTicketmaster(countryCode, limite);

  if (eventIds.length === 0) {
    console.log('[TM Flow] No se encontraron eventos.');
    return;
  }

  console.log(`[TM Flow] ${eventIds.length} eventos encontrados. Creando jobs...`);

  // Cada job hijo se encargará de pedir el detalle del evento
  const hijos = eventIds.map((id, index) => ({
    name: `extraer-tm-${index}`,
    queueName: 'scraper-children',
    data: { 
      provider: 'ticketmaster', 
      id 
    },
    opts: {
      attempts: 3,
      backoff: { type: 'exponential', delay: 2000 }
    }
  }));

  // El padre consolidará los eventos en su retorno
  await flowProducer.add({
    name: 'consolidar-eventos-ticketmaster',
    queueName: 'scraper-parent',
    children: hijos
  });

  console.log('¡Flujo de Ticketmaster encolado con éxito!');
}