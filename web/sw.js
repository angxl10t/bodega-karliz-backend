// Service Worker para CajaYa Cloud POS (PWA)
const CACHE_NAME = 'cajaya-pwa-v23';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
      );
    }).then(() => self.clients.claim())
  );
});

// Listener de Fetch: SOLO interceptar GET del mismo origen (nunca APIs cross-origin ni mutaciones POST/PUT/PATCH)
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  let url;
  try {
    url = new URL(event.request.url);
  } catch (_) {
    return;
  }
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    fetch(event.request).catch(async () => {
      const cached = await caches.match(event.request);
      if (cached) return cached;
      return new Response('Offline', {
        status: 503,
        statusText: 'Service Unavailable',
      });
    })
  );
});

