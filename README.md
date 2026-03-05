# MFG-40 — Medgyessy Gimnázium Képfeltöltő

Astro frontend + Directus CMS backend.

- **mfg-art.hu** → Astro feltöltő + galéria
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

Töltsd ki az összes értéket (DB_PASSWORD, DIRECTUS_SECRET, ADMIN_PASSWORD).
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

```bash
bash scripts/setup-directus.sh
```

### 5. API Token létrehozása

1. Nyisd meg: `https://api.mfg-art.hu/admin`
2. Jelentkezz be az ADMIN_EMAIL / ADMIN_PASSWORD-dal
3. **Settings → API Tokens → Add Token**
4. Név: `astro`, Role: `Administrator`
5. Másold a tokent

```bash
nano .env
# DIRECTUS_TOKEN=ide_a_token
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
  index.astro          # Feltöltő oldal
  galeria.astro        # Galéria lightboxszal
  api/
    upload-image.ts    # Proxy → Directus /files
    create-artwork.ts  # Proxy → Directus /items/artworks
src/layouts/
  Layout.astro         # Közös dark/red design
scripts/
  setup-directus.sh    # Egyszeri setup script
```
