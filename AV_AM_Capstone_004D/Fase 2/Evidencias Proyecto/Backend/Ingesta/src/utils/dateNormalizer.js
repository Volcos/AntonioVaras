const MESES = {
  enero: 1,
  febrero: 2,
  marzo: 3,
  abril: 4,
  mayo: 5,
  junio: 6,
  julio: 7,
  agosto: 8,
  septiembre: 9,
  setiembre: 9,
  octubre: 10,
  noviembre: 11,
  diciembre: 12
};

const formatoOffsetSantiago = new Intl.DateTimeFormat('en', {
  timeZone: 'America/Santiago',
  timeZoneName: 'shortOffset'
});

function crearFechaValida(dia, mes, anio, hora = 0, minuto = 0) {
  const fecha = new Date(Date.UTC(anio, mes - 1, dia, hora, minuto));
  if (
    fecha.getUTCFullYear() !== anio ||
    fecha.getUTCMonth() !== mes - 1 ||
    fecha.getUTCDate() !== dia
  ) {
    return null;
  }

  const offsetTexto = formatoOffsetSantiago
    .formatToParts(fecha)
    .find(parte => parte.type === 'timeZoneName')?.value;
  const offset = offsetTexto?.match(/^GMT([+-])(\d{1,2})(?::(\d{2}))?$/);
  if (!offset) {
    throw new Error(`No se pudo determinar el huso horario para ${offsetTexto}`);
  }

  const horasOffset = offset[2].padStart(2, '0');
  const minutosOffset = (offset[3] || '00').padStart(2, '0');
  const signoOffset = offset[1];

  return `${String(anio).padStart(4, '0')}-${String(mes).padStart(2, '0')}-${String(dia).padStart(2, '0')}T${String(hora).padStart(2, '0')}:${String(minuto).padStart(2, '0')}:00${signoOffset}${horasOffset}:${minutosOffset}`;
}

function interpretarFecha(texto) {
  const fechaNumerica = texto.match(/^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})$/);
  if (fechaNumerica) {
    let anio = Number(fechaNumerica[3]);
    if (anio < 100) {
      anio += 2000;
    }

    return {
      dia: Number(fechaNumerica[1]),
      mes: Number(fechaNumerica[2]),
      anio
    };
  }

  const fechaEnEspanol = texto.match(/^(\d{1,2})\s+de\s+([a-z]+)(?:\s+de\s+(\d{4}))?$/);
  if (!fechaEnEspanol) {
    return null;
  }

  const mes = MESES[fechaEnEspanol[2]];
  if (!mes) {
    return null;
  }

  return {
    dia: Number(fechaEnEspanol[1]),
    mes,
    anio: fechaEnEspanol[3] ? Number(fechaEnEspanol[3]) : null
  };
}

export function normalizarFechasPuntoTicket(fechaHora) {
  if (typeof fechaHora !== 'string' || !fechaHora.trim()) {
    return { fecha_inicio: null, fecha_termino: null };
  }

  const texto = fechaHora
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
  const fechas = [];
  const fechasNumericas = [...texto.matchAll(/\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b/g)];

  if (fechasNumericas.length > 0) {
    fechas.push(...fechasNumericas.slice(0, 2).map(match => interpretarFecha(match[0])));
  } else {
    const rangoEnEspanol = texto.match(
      /(?:desde\s+el\s+)?(\d{1,2})(?:\s+de\s+([a-z]+))?\s+(?:al|hasta)\s+(\d{1,2})(?:\s+de\s+([a-z]+))?(?:\s+de\s+(\d{4}))?/
    );

    if (rangoEnEspanol) {
      const mesInicio = MESES[rangoEnEspanol[2] || rangoEnEspanol[4]];
      const mesTermino = MESES[rangoEnEspanol[4] || rangoEnEspanol[2]];
      const anioExplicito = rangoEnEspanol[5]
        ? Number(rangoEnEspanol[5])
        : null;
      const anioActual = Number(
        new Intl.DateTimeFormat('en', {
          timeZone: 'America/Santiago',
          year: 'numeric'
        }).format(new Date())
      );

      if (mesInicio && mesTermino) {
        const anioInicio = anioExplicito || anioActual;
        const anioTermino =
          anioExplicito ||
          (mesTermino < mesInicio ||
          (mesTermino === mesInicio &&
            Number(rangoEnEspanol[3]) < Number(rangoEnEspanol[1]))
            ? anioInicio + 1
            : anioInicio);

        fechas.push(
          {
            dia: Number(rangoEnEspanol[1]),
            mes: mesInicio,
            anio: anioInicio
          },
          {
            dia: Number(rangoEnEspanol[3]),
            mes: mesTermino,
            anio: anioTermino
          }
        );
      }
    } else {
      const fechaSuelta = texto.match(/\b(\d{1,2})\s+de\s+([a-z]+)(?:\s+de\s+(\d{4}))?\b/);
      if (fechaSuelta && MESES[fechaSuelta[2]]) {
        fechas.push({
          dia: Number(fechaSuelta[1]),
          mes: MESES[fechaSuelta[2]],
          anio: fechaSuelta[3]
            ? Number(fechaSuelta[3])
            : Number(
                new Intl.DateTimeFormat('en', {
                  timeZone: 'America/Santiago',
                  year: 'numeric'
                }).format(new Date())
              )
        });
      }
    }
  }

  if (fechas.length === 0 || fechas[0] === null) {
    return { fecha_inicio: null, fecha_termino: null };
  }

  const horas = [...texto.matchAll(/\b([01]?\d|2[0-3]):([0-5]\d)\b/g)];
  const horaInicio = horas[0]
    ? { hora: Number(horas[0][1]), minuto: Number(horas[0][2]) }
    : { hora: 0, minuto: 0 };
  const horaTermino = horas.length > 1
    ? { hora: Number(horas[horas.length - 1][1]), minuto: Number(horas[horas.length - 1][2]) }
    : horaInicio;

  const fechaInicio = crearFechaValida(
    fechas[0].dia,
    fechas[0].mes,
    fechas[0].anio,
    horaInicio.hora,
    horaInicio.minuto
  );
  const fechaTermino = fechaInicio && fechas[1]
    ? crearFechaValida(
        fechas[1].dia,
        fechas[1].mes,
        fechas[1].anio,
        horaTermino.hora,
        horaTermino.minuto
      )
    : null;

  return {
    fecha_inicio: fechaInicio,
    fecha_termino: fechaInicio ? fechaTermino : null
  };
}
