#!/bin/sh
# Directus inicializálás — első indítás után futtatandó a containerből:
#
#   docker cp scripts/setup-directus.sh mfg-directus:/tmp/setup-directus.sh
#   docker exec mfg-directus sh /tmp/setup-directus.sh

set -e

if [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
  echo "Hiba: ADMIN_EMAIL és ADMIN_PASSWORD szükséges."
  echo "Példa: docker exec mfg-directus sh /tmp/setup-directus.sh"
  exit 1
fi

DIRECTUS_URL="${DIRECTUS_URL:-http://localhost:8055}"

echo "Directus setup indítása ($DIRECTUS_URL)..."

DIRECTUS_URL="$DIRECTUS_URL" \
ADMIN_EMAIL="$ADMIN_EMAIL" \
ADMIN_PASSWORD="$ADMIN_PASSWORD" \
node --input-type=module << 'EOF'
const base = process.env.DIRECTUS_URL;
const email = process.env.ADMIN_EMAIL;
const password = process.env.ADMIN_PASSWORD;

async function api(path, method = 'GET', body = null, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${base}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : null
  });
  const text = await res.text();
  try { return JSON.parse(text); } catch { return text; }
}

async function tryOrSkip(label, fn) {
  try { await fn(); console.log(`  ✓ ${label}`); }
  catch (e) { console.log(`  ⚠ ${label} — kihagyva (${e.message})`); }
}

// 1. Login
// Várakozás amíg Directus elindul
console.log('Várakozás a Directus indulására...');
let ready = false;
for (let i = 0; i < 30; i++) {
  try {
    const h = await fetch(`${base}/server/health`);
    if (h.ok) { ready = true; break; }
  } catch {}
  process.stdout.write(`  ${i + 1}/30...\r`);
  await new Promise(r => setTimeout(r, 2000));
}
if (!ready) { console.error('Directus nem indult el 60 másodpercen belül.'); process.exit(1); }
console.log('  ✓ Directus fut.                ');

console.log('Bejelentkezés...');
const login = await api('/auth/login', 'POST', { email, password });
const token = login.data?.access_token;
if (!token) { console.error('Bejelentkezés sikertelen:', JSON.stringify(login)); process.exit(1); }
console.log('  ✓ Token megvan.');

// 2. bekuldesek collection
console.log('bekuldesek collection...');
await tryOrSkip('bekuldesek létrehozva', () => api('/collections', 'POST', {
  collection: 'bekuldesek',
  meta: { icon: 'upload', note: 'Feltöltött alkotások', display_template: '{{author}} — {{email}}' },
  schema: {},
  fields: [
    { field: 'author', type: 'string', meta: { required: true, interface: 'input', display: 'raw' }, schema: { is_nullable: false } },
    { field: 'email',  type: 'string', meta: { required: true, interface: 'input', display: 'raw' }, schema: { is_nullable: false } },
    { field: 'description', type: 'text', meta: { interface: 'input-multiline', display: 'raw' }, schema: { is_nullable: true } }
  ]
}, token));

// 3. bekuldesek_files junction
console.log('bekuldesek_files junction...');
await tryOrSkip('junction létrehozva', () => api('/collections', 'POST', {
  collection: 'bekuldesek_files',
  meta: { hidden: true, icon: 'import_export' },
  schema: {},
  fields: [
    { field: 'bekuldesek_id',      type: 'integer', meta: { hidden: true }, schema: { is_nullable: false } },
    { field: 'directus_files_id',  type: 'uuid',    meta: { hidden: true }, schema: { is_nullable: false } }
  ]
}, token));

// 4. Relációk
console.log('Relációk...');
await tryOrSkip('bekuldesek_files → bekuldesek', () => api('/relations', 'POST', {
  collection: 'bekuldesek_files', field: 'bekuldesek_id',
  related_collection: 'bekuldesek',
  meta: { junction_field: 'directus_files_id' },
  schema: { on_delete: 'CASCADE' }
}, token));
await tryOrSkip('bekuldesek_files → directus_files', () => api('/relations', 'POST', {
  collection: 'bekuldesek_files', field: 'directus_files_id',
  related_collection: 'directus_files',
  meta: { junction_field: 'bekuldesek_id' },
  schema: {}
}, token));

// 5. files alias mező
await tryOrSkip('files alias mező', () => api('/fields/bekuldesek', 'POST', {
  field: 'files', type: 'alias',
  meta: {
    interface: 'list-m2m', display: 'related-values', special: ['files'],
    options: { template: '{{directus_files_id.filename_download}}' }
  }
}, token));

// 6. Jogosultságok
console.log('Jogosultságok...');
for (const [collection, action] of [
  ['bekuldesek',       'create'],
  ['bekuldesek_files', 'create'],
  ['directus_files',   'create']
]) {
  await tryOrSkip(`${collection} ${action}`, () =>
    api('/permissions', 'POST', { role: null, collection, action, fields: ['*'] }, token)
  );
}

console.log('\n✓ Directus setup kész!');
console.log('\nKövetkező lépések:');
console.log('  1. Nyisd meg: https://mfg-art.hu/admin');
console.log('  2. Settings → API Tokens → Add token (név: astro, role: Administrator)');
console.log('  3. Másold be a tokent a .env DIRECTUS_TOKEN mezőjébe');
console.log('  4. docker compose up -d mfg-astro');
EOF
