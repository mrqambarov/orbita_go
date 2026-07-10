/* ==========================================================================
   Orbita Go — Service Worker v1.0
   Offline caching strategy: Cache-first for assets, Network-first for API
   ========================================================================== */

const CACHE_NAME = 'orbita-go-v1';
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

    // External CDNs: network-first with cache fallback
    if (url.hostname !== location.hostname) {
        event.respondWith(
            fetch(event.request)
                .then(response => {
                    const clone = response.clone();
                    caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
                    return response;
                })
                .catch(() => caches.match(event.request))
        );
        return;
    }

    // Static assets: cache-first
    event.respondWith(
        caches.match(event.request).then(cached => {
            if (cached) return cached;
            return fetch(event.request).then(response => {
                const clone = response.clone();
                caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
                return response;
            });
        })
    );
});
