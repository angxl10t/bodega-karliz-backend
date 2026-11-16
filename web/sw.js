// Service Worker para CajaYa Cloud POS (PWA)
const CACHE_NAME = 'cajaya-pwa-v1';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// Listener de Fetch necesario para que Google Chrome y Edge califiquen el sitio como instalable PWA
self.addEventListener('fetch', (event) => {
  event.respondWith(
    fetch(event.request).catch(() => caches.match(event.request))
  );
});
