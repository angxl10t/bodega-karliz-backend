// Service Worker para CajaYa Cloud POS (PWA)
const CACHE_NAME = 'cajaya-pwa-v21';

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

// Listener de Fetch: Network First para asegurar que las actualizaciones de la UI se sirvan de inmediato
self.addEventListener('fetch', (event) => {
  event.respondWith(
    fetch(event.request).catch(() => caches.match(event.request))
  );
});

