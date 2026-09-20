#!/usr/bin/env node
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

async function main() {
  const output = process.argv[2] ||
    path.join(process.cwd(), 'tmp', 'catalogue-sample.png');
  await fs.mkdir(path.dirname(output), { recursive: true });
  const svg = `
    <svg width="1200" height="1800" xmlns="http://www.w3.org/2000/svg">
      <rect width="1200" height="1800" fill="#fffaf6"/>
      <path d="M430 260 L600 150 L770 260 L900 640 L790 720 L760 1570 L440 1570 L410 720 L300 640 Z"
        fill="#eadcff" stroke="#5330a8" stroke-width="18"/>
      <path d="M430 260 Q600 420 770 260" fill="none" stroke="#5330a8" stroke-width="16"/>
      <path d="M455 860 Q600 940 745 860" fill="none" stroke="#9f68db" stroke-width="12"/>
      <circle cx="600" cy="650" r="26" fill="#9f68db"/>
    </svg>`;
  await sharp(Buffer.from(svg)).png().toFile(output);
  console.log(output);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
