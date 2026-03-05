#!/bin/sh
# Directus inicializálás — első indítás után futtatandó
#
# Használat:
#   ADMIN_PASSWORD=xxx bash scripts/setup-directus.sh
#
# Vagy ha a Directus nem localhost:8055-ön fut:
#   DIRECTUS_URL=http://localhost:8056 ADMIN_PASSWORD=xxx bash scripts/setup-directus.sh

set -e

DIRECTUS_URL="${DIRECTUS_URL:-http://localhost:8055}"
EMAIL="${ADMIN_EMAIL}"
PASSWORD="${ADMIN_PASSWORD}"

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  echo "Hiba: ADMIN_EMAIL és ADMIN_PASSWORD szükséges."
  echo "Példa: docker cp scripts/setup-directus.sh mfg-directus:/tmp/ && docker exec mfg-directus sh /tmp/setup-directus.sh"
  exit 1
fi

echo "Bejelentkezés Directusba ($DIRECTUS_URL)..."
TOKEN=$(curl -sf -X POST "$DIRECTUS_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "Hiba: nem sikerült bejelentkezni. Ellenőrizd az ADMIN_EMAIL és ADMIN_PASSWORD értékeket."
  exit 1
fi

echo "Token megvan."

# ── 1. bekuldesek collection ──────────────────────────────────────────────────
echo "bekuldesek collection létrehozása..."
curl -sf -X POST "$DIRECTUS_URL/collections" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "collection": "bekuldesek",
    "meta": {
      "icon": "upload",
      "note": "Feltöltött alkotások",
      "display_template": "{{author}} — {{email}}"
    },
    "schema": {},
    "fields": [
      {
        "field": "author",
        "type": "string",
        "meta": {"required": true, "interface": "input", "display": "raw"},
        "schema": {"is_nullable": false}
      },
      {
        "field": "email",
        "type": "string",
        "meta": {"required": true, "interface": "input", "display": "raw"},
        "schema": {"is_nullable": false}
      },
      {
        "field": "description",
        "type": "text",
        "meta": {"interface": "input-multiline", "display": "raw"},
        "schema": {"is_nullable": true}
      }
    ]
  }' && echo "  ✓ bekuldesek collection létrehozva." || echo "  ⚠ bekuldesek már létezik, kihagyva."

# ── 2. bekuldesek_files junction collection ───────────────────────────────────
echo "bekuldesek_files junction collection létrehozása..."
curl -sf -X POST "$DIRECTUS_URL/collections" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "collection": "bekuldesek_files",
    "meta": {
      "hidden": true,
      "icon": "import_export"
    },
    "schema": {},
    "fields": [
      {
        "field": "bekuldesek_id",
        "type": "integer",
        "meta": {"hidden": true},
        "schema": {"is_nullable": false}
      },
      {
        "field": "directus_files_id",
        "type": "uuid",
        "meta": {"hidden": true},
        "schema": {"is_nullable": false}
      }
    ]
  }' && echo "  ✓ bekuldesek_files junction létrehozva." || echo "  ⚠ bekuldesek_files már létezik, kihagyva."

# ── 3. Relation: bekuldesek_files.bekuldesek_id → bekuldesek ─────────────────
echo "Relációk létrehozása..."
curl -sf -X POST "$DIRECTUS_URL/relations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "collection": "bekuldesek_files",
    "field": "bekuldesek_id",
    "related_collection": "bekuldesek",
    "meta": {"junction_field": "directus_files_id"},
    "schema": {
      "on_delete": "CASCADE"
    }
  }' && echo "  ✓ bekuldesek_files → bekuldesek reláció kész." || echo "  ⚠ Reláció már létezik."

# ── 4. Relation: bekuldesek_files.directus_files_id → directus_files ─────────
curl -sf -X POST "$DIRECTUS_URL/relations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "collection": "bekuldesek_files",
    "field": "directus_files_id",
    "related_collection": "directus_files",
    "meta": {"junction_field": "bekuldesek_id"},
    "schema": {}
  }' && echo "  ✓ bekuldesek_files → directus_files reláció kész." || echo "  ⚠ Reláció már létezik."

# ── 5. files alias mező a bekuldesek collection-ben ──────────────────────────
curl -sf -X POST "$DIRECTUS_URL/fields/bekuldesek" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "field": "files",
    "type": "alias",
    "meta": {
      "interface": "list-m2m",
      "display": "related-values",
      "special": ["files"],
      "options": {
        "template": "{{directus_files_id.filename_download}}"
      }
    }
  }' && echo "  ✓ files alias mező kész." || echo "  ⚠ files mező már létezik."

# ── 6. Jogosultságok ──────────────────────────────────────────────────────────
echo "Publikus jogosultságok beállítása..."

# bekuldesek: create
curl -sf -X POST "$DIRECTUS_URL/permissions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":null,"collection":"bekuldesek","action":"create","fields":["*"]}' \
  && echo "  ✓ bekuldesek create jog beállítva." || echo "  ⚠ Már be van állítva."

# bekuldesek_files: create
curl -sf -X POST "$DIRECTUS_URL/permissions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":null,"collection":"bekuldesek_files","action":"create","fields":["*"]}' \
  && echo "  ✓ bekuldesek_files create jog beállítva." || echo "  ⚠ Már be van állítva."

# directus_files: create (feltöltéshez)
curl -sf -X POST "$DIRECTUS_URL/permissions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":null,"collection":"directus_files","action":"create","fields":["*"]}' \
  && echo "  ✓ directus_files create jog beállítva." || echo "  ⚠ Már be van állítva."

echo ""
echo "✓ Directus setup kész!"
echo ""
echo "Következő lépések:"
echo "  1. Nyisd meg: ${DIRECTUS_URL}/admin (vagy https://api.mfg-art.hu/admin)"
echo "  2. Settings → API Tokens → Add token"
echo "  3. Név: astro, Role: Administrator (vagy egyedi, create jogokkal)"
echo "  4. Másold be a tokent a .env fájl DIRECTUS_TOKEN mezőjébe"
echo "  5. docker compose up -d --build mfg-astro"
