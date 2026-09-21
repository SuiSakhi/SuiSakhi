'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  parseCatalogueOriginalPath,
} = require('../catalogue_path');

const VALID_PATH =
  'catalogue_designs/design-123/' +
  'versions/version-456/' +
  'views/view-789/' +
  'original/source.jpg';

test('parses a valid multi-view JPEG original', () => {
  const parsed = parseCatalogueOriginalPath(VALID_PATH);

  assert.ok(parsed);
  assert.equal(parsed.designId, 'design-123');
  assert.equal(parsed.versionId, 'version-456');
  assert.equal(parsed.viewId, 'view-789');
  assert.equal(parsed.extension, 'jpg');

  assert.equal(
    parsed.normalizedPath,
    'catalogue_designs/design-123/' +
      'versions/version-456/' +
      'views/view-789/' +
      'normalized/preview.webp',
  );

  assert.equal(
    parsed.thumbnailPath,
    'catalogue_designs/design-123/' +
      'versions/version-456/' +
      'views/view-789/' +
      'thumbnails/card.webp',
  );

  assert.equal(
    parsed.manifestPath,
    'catalogue_designs/design-123/' +
      'versions/version-456/' +
      'views/view-789/' +
      'structured/manifest.json',
  );

  assert.equal(
    parsed.firestoreViewPath,
    'designs/design-123/' +
      'versions/version-456/' +
      'views/view-789',
  );
});

test('accepts supported extensions case-insensitively', () => {
  for (const extension of [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'JPG',
    'PNG',
  ]) {
    const parsed = parseCatalogueOriginalPath(
      VALID_PATH.replace('source.jpg', `source.${extension}`),
    );

    assert.ok(parsed, `Expected ${extension} to be accepted`);
    assert.equal(parsed.extension, extension.toLowerCase());
  }
});

test('rejects a normalized derivative', () => {
  assert.equal(
    parseCatalogueOriginalPath(
      'catalogue_designs/design-123/' +
        'versions/version-456/' +
        'views/view-789/' +
        'normalized/preview.webp',
    ),
    null,
  );
});

test('rejects a thumbnail derivative', () => {
  assert.equal(
    parseCatalogueOriginalPath(
      'catalogue_designs/design-123/' +
        'versions/version-456/' +
        'views/view-789/' +
        'thumbnails/card.webp',
    ),
    null,
  );
});

test('rejects a manifest derivative', () => {
  assert.equal(
    parseCatalogueOriginalPath(
      'catalogue_designs/design-123/' +
        'versions/version-456/' +
        'views/view-789/' +
        'structured/manifest.json',
    ),
    null,
  );
});

test('rejects the legacy single-view original path', () => {
  assert.equal(
    parseCatalogueOriginalPath(
      'catalogue_designs/design-123/' +
        'versions/version-456/' +
        'original/source.jpg',
    ),
    null,
  );
});

test('rejects unsupported extensions', () => {
  for (const extension of ['svg', 'gif', 'pdf', 'txt', 'exe']) {
    assert.equal(
      parseCatalogueOriginalPath(
        VALID_PATH.replace('source.jpg', `source.${extension}`),
      ),
      null,
    );
  }
});

test('rejects empty and non-string inputs', () => {
  assert.equal(parseCatalogueOriginalPath(''), null);
  assert.equal(parseCatalogueOriginalPath('   '), null);
  assert.equal(parseCatalogueOriginalPath(null), null);
  assert.equal(parseCatalogueOriginalPath(undefined), null);
  assert.equal(parseCatalogueOriginalPath(123), null);
});

test('rejects paths containing empty identifier segments', () => {
  assert.equal(
    parseCatalogueOriginalPath(
      'catalogue_designs//versions/version-456/' +
        'views/view-789/original/source.jpg',
    ),
    null,
  );
});

test('rejects extra nested path components', () => {
  assert.equal(
    parseCatalogueOriginalPath(
      `${VALID_PATH}/unexpected`,
    ),
    null,
  );
});
