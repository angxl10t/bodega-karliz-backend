// Service Worker para CajaYa Cloud POS (PWA)
const CACHE_NAME = 'cajaya-pwa-v29';

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

// Listener de Fetch: Estrategia Network-First con Respaldo en Caché para Recursos Estáticos
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
    fetch(event.request)
      .then((networkResponse) => {
        // Almacenar en caché estáticos del mismo origen para resiliencia offline en bodega
        if (
          networkResponse.status === 200 &&
          (url.pathname.endsWith('.js') ||
           url.pathname.endsWith('.wasm') ||
           url.pathname.endsWith('.html') ||
           url.pathname.endsWith('.png') ||
           url.pathname.endsWith('.ttf') ||
           url.pathname.endsWith('.wav') ||
           url.pathname.endsWith('.json') ||
           url.pathname === '/' ||
           url.pathname.endsWith('/'))
        ) {
          const responseClone = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone);
          });
        }
        return networkResponse;
      })
      .catch(async () => {
        const cached = await caches.match(event.request);
        if (cached) return cached;
        // Si no hay red y se navega, retornar la app shell index.html
        if (event.request.mode === 'navigate') {
          const cachedIndex = await caches.match('index.html') || await caches.match('./');
          if (cachedIndex) return cachedIndex;
        }
        return new Response('Offline', {
          status: 503,
          statusText: 'Service Unavailable',
        });
      })
  );
});

