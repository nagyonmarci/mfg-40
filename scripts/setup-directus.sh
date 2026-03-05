#!/bin/sh
# Futtasd első indítás után:
# docker exec mfg-directus sh /directus/setup.sh
# (vagy: bash scripts/setup-directus.sh)
#
# Ez létrehozza az "artworks" collection-t és a publikus feltöltési jogosultságot.

set -e

DIRECTUS_URL="http://localhost:8055"
EMAIL="${ADMIN_EMAIL:-admin@mfg-art.hu}"
PASSWORD="${ADMIN_PASSWORD}"

echo "Bejelentkezés Directusba..."
TOKEN=$(curl -sf -X POST "$DIRECTUS_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "Hiba: nem sikerült bejelentkezni. Ellenőrizd az ADMIN_EMAIL és ADMIN_PASSWORD értékeket."
  exit 1
fi

echo "Token megvan. Collection létrehozása..."

# artworks collection
curl -sf -X POST "$DIRECTUS_URL/collections" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "collection": "artworks",
    "meta": {
      "icon": "palette",
      "note": "Feltöltött műalkotások",
      "display_template": "{{title}} — {{author}}"
    },
    "schema": {},
    "fields": [
      {"field":"title","type":"string","meta":{"required":true,"interface":"input","display":"raw"},"schema":{"is_nullable":false}},
      {"field":"author","type":"string","meta":{"required":true,"interface":"input","display":"raw"},"schema":{"is_nullable":false}},
      {"field":"description","type":"text","meta":{"interface":"input-multiline","display":"raw"}},
      {"field":"image","type":"uuid","meta":{"interface":"file-image","display":"image","special":["file"]},"schema":{"is_nullable":true}}
    ]
  }' && echo "Collection létrehozva." || echo "Collection már létezik, kihagyva."

# Publikus olvasási jog az artworks collection-re
echo "Publikus olvasási jog beállítása..."
curl -sf -X POST "$DIRECTUS_URL/permissions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":null,"collection":"artworks","action":"read","fields":["*"]}' \
  && echo "Olvasási jog beállítva." || echo "Már be van állítva."

# Publikus olvasási jog a directus_files-ra (képek elérése)
curl -sf -X POST "$DIRECTUS_URL/permissions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":null,"collection":"directus_files","action":"read","fields":["*"]}' \
  && echo "Fájl olvasási jog beállítva." || echo "Már be van állítva."

echo ""
echo "✓ Directus setup kész!"
echo ""
echo "Most hozz létre egy API tokent:"
echo "  1. Nyisd meg: https://api.mfg-art.hu/admin"
echo "  2. Settings > API Tokens > Add token"
echo "  3. Adj neki 'astro' nevet, és adj neki Admin vagy egyedi jogot (create artworks + upload files)"
echo "  4. Másold be a tokent a .env fájl DIRECTUS_TOKEN mezőjébe"
echo "  5. docker compose up -d --build mfg-astro"
