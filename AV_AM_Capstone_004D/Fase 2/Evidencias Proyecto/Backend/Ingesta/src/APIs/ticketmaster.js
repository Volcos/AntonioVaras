// src/APIs/ticketmaster.js

import 'dotenv/config';

const TM_API_KEY = process.env.TICKETMASTER_API_KEY;
const BASE_URL = 'https://app.ticketmaster.com/discovery/v2';

/**
 * Consulta la lista de eventos en Ticketmaster filtrados por país
 */
export async function buscarEventosTicketmaster(countryCode = 'CL', size = 20) {
  const url = `${BASE_URL}/events.json?apikey=${TM_API_KEY}&countryCode=${countryCode}&size=${size}`;
  
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Ticketmaster API error: ${res.status} ${res.statusText}`);
  }

  const data = await res.json();
  const eventosRaw = data._embedded?.events || [];

  // Retornamos los IDs de los eventos para generar los jobs hijos
  return eventosRaw.map(e => e.id);
}

/**
 * Obtiene el detalle de un evento por su ID y normaliza los campos
 */
export async function obtenerDetalleEventoTM(eventId) {
  const url = `${BASE_URL}/events/${eventId}.json?apikey=${TM_API_KEY}`;
  
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Error al obtener evento TM ${eventId}: ${res.statusText}`);
  }

  const e = await res.json();
  
  // Mapeo unificado de campos (similar al que genera metascraper)
  return {
    source: 'ticketmaster',
    id: e.id,
    title: e.name,
    description: e.info || e.pleaseNote || '',
    date: e.dates?.start?.dateTime || e.dates?.start?.localDate || null,
    image: e.images?.find(img => img.ratio === '16_9')?.url || e.images?.[0]?.url || null,
    url: e.url,
    venue: e._embedded?.venues?.[0]?.name || null,
    city: e._embedded?.venues?.[0]?.city?.name || null
  };
}