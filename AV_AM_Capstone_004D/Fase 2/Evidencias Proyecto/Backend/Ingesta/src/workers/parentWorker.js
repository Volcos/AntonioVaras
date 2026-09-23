// src/workers/parentWorker.js
import { Worker } from 'bullmq';
import { redisConnection } from '../queues/connection.js';

export const parentWorker = new Worker(
  'scraper-parent', // Nombre de la cola del padre
  async (job) => {
    console.log(`[Padre - ${job.id}] Todos los hijos terminaron. Consolidando datos...`);

    // Obtener los retornos de todas las tareas hijas asociadas
    const childrenValues = await job.getChildrenValues();

    // childrenValues es un objeto donde la llave es la id del hijo y el valor es el return
    const listaConsolidada = Object.values(childrenValues);

    console.log(`[Padre - ${job.id}] Se consolidaron exitosamente ${listaConsolidada.length} eventos.`);
    console.log(listaConsolidada)
    // Aquí en el futuro enviarías los datos a la Base de Datos
    return {
      totalEventos: listaConsolidada.length,
      eventos: listaConsolidada
    };
  },
  { connection: redisConnection }
);