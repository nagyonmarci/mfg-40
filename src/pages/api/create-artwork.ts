import type { APIRoute } from 'astro';

const DIRECTUS_URL = import.meta.env.DIRECTUS_URL || 'http://mfg-directus:8055';
const DIRECTUS_TOKEN = import.meta.env.DIRECTUS_TOKEN;

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

    const res = await fetch(`${DIRECTUS_URL}/items/bekuldesek`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${DIRECTUS_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        email,
        author,
        description,
        files: fileIds.map((id: string) => ({ directus_files_id: id }))
      })
    });

    if (!res.ok) {
      const err = await res.text();
      console.error('Directus create bekuldes error:', err);
      return new Response(JSON.stringify({ error: 'Adatmentés sikertelen.' }), { status: 502 });
    }

    const data = await res.json();
    return new Response(JSON.stringify({ id: data.data.id }), {
      status: 200, headers: { 'Content-Type': 'application/json' }
    });

  } catch (err) {
    console.error('create-artwork error:', err);
    return new Response(JSON.stringify({ error: 'Szerverhiba.' }), { status: 500 });
  }
};
