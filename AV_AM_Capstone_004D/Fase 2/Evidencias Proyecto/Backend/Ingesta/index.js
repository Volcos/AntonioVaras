// index.js
import './src/workers/scraperWorker.js';
import './src/workers/parentWorker.js';
import { iniciarProgramacion } from './src/queues/scheduler.js';

console.log('Workers y servicios iniciados...');

// Arrancar la programación automática
iniciarProgramacion();