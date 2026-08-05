'use strict';
const fs   = require('fs');
const path = require('path');

const keyPath = path.join(__dirname, '..', 'secrets', 'serviceAccountKey.json');
const svcAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
console.log('\n✅  Project:', svcAccount.project_id);

// Works with firebase-admin v12 and v13
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore }        = require('firebase-admin/firestore');

const app = initializeApp({ credential: cert(svcAccount) });
const db  = getFirestore(app);

function inferType(v) {
  if (v === null || v === undefined) return 'null';
  const n = v && v.constructor && v.constructor.name;
  if (n === 'Timestamp') return 'Timestamp';
  if (n === 'GeoPoint')  return 'GeoPoint';
  if (n === 'DocumentReference') return 'Reference';
  if (Array.isArray(v)) return 'Array<' + (v.length ? inferType(v[0]) : 'unknown') + '>';
  if (typeof v === 'object') return 'Map';
  return typeof v;
}

async function main() {
  const cols = await db.listCollections();
  console.log('📂  Found ' + cols.length + ' collection(s)\n');
  const schema = {};
  for (const col of cols) {
    console.log('  scanning: ' + col.id);
    const snap = await col.limit(10).get();
    const fields = {};
    snap.forEach(function(doc) {
      Object.keys(doc.data()).forEach(function(k) {
        if (!fields[k]) fields[k] = inferType(doc.data()[k]);
      });
    });
    let subs = [];
    if (!snap.empty) { try { subs = (await snap.docs[0].ref.listCollections()).map(function(s){return s.id;}); } catch(e){} }
    schema[col.id] = { documentCount: snap.size, fields: fields, subcollections: subs };
  }
  fs.writeFileSync('firestore-schema.json', JSON.stringify(schema, null, 2));
  console.log('\nCollection'.padEnd(30) + 'Docs'.padEnd(7) + 'Fields'.padEnd(8) + 'Subcollections');
  console.log('-'.repeat(65));
  Object.keys(schema).forEach(function(n) {
    const s = schema[n];
    console.log(n.padEnd(30) + String(s.documentCount).padEnd(7) + String(Object.keys(s.fields).length).padEnd(8) + (s.subcollections.join(', ') || '-'));
  });
  console.log('\n✅  Done — firestore-schema.json created\n');
  process.exit(0);
}
main().catch(function(e) { console.error('❌', e.message); process.exit(1); });
