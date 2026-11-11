import assert from 'node:assert/strict';
import { test } from 'node:test';
import { resolverMacroCategoriaPuntoTicket } from './scraperFlow.js';

test('resuelve una macro-categoría única reconocida', () => {
  assert.equal(
    resolverMacroCategoriaPuntoTicket([
      { macro_categoria: 'Música', etiqueta: 'Rock' }
    ]),
    'Música'
  );
});

test('deduplica clasificaciones iguales y no considera etiquetas de tarjeta', () => {
  assert.equal(
    resolverMacroCategoriaPuntoTicket([
      { macro_categoria: 'Deportes', etiqueta: 'Fútbol' },
      { macro_categoria: 'Deportes', etiqueta: 'Fútbol' },
      { etiqueta: 'Fútbol' }
    ]),
    'Deportes'
  );
});

test('rechaza clasificaciones ausentes, ambiguas o fuera de las macro-categorías', () => {
  assert.equal(resolverMacroCategoriaPuntoTicket(), null);
  assert.equal(resolverMacroCategoriaPuntoTicket([{ etiqueta: 'Festival' }]), null);
  assert.equal(
    resolverMacroCategoriaPuntoTicket([
      { macro_categoria: 'Música' },
      { macro_categoria: 'Teatro' }
    ]),
    null
  );
  assert.equal(
    resolverMacroCategoriaPuntoTicket([{ macro_categoria: 'Especiales' }]),
    null
  );
});
