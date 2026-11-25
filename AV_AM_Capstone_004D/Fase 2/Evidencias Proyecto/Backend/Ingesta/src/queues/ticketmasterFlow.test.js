import assert from 'node:assert/strict';
import { test } from 'node:test';
import { resolverMacroCategoriaTicketmaster } from './ticketmasterFlow.js';

test('resuelve una macro-categoría única de Ticketmaster', () => {
  assert.equal(
    resolverMacroCategoriaTicketmaster([{ macro_categoria: 'Música' }]),
    1
  );
});

test('deduplica la misma macro-categoría', () => {
  assert.equal(
    resolverMacroCategoriaTicketmaster([
      { macro_categoria: 'Deportes' },
      { macro_categoria: 'Deportes' }
    ]),
    3
  );
});

test('usa el fallback especial para clasificaciones ausentes o ambiguas', () => {
  assert.equal(resolverMacroCategoriaTicketmaster(), 6);
  assert.equal(resolverMacroCategoriaTicketmaster([]), 6);
  assert.equal(
    resolverMacroCategoriaTicketmaster([
      { macro_categoria: 'Música' },
      { macro_categoria: 'Teatro' }
    ]),
    1
  );
  assert.equal(
    resolverMacroCategoriaTicketmaster([{ macro_categoria: 'Festival' }]),
    1
  );
});
