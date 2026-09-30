// src/config/db.js
import { Pool } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false, // Requerido por servicios cloud como Neon
  },
  max: 10, // Máximo de conexiones simultáneas en el pool
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

// Prueba rápida de conexión
pool.on('connect', () => {
  console.log(' Conectado exitosamente a PostgreSQL (Neon)');
});

pool.on('error', (err) => {
  console.error('Error inesperado en el cliente de base de datos:', err);
});

export default pool;