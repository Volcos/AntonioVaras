export const MAPA_CATEGORIAS = {
  musica: 1,
  music: 1,
  concierto: 1,
  festival: 1,
  recital: 1,
  fiesta: 1,
  electronica: 1,
  rock: 1,
  pop: 1,
  urbano: 1,
  teatro: 2,
  theatre: 2,
  arts: 2,
  'arts & theatre': 2,
  comedia: 2,
  'stand up': 2,
  'stand-up': 2,
  danza: 2,
  musical: 2,
  obra: 2,
  deportes: 3,
  sports: 3,
  futbol: 3,
  tenis: 3,
  running: 3,
  maraton: 3,
  torneo: 3,
  competencia: 3,
  familia: 4,
  family: 4,
  infantil: 4,
  circo: 4,
  exposicion: 4,
  ninos: 4,
  museo: 4,
  especiales: 6,
  miscellaneous: 6,
  charlas: 6,
  conferencia: 6,
  feria: 6,
  cultura: 6,
  otros: 6,
  otro: 6
};

export function limpiarTexto(texto) {
  if (typeof texto !== 'string') {
    return '';
  }
  return texto
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

export function resolverIdTipoEvento(evento = {}) {
  const candidatos = [];

  if (Array.isArray(evento.clasificaciones_fuente)) {
    for (const clasificacion of evento.clasificaciones_fuente) {
      if (clasificacion?.macro_categoria) {
        candidatos.push(clasificacion.macro_categoria);
      }
      if (clasificacion?.subcategoria) {
        candidatos.push(clasificacion.subcategoria);
      }
    }
  }

  if (evento.categoria) candidatos.push(evento.categoria);
  if (evento.segmento) candidatos.push(evento.segmento);

  for (const candidato of candidatos) {
    const texto = limpiarTexto(candidato);
    if (MAPA_CATEGORIAS[texto]) {
      return MAPA_CATEGORIAS[texto];
    }
  }

  const nombre = limpiarTexto(evento.nombre);
  if (/\b(concierto|concert|festival|fest|recital|rock|pop)\b/i.test(nombre)) return 1;
  if (/\b(stand\s*up|obra|teatro|theatre|comedia|danza|musical)\b/i.test(nombre)) return 2;
  if (/\b(torneo|copa|vs|deportes|futbol|tenis|running|maraton)\b/i.test(nombre)) return 3;
  if (/\b(circo|infantil|familiar|familia|ninos|museo)\b/i.test(nombre)) return 4;

  return 6;
}
