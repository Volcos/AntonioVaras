import pool from '../DBConnection/neon_connection.js';
import { guardarEvento } from '../DBConnection/guardarEvento.js';
import {
  buscarEventosTicketmaster,
  obtenerDetalleEventoTM
} from '../APIs/ticketmaster.js';

const MACRO_CATEGORIAS = ['Música', 'Deportes', 'Teatro', 'Familia'];

export function resolverMacroCategoriaTicketmaster(clasificaciones = []) {
  if (!Array.isArray(clasificaciones)) {
    return null;
  }

  const macroCategorias = [
    ...new Set(
      clasificaciones
        .map(clasificacion => clasificacion?.macro_categoria)
        .filter(macroCategoria => MACRO_CATEGORIAS.includes(macroCategoria))
    )
  ];

  return macroCategorias.length === 1 ? macroCategorias[0] : null;
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

async function resolverIdsTiposEvento() {
  const resultado = await pool.query(
    `SELECT id_tipo_evento, nombre_tipo_evento
     FROM public.tipo_evento
     WHERE nombre_tipo_evento = ANY($1::text[]);`,
    [MACRO_CATEGORIAS]
  );
  if (
    resultado.rows.length !== MACRO_CATEGORIAS.length ||
    new Set(resultado.rows.map(row => row.nombre_tipo_evento)).size !== MACRO_CATEGORIAS.length
  ) {
    throw new Error(
      `No se encontraron exactamente las macro-categorías esperadas: ${MACRO_CATEGORIAS.join(', ')}.`
    );
  }
  return new Map(
    resultado.rows.map(row => [row.nombre_tipo_evento, row.id_tipo_evento])
  );
}

export async function ejecutarIngestaTicketmaster({
  countryCode = process.env.TICKETMASTER_COUNTRY_CODE || 'CL',
  limite = Number(process.env.TICKETMASTER_EVENT_LIMIT || 200)
} = {}) {
  console.log(`[TM Job] Consultando catálogo de Ticketmaster (${countryCode})...`);

  const nombreFuente = process.env.TICKETMASTER_SOURCE_NAME || 'ticketmaster';
  const [idFuente, idsTiposEvento, idsEventos] = await Promise.all([
    resolverIdFuente(nombreFuente),
    resolverIdsTiposEvento(),
    buscarEventosTicketmaster(countryCode, limite)
  ]);

  if (idsEventos.length === 0) {
    console.log('[TM Job] No se encontraron eventos.');
    return { total: 0, guardados: 0, omitidos: 0, errores: 0 };
  }

  console.log(`[TM Job] Se encontraron ${idsEventos.length} eventos; obteniendo detalles...`);
  const resultados = [];
  let omitidos = 0;
  const errores = [];

  for (const idExterno of idsEventos) {
    let evento;
    try {
      evento = await obtenerDetalleEventoTM(idExterno);
      const macroCategoria = resolverMacroCategoriaTicketmaster(
        evento.clasificaciones_fuente
      );
      if (!macroCategoria) {
        omitidos += 1;
        console.warn(
          `[TM OMITIDO] "${evento.nombre || idExterno}": clasificación sin macro-categoría única.`
        );
        continue;
      }

      if (!evento.fecha_inicio || !evento.comuna || !evento.id_externo || !evento.nombre) {
        omitidos += 1;
        console.warn(
          `[TM OMITIDO] "${evento.nombre || idExterno}": falta ${[
            !evento.fecha_inicio && 'fecha_inicio',
            !evento.comuna && 'comuna',
            !evento.id_externo && 'id_externo',
            !evento.nombre && 'nombre'
          ].filter(Boolean).join(', ')}.`
        );
        continue;
      }

      const resultado = await guardarEvento({
        ...evento,
        id_fuente: idFuente,
        id_tipo_evento: idsTiposEvento.get(macroCategoria)
      });
      resultados.push(resultado);
      console.log(
        `[TM ${resultado.accion}] "${evento.nombre}" [${macroCategoria}] ` +
        `(ID: ${resultado.id_evento})`
      );
    } catch (error) {
      errores.push({ idExterno, nombre: evento?.nombre, error });
      console.error(
        `[TM ERROR] "${evento?.nombre || idExterno}": ${error.message}`
      );
    }
  }

  const resumen = {
    total: idsEventos.length,
    guardados: resultados.length,
    omitidos,
    errores: errores.length
  };
  console.log(
    `[TM Job] Finalizado: ${resumen.guardados} guardados, ${resumen.omitidos} omitidos, ` +
    `${resumen.errores} errores de ${resumen.total}.`
  );

  if (errores.length > 0) {
    throw new AggregateError(
      errores.map(({ error }) => error),
      `Falló el procesamiento de ${errores.length} eventos de Ticketmaster.`
    );
  }

  return resumen;
}
