import type { APIRoute } from 'astro';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const UPLOADS_DIR = '/app/uploads';
const METADATA_FILE = path.join(UPLOADS_DIR, 'metadata.json');
const MAX_SIZE = 20 * 1024 * 1024; // 20 MB
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

function ensureDir() {
  if (!fs.existsSync(UPLOADS_DIR)) {
    fs.mkdirSync(UPLOADS_DIR, { recursive: true });
  }
}

function loadMetadata(): any[] {
  try {
    if (fs.existsSync(METADATA_FILE)) {
      return JSON.parse(fs.readFileSync(METADATA_FILE, 'utf-8'));
    }
  } catch {}
  return [];
}

function saveMetadata(data: any[]) {
  fs.writeFileSync(METADATA_FILE, JSON.stringify(data, null, 2));
}

export const POST: APIRoute = async ({ request }) => {
  try {
    ensureDir();

    const formData = await request.formData();
    const file = formData.get('file') as File | null;
    const author = (formData.get('author') as string)?.trim();
    const title = (formData.get('title') as string)?.trim();
    const description = (formData.get('description') as string)?.trim() || '';

    if (!file || !author || !title) {
      return new Response(JSON.stringify({ error: 'Hiányzó kötelező mezők.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' }
      });
    }

    if (!ALLOWED_TYPES.includes(file.type)) {
      return new Response(JSON.stringify({ error: 'Csak képfájlok engedélyezettek (JPG, PNG, WEBP, GIF).' }), {
        status: 400, headers: { 'Content-Type': 'application/json' }
      });
    }

    if (file.size > MAX_SIZE) {
      return new Response(JSON.stringify({ error: 'A fájl mérete meghaladja a 20 MB-os határt.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' }
      });
    }

    const ext = file.name.split('.').pop()?.toLowerCase() || 'jpg';
    const id = crypto.randomUUID();
    const filename = `${id}.${ext}`;
    const filepath = path.join(UPLOADS_DIR, filename);

    const buffer = Buffer.from(await file.arrayBuffer());
    fs.writeFileSync(filepath, buffer);

    const metadata = loadMetadata();
    metadata.push({
      id,
      filename,
      author,
      title,
      description,
      originalName: file.name,
      uploadedAt: new Date().toISOString()
    });
    saveMetadata(metadata);

    return new Response(JSON.stringify({ success: true, id, filename }), {
      status: 200, headers: { 'Content-Type': 'application/json' }
    });

  } catch (err) {
    console.error('Upload error:', err);
    return new Response(JSON.stringify({ error: 'Szerverhiba. Kérjük próbáld újra.' }), {
      status: 500, headers: { 'Content-Type': 'application/json' }
    });
  }
};
