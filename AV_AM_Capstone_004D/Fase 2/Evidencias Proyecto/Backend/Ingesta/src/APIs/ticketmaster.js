import 'dotenv/config';

const BASE_URL = 'https://app.ticketmaster.com/discovery/v2';
const MACRO_CATEGORIAS = new Map([
  ['music', 'Música'],
  ['sports', 'Deportes'],
  ['family', 'Familia']
]);

function obtenerMacroCategoria(clasificacion) {
  const familia = clasificacion?.family?.name?.trim().toLocaleLowerCase('en');
  const macroFamilia = MACRO_CATEGORIAS.get(familia);
  if (macroFamilia) {
    return macroFamilia;
  }

  const segmento = clasificacion?.segment?.name?.trim().toLocaleLowerCase('en');
  if (segmento === 'arts & theatre') {
    const tipo = clasificacion.type?.name?.trim().toLocaleLowerCase('en');
    const genero = clasificacion.genre?.name?.trim().toLocaleLowerCase('en');
    return tipo === 'theatre' || genero === 'theatre' ? 'Teatro' : null;
  }

  return MACRO_CATEGORIAS.get(segmento) || null;
}

function normalizarFechaInicio(evento) {
  const inicio = evento.dates?.start;
  if (inicio?.dateTime && Number.isFinite(Date.parse(inicio.dateTime))) {
    return inicio.dateTime;
  }
  if (!inicio?.localDate || !/^\d{4}-\d{2}-\d{2}$/.test(inicio.localDate)) {
    return null;
  }

  const hora = inicio.localTime && /^\d{2}:\d{2}(:\d{2})?$/.test(inicio.localTime)
    ? inicio.localTime
    : '00:00:00';
  const zonaHoraria =
    evento.dates?.timezone ||
    evento._embedded?.venues?.[0]?.timezone ||
    (evento._embedded?.venues?.[0]?.country?.countryCode === 'CL'
      ? 'America/Santiago'
      : null);
  if (!zonaHoraria) {
    return null;
  }

  const [anio, mes, dia] = inicio.localDate.split('-').map(Number);
  const [horaLocal, minutoLocal, segundoLocal = '00'] = hora.split(':');
  const fechaReferencia = new Date(Date.UTC(anio, mes - 1, dia, 12));
  const offsetTexto = new Intl.DateTimeFormat('en', {
    timeZone: zonaHoraria,
    timeZoneName: 'shortOffset'
  })
    .formatToParts(fechaReferencia)
    .find(parte => parte.type === 'timeZoneName')?.value;
  const offset = offsetTexto?.match(/^GMT([+-])(\d{1,2})(?::(\d{2}))?$/);
  if (!offset) {
    throw new Error(`No se pudo determinar el huso horario de Ticketmaster: ${zonaHoraria}`);
  }

  return `${inicio.localDate}T${horaLocal}:${minutoLocal}:${segundoLocal}${offset[1]}${offset[2].padStart(2, '0')}:${(offset[3] || '00').padStart(2, '0')}`;
}

function obtenerCoordenada(valor) {
  if (valor === undefined || valor === null || valor === '') {
    return null;
  }
  const coordenada = Number(valor);
  return Number.isFinite(coordenada) ? coordenada : null;
}

export function normalizarEventoTicketmaster(evento) {
  const recinto = evento._embedded?.venues?.[0] || {};
  const clasificaciones = evento.classifications || [];
  const macroCategorias = [
    ...new Set(
      clasificaciones
        .map(obtenerMacroCategoria)
        .filter(Boolean)
    )
  ];
  const lineasDireccion = [
    recinto.name,
    recinto.address?.line1,
    recinto.city?.name,
    recinto.state?.name,
    recinto.country?.countryCode
  ].filter(Boolean);

  return {
    id_externo: evento.id || null,
    nombre: evento.name || null,
    descripcion: evento.info || evento.pleaseNote || '',
    fecha_inicio: normalizarFechaInicio(evento),
    fecha_termino: null,
    imagen_url:
      evento.images?.find(imagen => imagen.ratio === '16_9')?.url ||
      evento.images?.[0]?.url ||
      null,
    url_pagina_compra: evento.url || null,
    direccion: lineasDireccion.join(' - ') || null,
    comuna: recinto.city?.name || null,
    latitud: obtenerCoordenada(recinto.location?.latitude),
    longitud: obtenerCoordenada(recinto.location?.longitude),
    organizador: evento.promoters?.[0]?.name || evento.promoter?.name || null,
    clasificaciones_fuente: macroCategorias.map(macro_categoria => ({ macro_categoria }))
  };
}

function obtenerApiKey() {
  const apiKey = process.env.TICKETMASTER_API_KEY;
  if (!apiKey) {
    throw new Error('Falta configurar TICKETMASTER_API_KEY.');
  }
  return apiKey;
}

/**
 * Devuelve los IDs de eventos de un país para procesar sus detalles.
 */
export async function buscarEventosTicketmaster(countryCode = 'CL', limite = 20) {
  const codigoPais = String(countryCode).trim().toUpperCase();
  const tamanoPagina = Number(limite);
  if (!/^[A-Z]{2}$/.test(codigoPais)) {
    throw new TypeError('countryCode debe ser un código ISO de dos letras.');
  }
  if (!Number.isInteger(tamanoPagina) || tamanoPagina < 1 || tamanoPagina > 200) {
    throw new RangeError('limite debe ser un entero entre 1 y 200.');
  }

  const url = new URL(`${BASE_URL}/events.json`);
  url.searchParams.set('apikey', obtenerApiKey());
  url.searchParams.set('countryCode', codigoPais);
  url.searchParams.set('size', String(tamanoPagina));

  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Ticketmaster API error: ${res.status} ${res.statusText}`);
  }

  const data = await res.json();
  const eventosRaw = data._embedded?.events || [];
  return [...new Set(eventosRaw.map(evento => evento.id).filter(Boolean))];
}

/**
 * Obtiene y normaliza el detalle de un evento al formato común de ingesta.
 */
export async function obtenerDetalleEventoTM(eventId) {
  if (typeof eventId !== 'string' || !eventId.trim()) {
    throw new TypeError('eventId debe ser un identificador no vacío.');
  }

  const url = new URL(`${BASE_URL}/events/${encodeURIComponent(eventId)}.json`);
  url.searchParams.set('apikey', obtenerApiKey());

  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Error al obtener evento TM ${eventId}: ${res.status} ${res.statusText}`);
  }

  return normalizarEventoTicketmaster(await res.json());
}
