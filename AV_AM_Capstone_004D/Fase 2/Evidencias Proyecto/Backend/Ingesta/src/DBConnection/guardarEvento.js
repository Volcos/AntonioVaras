import pool from './neon_connection.js';

function validarDatosEvento(datos) {
  if (!datos || typeof datos !== 'object') {
    throw new TypeError('Los datos del evento deben ser un objeto.');
  }
  if (typeof datos.fecha_inicio !== 'string' || !Number.isFinite(Date.parse(datos.fecha_inicio))) {
    throw new TypeError('El evento requiere una fecha_inicio válida.');
  }
  if (
    datos.fecha_termino !== null &&
    datos.fecha_termino !== undefined &&
    (typeof datos.fecha_termino !== 'string' || !Number.isFinite(Date.parse(datos.fecha_termino)))
  ) {
    throw new TypeError('fecha_termino debe ser una fecha válida o null.');
  }
  if (!Number.isInteger(datos.id_tipo_evento) || datos.id_tipo_evento < 1) {
    throw new TypeError('El evento requiere un id_tipo_evento válido.');
  }
  if (
    (datos.id_comuna === null || datos.id_comuna === undefined) &&
    (typeof datos.comuna !== 'string' || !datos.comuna.trim())
  ) {
    throw new TypeError('El evento requiere id_comuna o un nombre de comuna.');
  }
  if (
    datos.id_comuna !== null &&
    datos.id_comuna !== undefined &&
    (!Number.isInteger(datos.id_comuna) || datos.id_comuna < 1)
  ) {
    throw new TypeError('id_comuna debe ser un entero positivo.');
  }
  if (
    (datos.url_pagina_compra || datos.url_compra) &&
    (!Number.isInteger(datos.id_fuente) || datos.id_fuente < 1)
  ) {
    throw new TypeError('El evento requiere un id_fuente válido para guardar su fuente.');
  }
}

async function guardarFechaFuente(client, idEvento, idEventoFuente, datos) {
  if (!datos.fecha_inicio) {
    return;
  }

  const fechaExistente = await client.query(
    `SELECT id_fecha
     FROM public.fecha_evento
     WHERE id_evento = $1 AND fecha_inicio = $2::timestamptz
     LIMIT 1;`,
    [idEvento, datos.fecha_inicio]
  );

  let idFecha;
  if (fechaExistente.rows.length > 0) {
    idFecha = fechaExistente.rows[0].id_fecha;

    if (datos.fecha_termino) {
      await client.query(
        `UPDATE public.fecha_evento
         SET fecha_termino = COALESCE(fecha_termino, $1::timestamptz)
         WHERE id_fecha = $2;`,
        [datos.fecha_termino, idFecha]
      );
    }
  } else {
    const resFecha = await client.query(
      `INSERT INTO public.fecha_evento (id_evento, fecha_inicio, fecha_termino)
       VALUES ($1, $2::timestamptz, $3::timestamptz)
       RETURNING id_fecha;`,
      [idEvento, datos.fecha_inicio, datos.fecha_termino || null]
    );
    idFecha = resFecha.rows[0].id_fecha;
  }

  await client.query(
    `INSERT INTO public.fecha_evento_fuente (id_fecha, id_evento_fuente, id_evento)
     VALUES ($1, $2, $3)
     ON CONFLICT (id_fecha, id_evento_fuente) DO NOTHING;`,
    [idFecha, idEventoFuente, idEvento]
  );
}

export async function guardarEvento(datos, { client: transactionClient } = {}) {
  validarDatosEvento(datos);
  const ownsClient = !transactionClient;
  const client = transactionClient || await pool.connect();

  try {
    if (ownsClient) {
      await client.query('BEGIN');
    }

    // =========================================================================
    // 1. VALIDACIÓN DE DUPLICADOS (Para Scrapers y APIs que traen id_externo)
    // =========================================================================
    if (datos.id_fuente && datos.id_externo) {
      // 1A. ¿Ya existe exactamente este id_externo en esta ticketera?
      const checkExacto = await client.query(
        `SELECT id_evento, id_evento_fuente FROM public.evento_fuente
         WHERE id_fuente = $1 AND id_externo = $2 LIMIT 1;`,
        [datos.id_fuente, datos.id_externo]
      );

      if (checkExacto.rows.length > 0) {
        await client.query(
          `UPDATE public.evento_fuente
           SET url_compra = $1, fecha_sincronizacion = CURRENT_TIMESTAMP
           WHERE id_fuente = $2 AND id_externo = $3;`,
          [datos.url_pagina_compra || datos.url_compra, datos.id_fuente, datos.id_externo]
        );
        await client.query(
          `UPDATE public.evento
           SET id_tipo_evento = $1
           WHERE id_evento = $2;`,
          [datos.id_tipo_evento, checkExacto.rows[0].id_evento]
        );
        await guardarFechaFuente(
          client,
          checkExacto.rows[0].id_evento,
          checkExacto.rows[0].id_evento_fuente,
          datos
        );
        if (ownsClient) {
          await client.query('COMMIT');
        }
        return { accion: 'ACTUALIZADO', id_evento: checkExacto.rows[0].id_evento };
      }

      // 1B. ¿OTRA fuente distinta ya subió este mismo evento en la misma fecha?
      if (datos.fecha_inicio) {
        const checkSimilar = await client.query(
          `SELECT e.id_evento, similarity(e.nombre, $1) AS score
           FROM public.evento e
           INNER JOIN public.fecha_evento fe ON fe.id_evento = e.id_evento
           WHERE (fe.fecha_inicio AT TIME ZONE 'America/Santiago')::date
                 = ($2::timestamptz AT TIME ZONE 'America/Santiago')::date
             AND similarity(e.nombre, $1) > 0.65
             AND NOT EXISTS (
               SELECT 1 FROM public.evento_fuente ef
               WHERE ef.id_evento = e.id_evento AND ef.id_fuente = $3
             )
           ORDER BY score DESC
           LIMIT 1;`,
          [datos.nombre, datos.fecha_inicio, datos.id_fuente]
        );

        if (checkSimilar.rows.length > 0) {
          const idExistente = checkSimilar.rows[0].id_evento;
          const resEventoFuente = await client.query(
            `INSERT INTO public.evento_fuente (id_evento, id_fuente, id_externo, url_compra)
             VALUES ($1, $2, $3, $4)
             RETURNING id_evento_fuente;`,
            [
              idExistente,
              datos.id_fuente,
              datos.id_externo,
              datos.url_pagina_compra || datos.url_compra
            ]
          );
          await guardarFechaFuente(
            client,
            idExistente,
            resEventoFuente.rows[0].id_evento_fuente,
            datos
          );

          if (ownsClient) {
            await client.query('COMMIT');
          }
          return { accion: 'VINCULADO_A_EXISTENTE', id_evento: idExistente };
        }
      }
    }

    // =========================================================================
    // 2. RESOLVER EL ID DE LA COMUNA (Acepta id_comuna numérico o el nombre en texto)
    // =========================================================================
    let idComuna = datos.id_comuna;

    if (idComuna === null || idComuna === undefined) {
      const resComuna = await client.query(
        `SELECT id_comuna FROM public.comuna WHERE LOWER(nombre_comuna) = LOWER($1) LIMIT 1;`,
        [datos.comuna.trim()]
      );
      if (resComuna.rows.length === 0) {
        throw new Error(`No se encontró la comuna "${datos.comuna}" en la base de datos.`);
      }
      idComuna = resComuna.rows[0].id_comuna;
    }

    // =========================================================================
    // 3. INSERTAR EN TABLA `evento`
    // =========================================================================
    const resEvento = await client.query(
      `INSERT INTO public.evento (
        nombre, descripcion, direccion, imagen_url, id_comuna, id_tipo_evento, latitud, longitud, organizador
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING id_evento;`,
      [
        datos.nombre.slice(0, 150),
        datos.descripcion || null,
        (datos.direccion || 'Por definir').slice(0, 200),
        datos.imagen_url || null,
        idComuna,
        datos.id_tipo_evento,
        datos.latitud,
        datos.longitud,
        datos.organizador ? datos.organizador.slice(0, 150) : null
      ]
    );

    const nuevoIdEvento = resEvento.rows[0].id_evento;

    // =========================================================================
    // 4. INSERTAR EN TABLA `fecha_evento`
    // =========================================================================
    await client.query(
      `INSERT INTO public.fecha_evento (id_evento, fecha_inicio, fecha_termino, precio_desde)
       VALUES ($1, $2, $3, $4);`,
      [
        nuevoIdEvento,
        datos.fecha_inicio,
        datos.fecha_termino || null,
        datos.precio_desde || null
      ]
    );

    // =========================================================================
    // 5. INSERTAR EN TABLA `evento_fuente`
    // =========================================================================
    const urlCompra = datos.url_pagina_compra || datos.url_compra;
    if (urlCompra) {
      const resEventoFuente = await client.query(
        `INSERT INTO public.evento_fuente (id_evento, id_fuente, id_externo, url_compra)
         VALUES ($1, $2, $3, $4)
         RETURNING id_evento_fuente;`,
        [
          nuevoIdEvento,
          datos.id_fuente,
          datos.id_externo || `manual-${nuevoIdEvento}`,
          urlCompra.slice(0, 300)
        ]
      );
      await guardarFechaFuente(
        client,
        nuevoIdEvento,
        resEventoFuente.rows[0].id_evento_fuente,
        datos
      );
    }

    if (ownsClient) {
      await client.query('COMMIT');
    }
    return { accion: 'CREADO_NUEVO', id_evento: nuevoIdEvento };

  } catch (error) {
    if (ownsClient) {
      await client.query('ROLLBACK');
    }
    console.error(`Error guardando "${datos.nombre}":`, error.message);
    throw error;
  } finally {
    if (ownsClient) {
      client.release();
    }
  }
}