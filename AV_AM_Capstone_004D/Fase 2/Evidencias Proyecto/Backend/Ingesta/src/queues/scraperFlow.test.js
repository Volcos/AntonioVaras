import assert from 'node:assert/strict';
import { test } from 'node:test';
import { resolverMacroCategoriaPuntoTicket } from './scraperFlow.js';

test('resuelve una macro-categoría única reconocida', () => {
  assert.equal(
    resolverMacroCategoriaPuntoTicket([
      { macro_categoria: 'Música', etiqueta: 'Rock' }
    ]),
    1
  );
});

test('deduplica clasificaciones iguales y no considera etiquetas de tarjeta', () => {
  assert.equal(
    resolverMacroCategoriaPuntoTicket([
      { macro_categoria: 'Deportes', etiqueta: 'Fútbol' },
      { macro_categoria: 'Deportes', etiqueta: 'Fútbol' },
      { etiqueta: 'Fútbol' }
    ]),
    3
  );
});

test('usa el fallback especial para clasificaciones ausentes o ambiguas', () => {
  assert.equal(resolverMacroCategoriaPuntoTicket(), 6);
  assert.equal(resolverMacroCategoriaPuntoTicket([{ etiqueta: 'Festival' }]), 6);
  assert.equal(
    resolverMacroCategoriaPuntoTicket([
      { macro_categoria: 'Música' },
      { macro_categoria: 'Teatro' }
    ]),
    1
  );
  assert.equal(
    resolverMacroCategoriaPuntoTicket([{ macro_categoria: 'Especiales' }]),
    6
  );
});
