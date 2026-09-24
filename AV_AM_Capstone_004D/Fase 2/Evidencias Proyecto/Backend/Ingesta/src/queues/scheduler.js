// src/queues/scheduler.js
import { Queue, Worker } from 'bullmq';
import { redisConnection } from './connection.js';
// Importamos el nuevo flujo de Ticketmaster
import { dispararFlujoTicketmaster } from './ticketmasterFlow.js';

const SCHEDULER_QUEUE_NAME = 'cron-trigger-queue';

export const schedulerQueue = new Queue(SCHEDULER_QUEUE_NAME, { connection: redisConnection });

// Worker que responde al temporizador
export const schedulerWorker = new Worker(
  SCHEDULER_QUEUE_NAME,
  async (job) => {
    console.log(`\n [${new Date().toLocaleTimeString()}] Temporizador activado: Disparando flujo de Ticketmaster...`);
    
    // Dispara el flujo para Chile (CL) limitando a 10 eventos por tanda
    await dispararFlujoTicketmaster('CL', 10);
  },
  { connection: redisConnection }
);

schedulerWorker.on('failed', (job, err) => {
  console.error(`[Scheduler Worker] Falló al disparar flujo: ${err.message}`);
});

export async function iniciarProgramacion() {
  // upsertJobScheduler registra o actualiza el temporizador de forma idempotente
  await schedulerQueue.upsertJobScheduler(
    'ejecutar-ticketmaster-periodico', // Nuevo ID único para la programación
    {
      every: 5 * 60 * 1000 // Frecuencia: Cada 5 minutos (ajusta según la cuota de tu API key)
      // Para usar Cron exacto: pattern: '0 8,14,20 * * *'
    },
    {
      name: 'ejecutar-ticketmaster-job',
      data: {}
    }
  );

  console.log('Programador activo: Se ejecutará Ticketmaster cada 5 minutos.');
}