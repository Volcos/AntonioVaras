import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  limpiarTexto,
  resolverIdTipoEvento
} from './categoryNormalizer.js';

test('limpia mayúsculas, tildes y espacios', () => {
  assert.equal(limpiarTexto('  MÚSICA  '), 'musica');
  assert.equal(limpiarTexto(' Deportes '), 'deportes');
});

test('resuelve categorías desde clasificaciones y campos directos', () => {
  assert.equal(resolverIdTipoEvento({
    clasificaciones_fuente: [{ macro_categoria: 'Rock' }]
  }), 1);
  assert.equal(resolverIdTipoEvento({
    segmento: 'Arts & Theatre'
  }), 2);
  assert.equal(resolverIdTipoEvento({
    categoria: 'Familia'
  }), 4);
});

test('infiere categoría desde el nombre y usa Especiales como fallback', () => {
  assert.equal(resolverIdTipoEvento({ nombre: 'Festival de verano' }), 1);
  assert.equal(resolverIdTipoEvento({ nombre: 'Stand Up Nacional' }), 2);
  assert.equal(resolverIdTipoEvento({ nombre: 'Copa regional' }), 3);
  assert.equal(resolverIdTipoEvento({ nombre: 'Circo infantil' }), 4);
  assert.equal(resolverIdTipoEvento({ nombre: 'Encuentro sin categoría' }), 6);
});
