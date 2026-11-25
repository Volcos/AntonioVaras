import pool from '../DBConnection/neon_connection.js';
import { guardarEvento } from '../DBConnection/guardarEvento.js';
import { ejecutarScraperPuntoTicket } from '../scrapers/puntoticket.js';
import { resolverIdTipoEvento } from '../utils/categoryNormalizer.js';

export function resolverMacroCategoriaPuntoTicket(clasificaciones = []) {
  return resolverIdTipoEvento({
    clasificaciones_fuente: Array.isArray(clasificaciones) ? clasificaciones : []
  });
}

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

export async function dispararFlujoScraping() {
  console.log('Iniciando extracción y procesamiento de PuntoTicket...');

  const nombreFuente = process.env.PUNTOTICKET_SOURCE_NAME || 'puntoticket';
  const [idFuente, eventosExtraidos] = await Promise.all([
    resolverIdFuente(nombreFuente),
    ejecutarScraperPuntoTicket({ guardarArchivo: false })
  ]);

  if (eventosExtraidos.length === 0) {
    console.log('No se encontraron eventos para procesar.');
    return { total: 0, guardados: 0, omitidos: 0, errores: 0 };
  }

  console.log(`Procesando ${eventosExtraidos.length} eventos de PuntoTicket...`);
  const resultados = [];
  let omitidos = 0;
  const errores = [];

  for (const evento of eventosExtraidos) {
    const idTipoEvento = resolverIdTipoEvento(evento);
    if (idTipoEvento === 6) {
      console.warn(
        `[CATEGORIA ESPECIALES] "${evento.nombre}": clasificación original: ` +
        `${JSON.stringify(evento.clasificaciones_fuente || [])}`
      );
    }

    if (!evento.fecha_inicio || !evento.comuna || !evento.id_externo) {
      omitidos += 1;
      console.warn(
        `[OMITIDO] "${evento.nombre}": falta ${[
          !evento.fecha_inicio && 'fecha_inicio',
          !evento.comuna && 'comuna',
          !evento.id_externo && 'id_externo'
        ].filter(Boolean).join(', ')}.`
      );
      continue;
    }

    try {
      const resultado = await guardarEvento({
        ...evento,
        id_fuente: idFuente,
        id_tipo_evento: idTipoEvento
      });
      resultados.push(resultado);
      console.log(
        `[${resultado.accion}] "${evento.nombre}" [tipo=${idTipoEvento}] ` +
        `(ID: ${resultado.id_evento})`
      );
    } catch (error) {
      errores.push({ nombre: evento.nombre, error });
      console.error(`[ERROR] "${evento.nombre}": ${error.message}`);
    }
  }

  const resumen = {
    total: eventosExtraidos.length,
    guardados: resultados.length,
    omitidos,
    errores: errores.length
  };
  console.log(
    `\nSincronización de PuntoTicket finalizada: ${resumen.guardados} guardados, ` +
    `${resumen.omitidos} omitidos y ${resumen.errores} errores de ${resumen.total}.`
  );

  if (errores.length > 0) {
    throw new AggregateError(
      errores.map(({ error }) => error),
      `Falló el procesamiento de ${errores.length} eventos de PuntoTicket.`
    );
  }

  return resumen;
}
