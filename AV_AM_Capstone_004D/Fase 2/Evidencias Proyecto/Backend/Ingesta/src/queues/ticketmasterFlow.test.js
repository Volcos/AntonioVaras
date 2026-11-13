import assert from 'node:assert/strict';
import { test } from 'node:test';
import { resolverMacroCategoriaTicketmaster } from './ticketmasterFlow.js';

test('resuelve una macro-categoría única de Ticketmaster', () => {
  assert.equal(
    resolverMacroCategoriaTicketmaster([{ macro_categoria: 'Música' }]),
    'Música'
  );
});

test('deduplica la misma macro-categoría', () => {
  assert.equal(
    resolverMacroCategoriaTicketmaster([
      { macro_categoria: 'Deportes' },
      { macro_categoria: 'Deportes' }
    ]),
    'Deportes'
  );
});

test('rechaza clasificaciones ausentes, ambiguas o desconocidas', () => {
  assert.equal(resolverMacroCategoriaTicketmaster(), null);
  assert.equal(resolverMacroCategoriaTicketmaster([]), null);
  assert.equal(
    resolverMacroCategoriaTicketmaster([
      { macro_categoria: 'Música' },
      { macro_categoria: 'Teatro' }
    ]),
    null
  );
  assert.equal(
    resolverMacroCategoriaTicketmaster([{ macro_categoria: 'Festival' }]),
    null
  );
});
