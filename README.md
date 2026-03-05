# MFG-40 — Medgyessy Gimnázium Digitális Archívum

Astro frontend + Directus CMS backend. Minden érzékeny adat a `.env` fájlban van (lásd `.env.example`).

- **mfg-art.hu** → Astro feltöltő oldal
- **api.mfg-art.hu** → Directus admin + API

## Deploy lépései

### 1. Klónozás a VPS-re

```bash
git clone https://github.com/nagyonmarci/mfg-40.git /opt/mfg-40
cd /opt/mfg-40
```

### 2. .env létrehozása

```bash
cp .env.example .env
nano .env
```

Töltsd ki az összes értéket (`DB_PASSWORD`, `DIRECTUS_SECRET`, `ADMIN_PASSWORD`).
A `DIRECTUS_TOKEN`-t egyelőre hagyd üresen.

### 3. Directus + DB indítása

```bash
docker compose up -d mfg-db mfg-directus
```

Várj ~30 másodpercet, majd ellenőrzd:
```bash
docker logs mfg-directus --tail 20
```

### 4. Directus setup (collection + jogosultságok)

A script a container belsejéből fut, ahol `localhost:8055` elérhető és az env változók (`ADMIN_EMAIL`, `ADMIN_PASSWORD`) már be vannak töltve:

```bash
docker cp scripts/setup-directus.sh mfg-directus:/tmp/setup-directus.sh
docker exec mfg-directus sh /tmp/setup-directus.sh
```

### 5. API Token létrehozása

1. Nyisd meg: `https://api.mfg-art.hu/admin`
2. Jelentkezz be az `ADMIN_EMAIL` / `ADMIN_PASSWORD` értékekkel (lásd `.env`)
3. **Settings → API Tokens → Add Token**
4. Név: `astro`, Role: `Administrator`
5. Másold a tokent a `.env` fájlba:

```bash
nano .env
# DIRECTUS_TOKEN=<token>
```

### 6. Astro indítása

```bash
docker compose up -d mfg-astro
```

### Frissítés

```bash
git pull
docker compose up -d --build mfg-astro
```

## Könyvtárszerkezet

```
src/pages/
  index.astro          # Feltöltő oldal (kétoszlopos, köszöntő + form)
  api/
    upload-image.ts    # Proxy → Directus /files
    create-artwork.ts  # Proxy → Directus /items/bekuldesek
src/layouts/
  Layout.astro         # Közös dark/red design
scripts/
  setup-directus.sh    # Egyszeri Directus inicializálás
```

## Helyi fejlesztés

A `docker-compose.override.yml` felülírja a production konfigurációt helyi futtatáshoz (port 8056, CORS localhost).

```bash
docker compose up -d mfg-db mfg-directus
# Várj ~30mp-et, majd:
docker cp scripts/setup-directus.sh mfg-directus:/tmp/setup-directus.sh
docker exec mfg-directus sh /tmp/setup-directus.sh
DIRECTUS_URL=http://localhost:8056 npm run dev
```
