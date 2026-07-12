/* ==========================================================================
   Orbita Go — Service Worker v1.0
   Offline caching strategy: Cache-first for assets, Network-first for API
   ========================================================================== */

const CACHE_NAME = 'orbita-go-v2';
const STATIC_ASSETS = [
    '/',
    '/index.html',
    '/style.css',
    '/app.js',
    '/translations.js',
    '/manifest.json',
    '/pages/page.css',
    '/pages/taxi.html',
    '/pages/walk.html',
    '/pages/games.html',
    '/pages/cafe.html',
    '/pages/market.html',
    '/pages/delivery.html',
];

// Install — cache all static assets
self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => cache.addAll(STATIC_ASSETS))
            .then(() => self.skipWaiting())
    );
});

// Activate — clean old caches
self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys().then(cacheNames =>
            Promise.all(
                cacheNames
                    .filter(name => name !== CACHE_NAME)
                    .map(name => caches.delete(name))
            )
        ).then(() => self.clients.claim())
    );
});

// Fetch — Cache-first for assets, Network-first for API
self.addEventListener('fetch', event => {
    // Only intercept http/https requests
    if (!event.request.url.startsWith('http')) return;

    const url = new URL(event.request.url);

    // API requests: network-first
    if (url.hostname === 'localhost' || url.pathname.startsWith('/api/')) {
        event.respondWith(
            fetch(event.request).catch(() =>
                new Response(JSON.stringify({ offline: true, message: 'Offline rejim' }), {
                    headers: { 'Content-Type': 'application/json' }
                })
            )
        );
        return;
    }

    // External CDNs (e.g. Ionicons, Google Fonts): network-first with cache fallback
    if (url.hostname !== location.hostname) {
        event.respondWith(
            fetch(event.request)
                .then(response => {
                    // Only cache successful GET responses (including opaque 0 responses from external CDNs)
                    if (event.request.method === 'GET' && (response.status === 200 || response.type === 'opaque')) {
                        const clone = response.clone();
                        caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
                    }
                    return response;
                })
                .catch(async () => {
                    const cached = await caches.match(event.request);
                    if (cached) return cached;
                    // Return offline placeholder or pass-through if nothing in cache
                    return new Response('', { status: 408, statusText: 'Network Error' });
                })
        );
        return;
    }

    // Static assets: cache-first
    event.respondWith(
        caches.match(event.request).then(cached => {
            if (cached) return cached;
            return fetch(event.request).then(response => {
                if (event.request.method === 'GET' && response.status === 200) {
                    const clone = response.clone();
                    caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
                }
                return response;
            }).catch(() => {
                // Return fallback if fetch fails and no cache
                return new Response('Offline content', { status: 503, statusText: 'Offline' });
            });
        })
    );
});
