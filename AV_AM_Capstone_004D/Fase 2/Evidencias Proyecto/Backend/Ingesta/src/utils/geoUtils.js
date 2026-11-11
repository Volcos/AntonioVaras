const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const RECINTOS_CONOCIDOS = {
  'club amanda': { latitud: -33.38315, longitud: -70.56942 },
  'freedom': { latitud: -33.43106, longitud: -70.63825 },
  'movistar arena': { latitud: -33.46268, longitud: -70.66069 },
  'teatro caupolican': { latitud: -33.45694, longitud: -70.64827 },
  'claro arena': { latitud: -33.39583, longitud: -70.50056 },
  'estadio nacional': { latitud: -33.46444, longitud: -70.61056 }
};

export function extraerLugarDesdeUrl(url) {
  const match = url.match(/\/evento\/([^/?#]+)/i);
  if (!match) {
    return null;
  }

  const slugLimpio = match[1].replace(
    /-(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)-\d{4}$/i,
    ''
  );
  const partes = slugLimpio.split('-');
  const palabrasRecinto = new Set([
    'teatro',
    'estadio',
    'movistar',
    'arena',
    'club',
    'centro',
    'caupolican',
    'fortin'
  ]);
  const indiceRecinto = partes.findIndex(parte => palabrasRecinto.has(parte.toLowerCase()));

  if (indiceRecinto === -1) {
    return null;
  }

  return partes
    .slice(indiceRecinto)
    .map(parte => parte.charAt(0).toUpperCase() + parte.slice(1).toLowerCase())
    .join(' ');
}

export async function extraerCoordenadasGooGl(urlCorta) {
  if (!urlCorta) return { latitud: null, longitud: null };

  try {
    const respuesta = await fetch(urlCorta, {
      headers: { 'User-Agent': USER_AGENT },
      redirect: 'follow'
    });

    const urlLarga = respuesta.url;

    const matchPin = urlLarga.match(/!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)/);
    if (matchPin) {
      return {
        latitud: parseFloat(matchPin[1]),
        longitud: parseFloat(matchPin[2])
      };
    }

    const matchAt = urlLarga.match(/[@q=](-?\d+\.\d+),(-?\d+\.\d+)/);
    if (matchAt) {
      return {
        latitud: parseFloat(matchAt[1]),
        longitud: parseFloat(matchAt[2])
      };
    }

    const html = await respuesta.text();
    const matchHtml = html.match(/\[null,null,(-?\d+\.\d+),(-?\d+\.\d+)\]/);
    if (matchHtml) {
      return {
        latitud: parseFloat(matchHtml[1]),
        longitud: parseFloat(matchHtml[2])
      };
    }

    return { latitud: null, longitud: null };
  } catch (error) {
    console.error('Error al resolver link corto de Maps:', error.message);
    return { latitud: null, longitud: null };
  }
}

export async function geocodificarPorLugar(lugar) {
  if (!lugar) return { latitud: null, longitud: null };

  const lugarLower = lugar
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s*-\s*/g, ', ');

  for (const [clave, coords] of Object.entries(RECINTOS_CONOCIDOS)) {
    if (lugarLower.includes(clave)) {
      return coords;
    }
  }

  try {
    const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(`${lugarLower}, Chile`)}&format=json&limit=1`;
    const res = await fetch(url, {
      headers: { 'User-Agent': 'PanoraMapp-Scraper/1.0' }
    });
    const data = await res.json();
    if (Array.isArray(data) && data.length > 0) {
      return {
        latitud: parseFloat(data[0].lat),
        longitud: parseFloat(data[0].lon)
      };
    }

    if (lugar.includes('-')) {
      const comuna = lugar.split('-').pop().trim();
      const urlComuna = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(comuna + ', Chile')}&format=json&limit=1`;
      const resComuna = await fetch(urlComuna, {
        headers: { 'User-Agent': 'PanoraMapp-Scraper/1.0' }
      });
      const dataComuna = await resComuna.json();

      if (Array.isArray(dataComuna) && dataComuna.length > 0) {
        return {
          latitud: parseFloat(dataComuna[0].lat),
          longitud: parseFloat(dataComuna[0].lon)
        };
      }
    }
  } catch (error) {
    console.error(`Error geocodificando "${lugar}":`, error.message);
  }

  return { latitud: null, longitud: null };
}
