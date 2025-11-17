#!/usr/bin/env bash
set -euo pipefail

ROOT="monorepo-pwa"
OUTZIP="../RandomPageHelper_PWA_Monorepo_local.zip"

echo "Criando estrutura em ./${ROOT} ..."

rm -rf "${ROOT}"
mkdir -p "${ROOT}/apps/web/public/icons"
mkdir -p "${ROOT}/apps/web/src"
mkdir -p "${ROOT}/apps/api"
mkdir -p "${ROOT}/.github/workflows"
mkdir -p "${ROOT}/docs"

cat > "${ROOT}/docker-compose.yml" <<'YAML'
version: '3.8'
services:
  api:
    build: ./apps/api
    ports:
      - "3000:3000"
  web:
    build: ./apps/web
    ports:
      - "8080:80"
    depends_on:
      - api
YAML

# apps/web package.json
cat > "${ROOT}/apps/web/package.json" <<'JSON'
{
  "name": "random-page-pwa",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview --port 8080",
    "test": "vitest"
  }
}
JSON

# public manifest
cat > "${ROOT}/apps/web/public/manifest.webmanifest" <<'JSON'
{
  "name": "Random Page Helper PWA",
  "short_name": "RPH PWA",
  "description": "Abra páginas educativas aleatórias — PWA derivada da extensão.",
  "start_url": "/?source=pwa",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#0B84FF",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
JSON

# public index.html
cat > "${ROOT}/apps/web/public/index.html" <<'HTML'
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <meta name="theme-color" content="#0B84FF" />
  <link rel="manifest" href="/manifest.webmanifest" />
  <link rel="apple-touch-icon" href="/icons/icon-192.png" />
  <title>Random Page Helper PWA</title>
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.jsx"></script>
</body>
</html>
HTML

# SW
cat > "${ROOT}/apps/web/public/sw.js" <<'SW'
const CACHE_NAME = 'rph-cache-v1';
const ASSETS = [
  '/',
  '/index.html',
  '/manifest.webmanifest',
  '/icons/icon-192.png',
  '/icons/icon-512.png'
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE_NAME).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  if (url.pathname.startsWith('/api/')) {
    e.respondWith(
      fetch(e.request)
        .then(res => { const clone = res.clone(); caches.open(CACHE_NAME).then(c => c.put(e.request, clone)); return res; })
        .catch(() => caches.match(e.request))
    );
    return;
  }

  e.respondWith(
    caches.match(e.request).then(cached => {
      const network = fetch(e.request).then(res => { caches.open(CACHE_NAME).then(c => c.put(e.request, res.clone())); return res; }).catch(()=>{});
      return cached || network;
    })
  );
});
SW

# src files
cat > "${ROOT}/apps/web/src/main.jsx" <<'JS'
import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";

createRoot(document.getElementById("root")).render(<App />);

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(console.error);
  });
}
JS

cat > "${ROOT}/apps/web/src/App.jsx" <<'JS'
import React, { useState } from "react";
import axios from "axios";

export default function App() {
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(false);

  async function openRandom() {
    try {
      setLoading(true);
      const res = await axios.get('/api/random');
      window.open(res.data.url, '_blank');
      setStatus('Ok: ' + res.data.url);
    } catch (e) {
      setStatus('Erro ao buscar página');
    } finally { setLoading(false); }
  }

  return (
    <main style={{padding:20,fontFamily:'Arial,Helvetica,sans-serif'}}>
      <h1>Random Page Helper (PWA)</h1>
      <p>Abra uma página educativa aleatória.</p>
      <button onClick={openRandom} disabled={loading}>
        {loading ? 'Carregando...' : 'Abrir página aleatória'}
      </button>
      {status && <p data-testid="api-ok">{status}</p>}
    </main>
  );
}
JS

# icons: try to create PNGs using python if available; fallback to SVG text files
ICON192="${ROOT}/apps/web/public/icons/icon-192.png"
ICON512="${ROOT}/apps/web/public/icons/icon-512.png"

if command -v convert >/dev/null 2>&1; then
  echo "Gerando ícones PNG com ImageMagick..."
  convert -size 1024x1024 xc:#0B84FF -gravity Center -pointsize 250 -fill white -draw "text 0,0 'RPH'" -resize 512x512 "${ICON512}"
  convert "${ICON512}" -resize 192x192 "${ICON192}"
else
  echo "ImageMagick não encontrado — escrevendo SVGs como fallback e duplicando para .png se possível."
  cat > "${ROOT}/apps/web/public/icons/icon-192.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192"><rect width="100%" height="100%" rx="24" fill="#0B84FF"/><text x="50%" y="55%" font-size="56" text-anchor="middle" fill="#fff" font-family="Arial">RPH</text></svg>
SVG
  cat > "${ROOT}/apps/web/public/icons/icon-512.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><rect width="100%" height="100%" rx="48" fill="#0B84FF"/><text x="50%" y="55%" font-size="160" text-anchor="middle" fill="#fff" font-family="Arial">RPH</text></svg>
SVG
fi

# apps/api
cat > "${ROOT}/apps/api/package.json" <<'JSON'
{
  "name": "random-page-api",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": { "start": "node index.js" },
  "dependencies": { "express": "^4.18.2", "cors": "^2.8.5" }
}
JSON

cat > "${ROOT}/apps/api/index.js" <<'JS'
import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json());

const urls = [
  "https://pt.wikipedia.org/wiki/Sorteio",
  "https://pt.wikipedia.org/wiki/Curiosidades",
  "https://www.khanacademy.org/",
  "https://www.duolingo.com/",
  "https://www.nasa.gov/"
];

app.get('/api/random', (req,res) => {
  const url = urls[Math.floor(Math.random()*urls.length)];
  res.json({ ok:true, url });
});

app.get('/api/status', (_,res) => res.json({ ok:true, time: new Date().toISOString() }));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`API on :${port}`));
JS

# Dockerfiles
cat > "${ROOT}/apps/web/Dockerfile" <<'DF'
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
FROM nginx:stable-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
DF

cat > "${ROOT}/apps/api/Dockerfile" <<'DF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE 3000
CMD ["node","index.js"]
DF

# GitHub Actions workflow (minimal)
cat > "${ROOT}/.github/workflows/ci.yml" <<'YML'
name: CI - PWA Build & Tests
on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install web deps
        run: |
          cd apps/web
          npm ci
      - name: Build web
        run: |
          cd apps/web
          npm run build
      - name: Upload dist
        uses: actions/upload-artifact@v4
        with:
          name: web-dist
          path: apps/web/dist
YML

# README
cat > "${ROOT}/README.md" <<'TXT'
# Random Page Helper — PWA monorepo

Conteúdo: apps/web (PWA), apps/api (Express).

### Rodar com Docker Compose
docker compose up --build
Acesse: http://localhost:8080
API: http://localhost:3000/api/random

### Publicação
Build web -> copiar dist para docs/ ou branch gh-pages
TXT

# zip output
echo "Compactando em ${OUTZIP} ..."
rm -f "${OUTZIP}"
cd "${ROOT}/.."
zip -r "${OUTZIP}" "$(basename "${ROOT}")" > /dev/null

echo "Pronto. ZIP gerado em: ${OUTZIP}"
echo "Para subir no GitHub: clone seu repo, copie os conteúdos do diretório '${ROOT}' e 'git add/commit/push'."
