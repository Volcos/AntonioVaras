import { guardarEvento } from './DBConnection/guardarEvento.js';
import pool from './DBConnection/neon_connection.js';
import { ejecutarScraperPuntoTicket } from './scrapers/puntoticket.js';

const MACRO_CATEGORIAS = ['Música', 'Deportes', 'Teatro', 'Familia'];

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

async function resolverIdsTiposEvento() {
  const resultado = await pool.query(
    `SELECT id_tipo_evento, nombre_tipo_evento
     FROM public.tipo_evento
     WHERE nombre_tipo_evento = ANY($1::text[]);`,
    [MACRO_CATEGORIAS]
  );
  if (resultado.rows.length !== MACRO_CATEGORIAS.length) {
    throw new Error(
      `Se esperaban las ${MACRO_CATEGORIAS.length} macro-categorías (${MACRO_CATEGORIAS.join(', ')}), ` +
      `pero se encontraron ${resultado.rows.length}.`
    );
  }
  return new Map(
    resultado.rows.map(row => [row.nombre_tipo_evento, row.id_tipo_evento])
  );
}

function obtenerMacroCategoria(evento) {
  const macroCategorias = [
    ...new Set(
      (evento.clasificaciones_fuente || [])
        .map(clasificacion => clasificacion.macro_categoria)
        .filter(macroCategoria => MACRO_CATEGORIAS.includes(macroCategoria))
    )
  ];

  return macroCategorias.length === 1 ? macroCategorias[0] : null;
}

async function probarCarga() {
  try {
    const nombreFuente = process.env.PUNTOTICKET_SOURCE_NAME || 'puntoticket';
    const [idFuente, idsTiposEvento] = await Promise.all([
      resolverIdFuente(nombreFuente),
      resolverIdsTiposEvento()
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
      const macroCategoria = obtenerMacroCategoria(ev);
      if (!macroCategoria) {
        omitidos += 1;
        console.warn(
          `[OMITIDO] "${ev.nombre}": no tiene una macro-categoría única reconocida.`
        );
        continue;
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
          id_tipo_evento: idsTiposEvento.get(macroCategoria)
        });

        guardados += 1;
        console.log(
          `[OK] "${ev.nombre}" [${macroCategoria}] -> ${resultado.accion} ` +
          `(ID Evento: ${resultado.id_evento})`
        );
      } catch (error) {
        errores.push({ nombre: ev.nombre, error });
        console.error(`[ERROR] "${ev.nombre}":`, error);
      }
    }

    console.log(
      `\nCarga terminada: ${guardados}/${eventos.length} eventos procesados, ` +
      `${omitidos} omitidos por falta de macro-categoría única.`
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