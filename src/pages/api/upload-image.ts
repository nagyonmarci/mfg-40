import type { APIRoute } from 'astro';

const DIRECTUS_URL = import.meta.env.DIRECTUS_URL || 'http://mfg-directus:8055';
const DIRECTUS_TOKEN = import.meta.env.DIRECTUS_TOKEN;

export const POST: APIRoute = async ({ request }) => {
  try {
    if (!DIRECTUS_TOKEN) {
      return new Response(JSON.stringify({ error: 'DIRECTUS_TOKEN nincs beállítva.' }), { status: 500 });
    }

    const formData = await request.formData();
    const file = formData.get('file') as File | null;

    if (!file) {
      return new Response(JSON.stringify({ error: 'Nincs fájl.' }), { status: 400 });
    }

    if (file.size > 20 * 1024 * 1024) {
      return new Response(JSON.stringify({ error: 'A fájl mérete meghaladja a 20 MB-ot.' }), { status: 400 });
    }

    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
    if (!allowed.includes(file.type)) {
      return new Response(JSON.stringify({ error: 'Csak képfájlok engedélyezettek.' }), { status: 400 });
    }

    const df = new FormData();
    df.append('file', file);

    const res = await fetch(`${DIRECTUS_URL}/files`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${DIRECTUS_TOKEN}` },
      body: df
    });

    if (!res.ok) {
      const err = await res.text();
      console.error('Directus file upload error:', err);
      return new Response(JSON.stringify({ error: 'Képfeltöltés sikertelen a Directusban.' }), { status: 502 });
    }

    const data = await res.json();
    return new Response(JSON.stringify({ id: data.data.id }), {
      status: 200, headers: { 'Content-Type': 'application/json' }
    });

  } catch (err) {
    console.error('upload-image error:', err);
    return new Response(JSON.stringify({ error: 'Szerverhiba.' }), { status: 500 });
  }
};
