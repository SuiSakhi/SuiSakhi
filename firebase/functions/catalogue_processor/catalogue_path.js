'use strict';

const ORIGINAL_VIEW_PATTERN =
  /^catalogue_designs\/([^/]+)\/versions\/([^/]+)\/views\/([^/]+)\/original\/source\.([A-Za-z0-9]+)$/;

const SUPPORTED_EXTENSIONS = new Set([
  'jpg',
  'jpeg',
  'png',
  'webp',
]);

function parseCatalogueOriginalPath(objectPath) {
  if (typeof objectPath !== 'string') {
    return null;
  }

  const normalizedPath = objectPath.trim();
  if (normalizedPath.length === 0) {
    return null;
  }

  const match = ORIGINAL_VIEW_PATTERN.exec(normalizedPath);
  if (!match) {
    return null;
  }

  const designId = match[1];
  const versionId = match[2];
  const viewId = match[3];
  const extension = match[4].toLowerCase();

  if (!SUPPORTED_EXTENSIONS.has(extension)) {
    return null;
  }

  const viewBasePath =
    `catalogue_designs/${designId}` +
    `/versions/${versionId}` +
    `/views/${viewId}`;

  return Object.freeze({
    objectPath: normalizedPath,
    designId,
    versionId,
    viewId,
    extension,
    viewBasePath,
    normalizedPath: `${viewBasePath}/normalized/preview.webp`,
    thumbnailPath: `${viewBasePath}/thumbnails/card.webp`,
    manifestPath: `${viewBasePath}/structured/manifest.json`,
    firestoreDesignPath: `designs/${designId}`,
    firestoreVersionPath:
      `designs/${designId}/versions/${versionId}`,
    firestoreViewPath:
      `designs/${designId}/versions/${versionId}/views/${viewId}`,
  });
}

module.exports = {
  ORIGINAL_VIEW_PATTERN,
  SUPPORTED_EXTENSIONS,
  parseCatalogueOriginalPath,
};
