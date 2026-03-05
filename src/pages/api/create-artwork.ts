import type { APIRoute } from 'astro';

const DIRECTUS_URL = process.env.DIRECTUS_URL || 'http://mfg-directus:8055';
const DIRECTUS_TOKEN = process.env.DIRECTUS_TOKEN;

export const POST: APIRoute = async ({ request }) => {
  try {
    if (!DIRECTUS_TOKEN) {
      return new Response(JSON.stringify({ error: 'DIRECTUS_TOKEN nincs beállítva.' }), { status: 500 });
    }

    const body = await request.json();
    const { email, author, description, fileIds } = body;

    if (!email || !author || !fileIds?.length) {
      return new Response(JSON.stringify({ error: 'Hiányzó mezők.' }), { status: 400 });
    }

    // 1. bekuldesek rekord létrehozása (files nélkül)
    const res = await fetch(`${DIRECTUS_URL}/items/bekuldesek`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${DIRECTUS_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ email, author, description })
    });

    if (!res.ok) {
      const err = await res.text();
      console.error('Directus create bekuldes error:', err);
      return new Response(JSON.stringify({ error: 'Adatmentés sikertelen.' }), { status: 502 });
    }

    const data = await res.json();
    const bekuldesId = data.data.id;

    // 2. Junction tábla bejegyzések (bekuldesek_files)
    for (const fileId of fileIds) {
      const jRes = await fetch(`${DIRECTUS_URL}/items/bekuldesek_files`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${DIRECTUS_TOKEN}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ bekuldesek_id: bekuldesId, directus_files_id: fileId })
      });
      if (!jRes.ok) {
        console.error('Directus junction error:', await jRes.text());
      }
    }

    return new Response(JSON.stringify({ id: bekuldesId }), {
      status: 200, headers: { 'Content-Type': 'application/json' }
    });

  } catch (err) {
    console.error('create-artwork error:', err);
    return new Response(JSON.stringify({ error: 'Szerverhiba.' }), { status: 500 });
  }
};
