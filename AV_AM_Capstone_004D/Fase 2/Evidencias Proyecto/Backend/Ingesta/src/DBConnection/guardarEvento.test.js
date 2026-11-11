import assert from 'node:assert/strict';
import { test } from 'node:test';
import { guardarEvento } from './guardarEvento.js';

test('rechaza fecha_inicio nula antes de intentar conectar a la base', async () => {
  await assert.rejects(
    guardarEvento({ fecha_inicio: null }),
    {
      name: 'TypeError',
      message: 'El evento requiere una fecha_inicio válida.'
    }
  );
});

test('rechaza fecha_inicio inválida antes de intentar conectar a la base', async () => {
  await assert.rejects(
    guardarEvento({ fecha_inicio: 'no-es-una-fecha' }),
    {
      name: 'TypeError',
      message: 'El evento requiere una fecha_inicio válida.'
    }
  );
});

test('acepta fecha_termino nula y continúa con las demás validaciones', async () => {
  await assert.rejects(
    guardarEvento({
      fecha_inicio: '2026-11-08T15:00:00-03:00',
      fecha_termino: null
    }),
    {
      name: 'TypeError',
      message: 'El evento requiere un id_tipo_evento válido.'
    }
  );
});

test('actualiza el tipo del evento al sincronizar una fuente ya existente', async () => {
  const consultas = [];
  const client = {
    async query(sql, parametros = []) {
      consultas.push({ sql, parametros });
      if (sql.includes('SELECT id_evento, id_evento_fuente')) {
        return { rows: [{ id_evento: 5, id_evento_fuente: 9 }] };
      }
      if (sql.includes('SELECT id_fecha')) {
        return { rows: [{ id_fecha: 12 }] };
      }
      return { rows: [], rowCount: 1 };
    }
  };

  const resultado = await guardarEvento({
    nombre: 'Evento de prueba',
    fecha_inicio: '2026-11-08T15:00:00-03:00',
    fecha_termino: null,
    id_tipo_evento: 4,
    id_comuna: 1,
    id_fuente: 2,
    id_externo: 'EVT123',
    url_pagina_compra: 'https://example.com/evento'
  }, { client });

  assert.deepEqual(resultado, { accion: 'ACTUALIZADO', id_evento: 5 });
  assert.ok(
    consultas.some(
      ({ sql, parametros }) =>
        sql.includes('UPDATE public.evento') &&
        sql.includes('SET id_tipo_evento = $1') &&
        parametros[0] === 4 &&
        parametros[1] === 5
    )
  );
});
