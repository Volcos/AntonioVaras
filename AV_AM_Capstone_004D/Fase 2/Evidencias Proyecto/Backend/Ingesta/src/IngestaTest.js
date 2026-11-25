import { guardarEvento } from './DBConnection/guardarEvento.js';
import pool from './DBConnection/neon_connection.js';
import { ejecutarScraperPuntoTicket } from './scrapers/puntoticket.js';
import { resolverIdTipoEvento } from './utils/categoryNormalizer.js';

async function resolverIdFuente(nombreFuente) {
  const resultado = await pool.query(
    `SELECT id_fuente
     FROM public.fuente
     WHERE LOWER(BTRIM(nombre_fuente)) = LOWER(BTRIM($1));`,
    [nombreFuente]
  );
  if (resultado.rows.length !== 1) {
    throw new Error(
      `Se esperaba una fuente llamada "${nombreFuente}", pero se encontraron ${resultado.rows.length}.`
    );
  }
  return resultado.rows[0].id_fuente;
}

async function probarCarga() {
  try {
    const nombreFuente = process.env.PUNTOTICKET_SOURCE_NAME || 'puntoticket';
    const [idFuente] = await Promise.all([
      resolverIdFuente(nombreFuente),
    ]);

    const eventos = await ejecutarScraperPuntoTicket({ guardarArchivo: false });
    if (eventos.length === 0) {
      throw new Error('El scraper no encontró eventos para cargar.');
    }

    console.log(`Iniciando carga de ${eventos.length} eventos...`);
    let guardados = 0;
    let omitidos = 0;
    const errores = [];

    for (const ev of eventos) {
      const idTipoEvento = resolverIdTipoEvento(ev);
      if (idTipoEvento === 6) {
        console.warn(
          `[CATEGORIA ESPECIALES] "${ev.nombre}": clasificación original: ` +
          `${JSON.stringify(ev.clasificaciones_fuente || [])}`
        );
      }

      if (!ev.id_externo) {
        errores.push({
          nombre: ev.nombre,
          error: new Error('El scraper no entregó un id_externo estable.')
        });
        console.error(`[ERROR] "${ev.nombre}": falta id_externo.`);
        continue;
      }

      try {
        const resultado = await guardarEvento({
          ...ev,
          id_fuente: idFuente,
          id_externo: ev.id_externo,
          id_tipo_evento: idTipoEvento
        });

        guardados += 1;
        console.log(
          `[OK] "${ev.nombre}" [tipo=${idTipoEvento}] -> ${resultado.accion} ` +
          `(ID Evento: ${resultado.id_evento})`
        );
      } catch (error) {
        errores.push({ nombre: ev.nombre, error });
        console.error(`[ERROR] "${ev.nombre}":`, error);
      }
    }

    console.log(
      `\nCarga terminada: ${guardados}/${eventos.length} eventos procesados, ` +
      `${omitidos} omitidos y ${errores.length} errores.`
    );
    if (errores.length > 0) {
      console.error(`Fallaron ${errores.length} eventos.`);
      process.exitCode = 1;
    }
  } catch (error) {
    console.error('Error durante la prueba de inserción:', error);
    process.exitCode = 1;
  } finally {
    try {
      await pool.end();
    } catch (error) {
      console.error('Error cerrando el pool de conexiones:', error);
      process.exitCode = 1;
    }
  }
}

await probarCarga();