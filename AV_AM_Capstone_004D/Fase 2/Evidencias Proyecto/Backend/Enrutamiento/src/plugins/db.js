import 'dotenv/config';
import fp from 'fastify-plugin';

import { neon }  from '@neondatabase/serverless';

async function dbConnector(fastify, options) {
    const db = neon(process.env.DATABASE_URL);
    console.log('DatabaseURL detectada: ', process.env.DATABASE_URL ? 'Existe':'No detectada')
    fastify.decorate( 'sql', db );
}

export default fp(dbConnector);