import { dispararFlujoScraping } from './src/queues/scraperFlow.js';
import { ejecutarIngestaTicketmaster } from './src/queues/ticketmasterFlow.js';
import pool from './src/DBConnection/neon_connection.js';

async function main() {
  const errores = [];

  try {
    console.log('=== Iniciando Sincronización Diaria ===');
    for (const [nombre, ejecutar] of [
      ['PuntoTicket', dispararFlujoScraping],
      ['Ticketmaster', ejecutarIngestaTicketmaster]
    ]) {
      try {
        await ejecutar();
      } catch (error) {
        errores.push(error);
        console.error(`Fallo en el job de ${nombre}:`, error);
      }
    }

    if (errores.length > 0) {
      throw new AggregateError(errores, 'Fallaron uno o más jobs de ingesta.');
    }
    console.log('=== Sincronización Finalizada con Éxito ===');
  } catch (error) {
    console.error('Fallo crítico en sincronización:', error);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

main();