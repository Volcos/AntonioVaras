import pool from './src/DBConnection/neon_connection.js';

async function verificarConexion() {
  try {
    const res = await pool.query('SELECT NOW() AS hora_servidor, postgis_version();');
    console.log('Conexión establecida.');
    console.log(' Hora del servidor Neon:', res.rows[0].hora_servidor);
    console.log(' Versión de PostGIS:', res.rows[0].postgis_version);
  } catch (error) {
    console.error('Error al consultar la BD:', error);
  } finally {
    await pool.end();
  }
}

verificarConexion();