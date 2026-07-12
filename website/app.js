/* ==========================================================================
   Orbita Go — app.js v3.1
   Particle Canvas · Animated Counters · Scroll Reveal
   Hamburger Menu · FAQ Accordion · Confetti
   Leaflet.js Interactive Map · Multi-language · PWA Install
   ========================================================================== */

// Auto-detect API base: use localhost only in dev environment
const API_BASE = (location.hostname === 'localhost' || location.hostname === '127.0.0.1' || location.protocol === 'file:')
    ? 'http://localhost:3000'
    : 'https://api.orbitago.uz';
const KOSONSOY = [40.9983, 71.1522]; // Default center: Kosonsoy

let GLOBAL_TAXI_PRICES = {
    START: 5000, startKm: 1200,
    KOMFORT: 8000, komfortKm: 1600,
    BIZNES: 12000, biznesKm: 2200
};

/* ============================================================
   DOM READY
   ============================================================ */
document.addEventListener('DOMContentLoaded', () => {
    updateSimClock();
    setInterval(updateSimClock, 60000);

    window.addEventListener('scroll', () => {
        document.getElementById('navbar').classList.toggle('scrolled', window.scrollY > 60);
        // Hide scroll hint after first scroll
        const scrollHint = document.querySelector('.scroll-hint');
        if (scrollHint && window.scrollY > 80) scrollHint.style.opacity = '0';
    }, { passive: true });

    initParticleCanvas();
    initScrollReveal();
    initCounters();
    initHamburger();
    initFaqAccordion();
    loadLeaderboard();
    setupBookingSimulator();
    initPWAInstall();
});

/* ============================================================
   CLOCK
   ============================================================ */
function updateSimClock() {
    const el = document.getElementById('sim-clock');
    if (!el) return;
    const now = new Date();
    el.textContent = `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;
}

/* ============================================================
   PWA INSTALL BANNER
   ============================================================ */
let deferredPWAPrompt = null;
function initPWAInstall() {
    window.addEventListener('beforeinstallprompt', e => {
        e.preventDefault();
        deferredPWAPrompt = e;
        const banner = document.getElementById('pwa-banner');
        if (banner) {
            setTimeout(() => banner.style.display = 'flex', 3000);
        }
    });

    const installBtn = document.getElementById('pwa-install-btn');
    const closeBtn   = document.getElementById('pwa-close-btn');
    const banner     = document.getElementById('pwa-banner');

    if (installBtn) installBtn.addEventListener('click', async () => {
        if (!deferredPWAPrompt) return;
        deferredPWAPrompt.prompt();
        const result = await deferredPWAPrompt.userChoice;
        deferredPWAPrompt = null;
        if (banner) banner.style.display = 'none';
    });
    if (closeBtn && banner) closeBtn.addEventListener('click', () => banner.style.display = 'none');
}

/* ============================================================
   PARTICLE CANVAS
   ============================================================ */
function initParticleCanvas() {
    const canvas = document.getElementById('particle-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let W, H, particles = [];
    const COUNT = 80;
    const COLORS = ['rgba(99,102,241,', 'rgba(217,70,239,', 'rgba(16,185,129,', 'rgba(251,191,36,'];

    const resize = () => { W = canvas.width = window.innerWidth; H = canvas.height = window.innerHeight; };
    const mkP = () => ({
        x: Math.random() * W, y: Math.random() * H,
        size: Math.random() * 2 + 0.5,
        color: COLORS[Math.floor(Math.random() * COLORS.length)],
        alpha: Math.random() * 0.5 + 0.1,
        vx: (Math.random() - 0.5) * 0.4, vy: (Math.random() - 0.5) * 0.4,
        pulse: Math.random() * Math.PI * 2,
    });

    const draw = () => {
        ctx.clearRect(0, 0, W, H);
        for (let i = 0; i < particles.length; i++) {
            for (let j = i + 1; j < particles.length; j++) {
                const dx = particles[i].x - particles[j].x, dy = particles[i].y - particles[j].y;
                const d = Math.sqrt(dx * dx + dy * dy);
                if (d < 120) {
                    ctx.beginPath();
                    ctx.strokeStyle = `rgba(99,102,241,${0.06 * (1 - d / 120)})`;
                    ctx.lineWidth = 0.5;
                    ctx.moveTo(particles[i].x, particles[i].y);
                    ctx.lineTo(particles[j].x, particles[j].y);
                    ctx.stroke();
                }
            }
        }
        particles.forEach(p => {
            p.pulse += 0.02;
            const a = p.alpha * (0.7 + 0.3 * Math.sin(p.pulse));
            ctx.beginPath(); ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
            ctx.fillStyle = `${p.color}${a})`; ctx.fill();
            p.x += p.vx; p.y += p.vy;
            if (p.x < 0 || p.x > W) p.vx *= -1;
            if (p.y < 0 || p.y > H) p.vy *= -1;
        });
        requestAnimationFrame(draw);
    };
    resize(); particles = Array.from({ length: COUNT }, mkP); draw();
    window.addEventListener('resize', () => { resize(); particles = Array.from({ length: COUNT }, mkP); }, { passive: true });
}

/* ============================================================
   SCROLL REVEAL
   ============================================================ */
function initScrollReveal() {
    const targets = document.querySelectorAll('.reveal-up, .reveal-left, .reveal-right');
    if (!targets.length) return;
    const obs = new IntersectionObserver(entries => {
        entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('revealed'); obs.unobserve(e.target); } });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    targets.forEach(el => obs.observe(el));
}

/* ============================================================
   ANIMATED COUNTERS
   ============================================================ */
function initCounters() {
    const counters = document.querySelectorAll('.counter');
    if (!counters.length) return;
    const animateVal = (el, target, suffix, dur) => {
        let start = null;
        const step = ts => {
            if (!start) start = ts;
            const p = Math.min((ts - start) / dur, 1);
            const e = 1 - Math.pow(1 - p, 3);
            const val = Math.floor(e * target);
            // Format large numbers nicely: 48200 with K+ => 48.2K+
            let displayVal;
            if (suffix.includes('K') && target >= 1000) {
                displayVal = (val / 1000).toFixed(val % 1000 === 0 ? 0 : 1) + suffix;
            } else if (suffix.includes('M') && target >= 1) {
                displayVal = val.toLocaleString() + suffix;
            } else {
                displayVal = val.toLocaleString() + suffix;
            }
            el.textContent = displayVal;
            if (p < 1) requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
    };
    const obs = new IntersectionObserver(entries => {
        entries.forEach(e => {
            if (e.isIntersecting) {
                const el = e.target;
                animateVal(el, parseInt(el.dataset.target, 10), el.dataset.suffix || '', 2000);
                obs.unobserve(el);
            }
        });
    }, { threshold: 0.5 });
    counters.forEach(el => obs.observe(el));
}

/* ============================================================
   HAMBURGER MENU
   ============================================================ */
function initHamburger() {
    const btn = document.getElementById('hamburger-btn');
    const overlay = document.getElementById('mobile-nav-overlay');
    if (!btn || !overlay) return;
    const toggle = () => {
        btn.classList.toggle('open');
        overlay.classList.toggle('open');
        document.body.style.overflow = overlay.classList.contains('open') ? 'hidden' : '';
    };
    btn.addEventListener('click', toggle);
    overlay.querySelectorAll('.mobile-nav-link, .btn').forEach(l => l.addEventListener('click', toggle));
    document.addEventListener('keydown', e => { if (e.key === 'Escape' && overlay.classList.contains('open')) toggle(); });
}

/* ============================================================
   FAQ ACCORDION
   ============================================================ */
function initFaqAccordion() {
    const items = document.querySelectorAll('.faq-item');
    items.forEach(item => {
        const btn = item.querySelector('.faq-question');
        const ans = item.querySelector('.faq-answer');
        if (!btn || !ans) return;
        btn.addEventListener('click', () => {
            const open = item.classList.contains('open');
            items.forEach(o => { o.classList.remove('open'); const a = o.querySelector('.faq-answer'); if (a) a.style.maxHeight = '0'; });
            if (!open) { item.classList.add('open'); ans.style.maxHeight = ans.scrollHeight + 'px'; }
        });
    });
}

/* ============================================================
   LEADERBOARD
   ============================================================ */
async function loadLeaderboard() {
    const list = document.getElementById('leaderboard-list');
    if (!list) return;
    try {
        const res = await fetch(`${API_BASE}/api/games/tournament/weekly`);
        const data = await res.json();
        if (data.success && data.leaderboard?.length) {
            renderLeaderboard(data.leaderboard);
            startCountdown(data.resetCountdownSeconds || 604800);
        } else throw new Error();
    } catch { showMockLeaderboard(); }
}
function renderLeaderboard(players) {
    const list = document.getElementById('leaderboard-list');
    list.innerHTML = '';
    players.forEach((p, i) => {
        const rc = ['rank-1','rank-2','rank-3'][i] || '';
        const row = document.createElement('div'); row.className = 'leaderboard-row';
        row.innerHTML = `<span class="rank-badge ${rc}">${i+1}</span>
            <div class="user-profile-cell"><div class="user-avatar">${(p.fullName||'?').charAt(0)}</div><span class="user-name">${p.fullName}</span></div>
            <span class="user-score">${p.totalScore.toLocaleString()} ball</span>`;
        list.appendChild(row);
    });
}
function showMockLeaderboard() {
    renderLeaderboard([
        { fullName:'Jamshid Karimov',   totalScore:28400 },
        { fullName:'Zilola Aliyeva',    totalScore:24200 },
        { fullName:'Sardor Sobirov',    totalScore:21900 },
        { fullName:'Dilnoza Rahmonova', totalScore:18450 },
        { fullName:'Shoxrux Xamidov',  totalScore:15300 },
    ]);
    startCountdown(483000);
}
function startCountdown(secs) {
    const el = document.getElementById('timer-display');
    if (!el) return;
    let t = secs;
    const tick = () => {
        if (t <= 0) { el.textContent = 'Musobaqa tugadi!'; return; }
        const d = Math.floor(t / 86400), h = Math.floor((t % 86400) / 3600),
              m = Math.floor((t % 3600) / 60), s = t % 60;
        el.textContent = `${d>0?d+'k ':''}${pad(h)}:${pad(m)}:${pad(s)}`;
        t--; setTimeout(tick, 1000);
    };
    tick();
}
const pad = n => String(n).padStart(2, '0');

/* ============================================================
   CONFETTI
   ============================================================ */
function launchConfetti() {
    const canvas = document.getElementById('confetti-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    canvas.width = window.innerWidth; canvas.height = window.innerHeight;
    canvas.style.opacity = '1';
    const COLORS = ['#6366f1','#d946ef','#fbbf24','#10b981','#f87171','#38bdf8'];
    const pieces = Array.from({length:130}, () => ({
        x: Math.random() * canvas.width, y: -20 - Math.random() * 100,
        w: Math.random() * 10 + 5, h: Math.random() * 6 + 3,
        color: COLORS[Math.floor(Math.random() * COLORS.length)],
        angle: Math.random() * Math.PI * 2, spin: (Math.random() - 0.5) * 0.2,
        vy: Math.random() * 4 + 3, vx: (Math.random() - 0.5) * 2,
    }));
    let done = false;
    const draw = () => {
        ctx.clearRect(0, 0, canvas.width, canvas.height); done = true;
        pieces.forEach(p => {
            p.y += p.vy; p.x += p.vx; p.angle += p.spin;
            if (p.y < canvas.height + 20) done = false;
            ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.angle);
            ctx.fillStyle = p.color; ctx.fillRect(-p.w/2, -p.h/2, p.w, p.h); ctx.restore();
        });
        if (!done) requestAnimationFrame(draw);
        else { canvas.style.opacity = '0'; ctx.clearRect(0, 0, canvas.width, canvas.height); }
    };
    requestAnimationFrame(draw);
}

/* ============================================================
   LEAFLET MAP HELPERS
   ============================================================ */
let leafletMap = null;
let pickupMarker = null;
let destMarker   = null;
let carMarker    = null;
let routeLine    = null;

function getLeafletIcon(type) {
    const colors = { pickup: '#6366f1', dest: '#ef4444', car: '#fbbf24' };
    const icons  = { pickup: '📍', dest: '🏁', car: '🚗' };
    return L.divIcon({
        html: `<div style="
            width:38px;height:38px;border-radius:50%;
            background:${colors[type]};border:3px solid #fff;
            display:flex;align-items:center;justify-content:center;
            font-size:16px;box-shadow:0 0 20px ${colors[type]};
            animation:ring-pulse 1.8s infinite;
        ">${icons[type]}</div>`,
        className: '',
        iconSize: [38, 38],
        iconAnchor: [19, 19],
    });
}

function drawRoute(a, b) {
    if (routeLine) leafletMap.removeLayer(routeLine);
    routeLine = L.polyline([a, b], {
        color: '#6366f1', weight: 4, opacity: 0.85,
        dashArray: '10, 8',
    }).addTo(leafletMap);
    leafletMap.fitBounds(routeLine.getBounds(), { padding: [40, 40] });
}

function initLeafletMap() {
    if (leafletMap || typeof L === 'undefined') return;
    const container = document.getElementById('map-display');
    if (!container) return;
    container.style.background = '#020108';

    leafletMap = L.map('map-display', {
        center: KOSONSOY, zoom: 12,
        zoomControl: true,
        attributionControl: false,
    });

    // Dark CartoDB tiles
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        maxZoom: 19,
        subdomains: 'abcd',
    }).addTo(leafletMap);

    // Attribution small
    L.control.attribution({ position: 'bottomright', prefix: '' })
        .addAttribution('© CartoDB')
        .addTo(leafletMap);
}

/* ============================================================
   TAXI SIMULATOR
   ============================================================ */
function setupBookingSimulator() {
    const pickupInput  = document.getElementById('pickup-address');
    const destInput    = document.getElementById('destination-address');
    const pickupDD     = document.getElementById('pickup-dropdown');
    const destDD       = document.getElementById('dest-dropdown');
    const tariffCards  = document.querySelectorAll('.tariff-card');
    const submitBtn    = document.getElementById('btn-submit-order');
    const statusText   = document.getElementById('simulator-status-text');
    const hudDistance  = document.getElementById('hud-distance');
    const hudTime      = document.getElementById('hud-time');
    const hudPrice     = document.getElementById('hud-price');

    if (!pickupInput) return;

    // Init Leaflet map (deferred to when section is visible)
    const simSection = document.getElementById('simulator');
    if (simSection) {
        const simObs = new IntersectionObserver(entries => {
            if (entries[0].isIntersecting) { initLeafletMap(); simObs.disconnect(); }
        }, { threshold: 0.1 });
        simObs.observe(simSection);
    }

    let pickupLatLng = null, destLatLng = null;
    let selectedTariff = 'START';
    let isBooking = false;
    let socket = null;

    statusText.textContent = 'Manzil kiriting...';

    setupAutocomplete(pickupInput, pickupDD, (addr, lat, lng) => {
        pickupInput.value = addr;
        pickupLatLng = [lat, lng];
        if (leafletMap) {
            if (pickupMarker) leafletMap.removeLayer(pickupMarker);
            pickupMarker = L.marker([lat, lng], { icon: getLeafletIcon('pickup') }).addTo(leafletMap);
            leafletMap.setView([lat, lng], 13);
        }
        updateHUD(); checkReady();
    });

    setupAutocomplete(destInput, destDD, (addr, lat, lng) => {
        destInput.value = addr;
        destLatLng = [lat, lng];
        if (leafletMap) {
            if (destMarker) leafletMap.removeLayer(destMarker);
            destMarker = L.marker([lat, lng], { icon: getLeafletIcon('dest') }).addTo(leafletMap);
        }
        if (pickupLatLng && destLatLng && leafletMap) drawRoute(pickupLatLng, destLatLng);
        updateHUD(); checkReady();
    });

    tariffCards.forEach(card => {
        card.addEventListener('click', () => {
            if (isBooking) return;
            tariffCards.forEach(c => c.classList.remove('active'));
            card.classList.add('active');
            selectedTariff = card.dataset.tariff;
            updateHUD();
        });
    });

    submitBtn.addEventListener('click', () => {
        if (!pickupLatLng || !destLatLng || isBooking) return;
        startSimulator();
    });

    function checkReady() {
        const ready = !!(pickupLatLng && destLatLng);
        submitBtn.disabled = !ready;
        submitBtn.style.opacity = ready ? '1' : '0.45';
        if (ready) statusText.textContent = 'Buyurtma berishga tayyor!';
    }

    function updateHUD() {
        if (pickupLatLng && destLatLng) {
            const dist = haversine(pickupLatLng, destLatLng).toFixed(1);
            const mins = Math.max(3, Math.round(dist / 0.4));
            
            const base = GLOBAL_TAXI_PRICES[selectedTariff] || 5000;
            let kmRate = 1200;
            if (selectedTariff === 'START') kmRate = GLOBAL_TAXI_PRICES.startKm || 1200;
            else if (selectedTariff === 'KOMFORT') kmRate = GLOBAL_TAXI_PRICES.komfortKm || 1600;
            else if (selectedTariff === 'BIZNES') kmRate = GLOBAL_TAXI_PRICES.biznesKm || 2200;
            
            const price = base + Math.round(dist * kmRate);
            if (hudDistance) hudDistance.textContent = `${dist} km`;
            if (hudTime)     hudTime.textContent     = `~${mins} daq`;
            if (hudPrice)    hudPrice.textContent    = `${price.toLocaleString()} UZS`;
        } else {
            if (hudDistance) hudDistance.textContent = '-- km';
            if (hudTime)     hudTime.textContent     = '-- daqiqa';
            if (hudPrice)    hudPrice.textContent    = '-- UZS';
        }
    }

    async function startSimulator() {
        isBooking = true;
        submitBtn.disabled = true; submitBtn.style.opacity = '0.45';
        statusText.textContent = 'Serverga ulanmoqda...';
        try {
            const res = await fetch(`${API_BASE}/api/order/simulate-public`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    fromAddress: pickupInput.value, toAddress: destInput.value,
                    fromLat: pickupLatLng[0], fromLng: pickupLatLng[1],
                    toLat: destLatLng[0],   toLng: destLatLng[1],
                    tariff: selectedTariff,
                })
            });
            const data = await res.json();
            if (data.success) { statusText.textContent = 'Haydovchi qidirilmoqda...'; connectSocket(data.clientId); }
            else throw new Error(data.message);
        } catch (err) {
            console.warn('Backend offline — client-side sim:', err.message);
            runOfflineSimulation();
        }
    }

    function connectSocket(clientId) {
        if (typeof io === 'undefined') { runOfflineSimulation(); return; }
        socket = io(API_BASE);
        socket.on('connect', () => socket.emit('join_client_room', clientId));
        socket.on('order_status_update', handleStatus);
        socket.on('driver_location_update', handleLocation);
    }

    function handleStatus(upd) {
        const d = upd.driver;
        if (upd.status === 'DRIVER_ARRIVING') {
            statusText.textContent = `✅ Haydovchi: ${d?.fullName || 'Haydovchi'} (${d?.carModel || ''})`;
            if (leafletMap) {
                if (carMarker) leafletMap.removeLayer(carMarker);
                carMarker = L.marker(pickupLatLng, { icon: getLeafletIcon('car') }).addTo(leafletMap);
            }
        } else if (upd.status === 'DRIVER_ARRIVED') {
            statusText.textContent = '🚗 Haydovchi yetib keldi!';
        } else if (upd.status === 'IN_TRIP') {
            statusText.textContent = '🚀 Safar boshlandi!';
        } else if (upd.status === 'COMPLETED') {
            statusText.textContent = '🎉 Safar yakunlandi! Rahmat!';
            launchConfetti();
            setTimeout(cleanReset, 3500);
        }
    }

    function handleLocation(loc) {
        if (carMarker && leafletMap) carMarker.setLatLng([loc.lat, loc.lng]);
    }

    async function runOfflineSimulation() {
        statusText.textContent = '🔍 Haydovchi qidirilmoqda...';
        await delay(2800);

        statusText.textContent = '✅ Haydovchi topildi: Akbar (Nexia 3, Oq)';
        if (leafletMap) {
            if (carMarker) leafletMap.removeLayer(carMarker);
            // Start car near pickup
            const start = [pickupLatLng[0] + 0.005, pickupLatLng[1] - 0.003];
            carMarker = L.marker(start, { icon: getLeafletIcon('car') }).addTo(leafletMap);
        }
        await delay(600);

        // Animate car to pickup
        if (carMarker) await animateCar(carMarker.getLatLng(), { lat: pickupLatLng[0], lng: pickupLatLng[1] }, 6);
        statusText.textContent = '🚗 Haydovchi yetib keldi!';
        await delay(1500);

        // Animate car to destination
        statusText.textContent = '🚀 Safar boshlandi!';
        if (carMarker && destLatLng) await animateCar({ lat: pickupLatLng[0], lng: pickupLatLng[1] }, { lat: destLatLng[0], lng: destLatLng[1] }, 12);

        statusText.textContent = '🎉 Safar yakunlandi! Rahmat!';
        launchConfetti();
        await delay(3000);
        cleanReset();
    }

    async function animateCar(from, to, steps) {
        for (let i = 1; i <= steps; i++) {
            await delay(450);
            const lat = from.lat + (to.lat - from.lat) * (i / steps);
            const lng = (from.lng || from[1]) + ((to.lng || to[1]) - (from.lng || from[1])) * (i / steps);
            if (carMarker) carMarker.setLatLng([lat, lng]);
        }
    }

    function cleanReset() {
        if (socket) { socket.disconnect(); socket = null; }
        isBooking = false; pickupLatLng = null; destLatLng = null;
        pickupInput.value = ''; destInput.value = '';
        [pickupMarker, destMarker, carMarker].forEach(m => { if (m && leafletMap) leafletMap.removeLayer(m); });
        pickupMarker = destMarker = carMarker = null;
        if (routeLine && leafletMap) { leafletMap.removeLayer(routeLine); routeLine = null; }
        if (leafletMap) leafletMap.setView(KOSONSOY, 12);
        updateHUD(); checkReady();
        statusText.textContent = 'Manzil kiriting...';
    }
}

/* ============================================================
   ADDRESS AUTOCOMPLETE
   ============================================================ */
function setupAutocomplete(input, dropdown, onSelect) {
    let timer = null;
    if (!input || !dropdown) return;
    input.addEventListener('input', () => {
        clearTimeout(timer);
        const q = input.value.trim();
        if (q.length < 3) { hideDD(dropdown); return; }
        timer = setTimeout(async () => {
            try {
                const res = await fetch(`https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(q)},+Uzbekistan&format=json&limit=5&accept-language=uz`);
                const results = await res.json();
                if (results.length) {
                    dropdown.innerHTML = '';
                    showDD(dropdown);
                    results.forEach(item => {
                        const div = document.createElement('div');
                        div.className = 'address-item';
                        div.textContent = item.display_name;
                        div.addEventListener('click', () => {
                            hideDD(dropdown);
                            onSelect(item.display_name, parseFloat(item.lat), parseFloat(item.lon));
                        });
                        dropdown.appendChild(div);
                    });
                } else hideDD(dropdown);
            } catch { hideDD(dropdown); }
        }, 500);
    });
    document.addEventListener('click', e => { if (e.target !== input) hideDD(dropdown); });
}
const showDD = dd => dd && (dd.style.display = 'block');
const hideDD = dd => dd && (dd.style.display = 'none');

/* ============================================================
   UTILITIES
   ============================================================ */
const delay = ms => new Promise(r => setTimeout(r, ms));

function haversine(a, b) {
    const R = 6371, toR = d => d * Math.PI / 180;
    const aLat = Array.isArray(a) ? a[0] : a.lat;
    const aLng = Array.isArray(a) ? a[1] : a.lng;
    const bLat = Array.isArray(b) ? b[0] : b.lat;
    const bLng = Array.isArray(b) ? b[1] : b.lng;
    const dLat = toR(bLat - aLat), dLng = toR(bLng - aLng);
    const s = Math.sin(dLat/2)**2 + Math.cos(toR(aLat)) * Math.cos(toR(bLat)) * Math.sin(dLng/2)**2;
    return R * 2 * Math.atan2(Math.sqrt(s), Math.sqrt(1-s));
}

/* ============================================================
   LIVE SYSTEM HEALTH CHECK
   ============================================================ */
function initSystemHealthCheck() {
    const statusDot = document.querySelector('.status-dot');
    const statusText = document.getElementById('system-status-text');
    const pubDot = document.getElementById('pub-status-dot');
    const pubText = document.getElementById('pub-status-text');
    const pubDrivers = document.getElementById('pub-online-drivers');
    const pubOrders = document.getElementById('pub-today-orders');

    // Uses global API_BASE (auto-detected at top of file)

    async function checkHealth() {
        try {
            const res = await fetch(`${API_BASE}/api/health`);
            const data = await res.json();
            const lang = localStorage.getItem('orbita_lang') || 'uz';

            if (pubDrivers && data.stats) {
                pubDrivers.textContent = data.stats.onlineDrivers;
            }
            if (pubOrders && data.stats) {
                pubOrders.textContent = data.stats.todayOrders;
            }

            if (data.status === 'ok') {
                if (statusDot) statusDot.className = 'status-dot status-online';
                const texts = {
                    uz: 'Tizim: API Onlayn (Baza ok)',
                    ru: 'Система: API Онлайн (БД ок)',
                    en: 'System: API Online (DB ok)'
                };
                if (statusText) statusText.textContent = texts[lang] || texts.uz;

                if (pubDot) pubDot.style.background = 'var(--success)';
                if (pubText) {
                    const pubTexts = {
                        uz: 'Tizim holati: FAOL (Onlayn)',
                        ru: 'Статус системы: АКТИВЕН (Онлайн)',
                        en: 'System Status: ACTIVE (Online)'
                    };
                    pubText.textContent = pubTexts[lang] || pubTexts.uz;
                }
            } else {
                if (statusDot) statusDot.className = 'status-dot status-degraded';
                const texts = {
                    uz: 'Tizim: Cheklangan rejim',
                    ru: 'Система: Ограниченный режим',
                    en: 'System: Degraded mode'
                };
                if (statusText) statusText.textContent = texts[lang] || texts.uz;

                if (pubDot) pubDot.style.background = 'var(--yellow)';
                if (pubText) {
                    const pubTexts = {
                        uz: 'Tizim holati: CHEKLANGAN',
                        ru: 'Статус системы: ОГРАНИЧЕН',
                        en: 'System Status: DEGRADED'
                    };
                    pubText.textContent = pubTexts[lang] || pubTexts.uz;
                }
            }
        } catch (err) {
            const lang = localStorage.getItem('orbita_lang') || 'uz';
            if (statusDot) statusDot.className = 'status-dot status-offline';
            const texts = {
                uz: 'Tizim: API Oflayn (Ulanish xatosi)',
                ru: 'Система: API Оффлайн (Ошибка соединения)',
                en: 'System: API Offline (Connection Error)'
            };
            if (statusText) statusText.textContent = texts[lang] || texts.uz;

            if (pubDot) pubDot.style.background = 'var(--red-color)';
            if (pubText) {
                const pubTexts = {
                    uz: 'Tizim holati: OFLAYN',
                    ru: 'Статус системы: ОФФЛАЙН',
                    en: 'System Status: OFFLINE'
                };
                pubText.textContent = pubTexts[lang] || pubTexts.uz;
            }
            if (pubDrivers) pubDrivers.textContent = '--';
            if (pubOrders) pubOrders.textContent = '--';
        }
    }

    checkHealth();
    setInterval(checkHealth, 15000);
}

// Auto init on DOMContentLoaded
document.addEventListener('DOMContentLoaded', initSystemHealthCheck);

// Remove redundant API_BASE — use the single global one defined at top.

// ============================================================
// 3D TILT MOCKUP INTERACTION
// ============================================================
function init3DMockup() {
    const container = document.querySelector('.hero-image-container');
    const phone = document.querySelector('.phone-mockup');
    const glare = document.querySelector('.phone-glare');
    if (!container || !phone) return;

    container.addEventListener('mousemove', e => {
        const rect = container.getBoundingClientRect();
        const x = e.clientX - rect.left - rect.width / 2;
        const y = e.clientY - rect.top - rect.height / 2;
        
        const rx = -(y / (rect.height / 2)) * 12;
        const ry = (x / (rect.width / 2)) * 12;
        
        phone.style.transform = `rotateX(${rx}deg) rotateY(${ry}deg) scale(1.02)`;
        
        if (glare) {
            glare.style.opacity = '1';
            glare.style.background = `radial-gradient(circle at ${e.clientX - rect.left}px ${e.clientY - rect.top}px, rgba(255,255,255,0.18) 0%, transparent 60%)`;
        }
    });

    container.addEventListener('mouseleave', () => {
        phone.style.transform = 'rotateX(0deg) rotateY(0deg) scale(1)';
        if (glare) {
            glare.style.opacity = '0';
        }
    });
}
document.addEventListener('DOMContentLoaded', init3DMockup);

// ============================================================
// MOCKUP SCREEN TAB SWITCHER & WATERING SIMULATOR
// ============================================================
function initMockupTabs() {
    const tabs = document.querySelectorAll('.sim-tab');
    const screens = document.querySelectorAll('.sim-tab-content');
    if (!tabs.length) return;

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            tabs.forEach(t => t.classList.remove('active'));
            screens.forEach(s => s.style.display = 'none');

            tab.classList.add('active');
            const targetId = `sim-screen-${tab.dataset.simTab}`;
            const targetScreen = document.getElementById(targetId);
            if (targetScreen) {
                targetScreen.style.display = (targetScreen.id === 'sim-screen-games' || targetScreen.id === 'sim-screen-taxi') ? 'flex' : 'block';
            }
        });
    });

    const waterBtn = document.getElementById('btn-sim-water');
    const treeProgress = document.getElementById('sim-tree-progress');
    const treePercent = document.getElementById('sim-tree-percent');
    const treeIcon = document.getElementById('sim-tree-icon');
    let percent = 72;

    if (waterBtn && treeProgress && treePercent) {
        waterBtn.addEventListener('click', () => {
            percent += 6;
            if (percent > 100) {
                percent = 30;
                treeIcon.textContent = treeIcon.textContent === '🌳' ? '🌲' : '🌳';
            }
            treePercent.textContent = `${percent}%`;
            treeProgress.style.width = `${percent}%`;

            const drop = document.createElement('span');
            drop.textContent = '💧';
            drop.style.position = 'absolute';
            drop.style.left = '50%';
            drop.style.top = '20%';
            drop.style.transform = 'translateX(-50%)';
            drop.style.fontSize = '24px';
            drop.style.transition = 'all 0.6s ease';
            drop.style.opacity = '1';
            drop.style.pointerEvents = 'none';
            waterBtn.closest('.sim-tab-content').appendChild(drop);

            setTimeout(() => {
                drop.style.top = '40%';
                drop.style.opacity = '0';
                drop.style.transform = 'translateX(-50%) scale(1.4)';
            }, 50);

            setTimeout(() => {
                drop.remove();
            }, 600);
        });
    }
}
document.addEventListener('DOMContentLoaded', initMockupTabs);

// ============================================================
// AI FLOATING ORB ASSISTANT CHAT SYSTEM
// ============================================================
function initAIAssistant() {
    const orb = document.getElementById('ai-orb-btn');
    const chatBox = document.getElementById('ai-chat-box');
    const closeBtn = document.getElementById('ai-chat-close-btn');
    const chatLogs = document.getElementById('ai-chat-logs');
    const chips = document.querySelectorAll('.chat-chip');

    if (!orb || !chatBox) return;

    orb.addEventListener('click', () => {
        chatBox.classList.toggle('open');
    });

    if (closeBtn) {
        closeBtn.addEventListener('click', () => {
            chatBox.classList.remove('open');
        });
    }

    function typeMessage(text, callback) {
        const div = document.createElement('div');
        div.className = 'chat-msg bot';
        chatLogs.appendChild(div);
        chatLogs.scrollTop = chatLogs.scrollHeight;

        let index = 0;
        function type() {
            if (index < text.length) {
                div.innerHTML += text.charAt(index);
                index++;
                chatLogs.scrollTop = chatLogs.scrollHeight;
                setTimeout(type, 15);
            } else if (callback) {
                callback();
            }
        }
        type();
    }

    const RESPONSES = {
        uz: {
            nima: "Orbita Go — bu O'zbekistondagi taksi xizmati, qadam hisoblagich hamda musobaqa o'yinlarini birlashtirgan super-ilova ekotizimidir. 🚀",
            taksi: "Taksi tariflarimiz juda hamyonbop: Start (5,000 UZS boshlang'ich), Komfort (8,000 UZS) va Biznes (12,000 UZS). Safar davomida koinlar ham yig'asiz! 🚖",
            bog: "Virtual bog'imizda daraxt ekib uni sug'orasiz. Daraxt o'sishi evaziga ball to'plab, har haftalik musobaqalarda pul mukofotlarini yutishingiz mumkin! 🌳",
            qadam: "Ilovada yurganda qadamlar avtomatik hisoblanib, koinlarga aylanadi. Ularni KFC, Evos kuponlariga yoki naqd pul balansiga almashtirish mumkin. 🚶",
            donat: "Loyihamizni rivojlantirishga hissa qo'shmoqchi bo'lsangiz, sahifa pastidagi donat bo'limidan Akbar H. nomiga to'lov qilishingiz mumkin. Rahmat! ❤️"
        },
        ru: {
            nima: "Orbita Go — это суперапп-экосистема в Узбекистане, объединяющая службу такси, шагомер и турнирные игры. 🚀",
            taksi: "Наши тарифы очень доступны: Старт (от 5,000 UZS), Комфорт (от 8,000 UZS) и Бизнес (от 12,000 UZS). Вы также получаете коины за поездки! 🚖",
            bog: "В виртуальном саду вы сажаете и поливаете дерево. За выращивание дерева вы копите очки и выигрываете денежные призы каждую неделю! 🌳",
            qadam: "При ходьбе шаги автоматически конвертируются в коины. Их можно обменять на купоны KFC, Evos или вывести на баланс. 🚶",
            donat: "Если вы хотите поддержать проект, вы можете сделать перевод на имя Акбара Х. в разделе донатов внизу страницы. Спасибо! ❤️"
        },
        en: {
            nima: "Orbita Go is a next-generation super-app ecosystem in Uzbekistan combining taxi booking, step tracking, and tournament games. 🚀",
            taksi: "Our taxi rates are very budget-friendly: Start (5,000 UZS base), Comfort (8,000 UZS), and Business (12,000 UZS). Earn coins during rides! 🚖",
            bog: "In the virtual garden, you plant and water trees. As they grow, you accumulate points to win real cash prizes weekly! 🌳",
            qadam: "Steps are automatically tracked and converted to coins, which can be redeemed for KFC/Evos coupons or mobile balance. 🚶",
            donat: "To support our project development, you can send donations to Akbar H. using the donation card widget at the bottom. Thank you! ❤️"
        }
    };

    chips.forEach(chip => {
        chip.addEventListener('click', () => {
            sendChatMessage(chip.dataset.question, chip.textContent);
        });
    });

    // AI Chat text input field
    const chatInputRow = document.createElement('div');
    chatInputRow.style.cssText = 'display:flex;gap:8px;padding:12px 20px 16px;border-top:1px solid rgba(255,255,255,0.05);background:rgba(0,0,0,0.12);';
    chatInputRow.innerHTML = `
        <input id="ai-chat-input" type="text" placeholder="Savol yozing..." autocomplete="off"
            style="flex:1;background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.08);border-radius:12px;
            padding:10px 14px;color:#fff;font-size:13px;font-family:inherit;outline:none;transition:border-color 0.25s;"
            onfocus="this.style.borderColor='rgba(99,102,241,0.5)'"
            onblur="this.style.borderColor='rgba(255,255,255,0.08)'"
        />
        <button id="ai-chat-send" style="background:linear-gradient(135deg,#6366f1,#d946ef);border:none;border-radius:12px;
            width:40px;height:40px;display:flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0;transition:opacity 0.2s;"
            onmouseenter="this.style.opacity='0.85'" onmouseleave="this.style.opacity='1'"
        ><ion-icon name="send-outline" style="color:#fff;font-size:18px;"></ion-icon></button>
    `;
    chatBox.appendChild(chatInputRow);

    const chatInput = chatBox.querySelector('#ai-chat-input');
    const chatSendBtn = chatBox.querySelector('#ai-chat-send');

    function handleUserInput() {
        const text = chatInput.value.trim();
        if (!text) return;
        chatInput.value = '';
        // Try to match a chip keyword, else give generic response
        const lang = localStorage.getItem('orbita_lang') || 'uz';
        const lower = text.toLowerCase();
        let key = 'nima';
        if (lower.includes('taksi') || lower.includes('tarif') || lower.includes('taxi')) key = 'taksi';
        else if (lower.includes('qadam') || lower.includes('step') || lower.includes('shag')) key = 'qadam';
        else if (lower.includes('bog') || lower.includes('daraxt') || lower.includes('garden') || lower.includes('sad')) key = 'bog';
        else if (lower.includes('donat') || lower.includes('pullov') || lower.includes('support')) key = 'donat';
        sendChatMessage(key, text);
    }

    chatInput.addEventListener('keydown', e => { if (e.key === 'Enter') handleUserInput(); });
    chatSendBtn.addEventListener('click', handleUserInput);

    function sendChatMessage(key, displayText) {
        const lang = localStorage.getItem('orbita_lang') || 'uz';
        const userMsg = document.createElement('div');
        userMsg.className = 'chat-msg user';
        userMsg.textContent = displayText;
        chatLogs.appendChild(userMsg);
        chatLogs.scrollTop = chatLogs.scrollHeight;
        setTimeout(() => {
            const responseSet = RESPONSES[lang] || RESPONSES.uz;
            const replyText = responseSet[key] || (lang === 'ru' ? 'Пожалуйста, выберите другой вопрос.' : lang === 'en' ? 'Please choose another question.' : 'Iltimos, boshqa savol tanlang.');
            typeMessage(replyText);
        }, 400);
    }
}
document.addEventListener('DOMContentLoaded', initAIAssistant);

/* ============================================================
   DOWNLOAD MODAL — All Apps Screen
   ============================================================ */
(function initDownloadModal() {
    const overlay = document.getElementById('dl-modal');
    const closeBtn = document.getElementById('dl-modal-close');
    if (!overlay) return;

    function openDlModal() {
        overlay.classList.add('open');
        document.body.style.overflow = 'hidden';
    }
    function closeDlModal() {
        overlay.classList.remove('open');
        document.body.style.overflow = '';
    }

    // Attach to ALL download buttons
    document.querySelectorAll('[href="#download"], .btn-download, #btn-download-hero, #btn-header-download').forEach(el => {
        el.addEventListener('click', e => {
            e.preventDefault();
            openDlModal();
        });
    });

    // Also intercept nav download button
    document.querySelectorAll('[data-i18n="nav.download"]').forEach(el => {
        if (el.tagName === 'A') {
            el.addEventListener('click', e => { e.preventDefault(); openDlModal(); });
        }
    });

    closeBtn.addEventListener('click', closeDlModal);
    overlay.addEventListener('click', e => { if (e.target === overlay) closeDlModal(); });
    document.addEventListener('keydown', e => { if (e.key === 'Escape') { closeDlModal(); closeNewsModal(); } });

    window.openDownloadModal = openDlModal;
    window.closeDownloadModal = closeDlModal;
})();

/* ============================================================
   NEWS ARTICLE MODAL
   ============================================================ */
const NEWS_ARTICLES = {
    1: {
        tagClass: 'news-tag--feature',
        icon: '<ion-icon name="footsteps-outline"></ion-icon>',
        iconStyle: 'background:rgba(99,102,241,0.12);border-color:rgba(99,102,241,0.2);color:var(--primary-light)',
        getContent: (lang) => {
            const c = {
                uz: {
                    tag: 'Yangi Xususiyat', date: '8 Iyul 2026',
                    title: 'Orbita Walk 2.0 — Yangi qadam musobaqa tizimi!',
                    body: `
                        <p>Orbita Walk ilovasining 2.0 versiyasi rasman chiqdi! Bu yangilanish foydalanuvchilarimizga do'stlar bilan musobaqa qilish imkoniyatini beradi.</p>
                        <div class="highlight-box">
                            🏆 Yangi: Har kuni eng ko'p qadam bosgan <strong>TOP 3 foydalanuvchi</strong> real pul mukofot oladi!
                        </div>
                        <p><strong>Nima o'zgardi?</strong></p>
                        <ul>
                            <li>Kunlik va haftalik qadam musobaqalari</li>
                            <li>Do'stlarni taklif qilish va guruh reyting</li>
                            <li>Yangi qadam animatsiyalari va effektlar</li>
                            <li>Qadam sog'liq statistikasi (kaloriya, masofa)</li>
                            <li>KFC va Evos kuponlari to'g'ridan-to'g'ri ilovada</li>
                        </ul>
                        <p>Orbita Walk 2.0 ni hoziroq yuklab oling va bugungi musobaqaga qo'shiling!</p>`
                },
                ru: {
                    tag: 'Новая Функция', date: '8 Июля 2026',
                    title: 'Orbita Walk 2.0 — Новая система соревнований!',
                    body: `
                        <p>Официально вышла версия 2.0 приложения Orbita Walk! Это обновление даёт пользователям возможность соревноваться с друзьями.</p>
                        <div class="highlight-box">
                            🏆 Новое: Топ-3 пользователя с наибольшим количеством шагов ежедневно получают <strong>реальные денежные призы!</strong>
                        </div>
                        <ul>
                            <li>Ежедневные и еженедельные соревнования по шагам</li>
                            <li>Приглашение друзей и групповой рейтинг</li>
                            <li>Новые анимации шагов и эффекты</li>
                            <li>Статистика здоровья (калории, расстояние)</li>
                            <li>Купоны KFC и Evos прямо в приложении</li>
                        </ul>
                        <p>Скачайте Orbita Walk 2.0 прямо сейчас и присоединяйтесь к соревнованию!</p>`
                },
                en: {
                    tag: 'New Feature', date: 'July 8, 2026',
                    title: 'Orbita Walk 2.0 — New Step Competition System!',
                    body: `
                        <p>Orbita Walk version 2.0 is officially out! This update gives users the ability to compete with friends.</p>
                        <div class="highlight-box">
                            🏆 New: The top 3 users with the most daily steps win <strong>real cash prizes every day!</strong>
                        </div>
                        <ul>
                            <li>Daily and weekly step challenges</li>
                            <li>Invite friends and group leaderboard</li>
                            <li>New step animations and effects</li>
                            <li>Health statistics (calories, distance)</li>
                            <li>KFC and Evos coupons directly in-app</li>
                        </ul>
                        <p>Download Orbita Walk 2.0 now and join today's challenge!</p>`
                }
            };
            return c[lang] || c.uz;
        }
    },
    2: {
        tagClass: 'news-tag--update',
        icon: '<ion-icon name="car-sport-outline"></ion-icon>',
        iconStyle: 'background:rgba(251,191,36,0.12);border-color:rgba(251,191,36,0.2);color:var(--yellow)',
        getContent: (lang) => {
            const c = {
                uz: {
                    tag: 'Yangilanish', date: '5 Iyul 2026',
                    title: 'Taksi ilovasi yangilandi — v3.2 chiqdi',
                    body: `
                        <p>Orbita Go Taksi ilovasining v3.2 versiyasi rasman chiqarildi! Bu versiyada haydovchilar va mijozlar uchun juda ko'p foydali yangiliklar qo'shildi.</p>
                        <div class="highlight-box">
                            🚖 Haydovchilar uchun yangi daromad paneli — real vaqtda kunlik, haftalik va oylik daromadingizni kuzating!
                        </div>
                        <p><strong>Haydovchilar uchun:</strong></p>
                        <ul>
                            <li>Yangi daromad hisoblagichi va statistika paneli</li>
                            <li>Turnov bonuslari — ko'proq safar = ko'proq bonus</li>
                            <li>Navigatsiya yaxshilandi (offline xarita)</li>
                        </ul>
                        <p><strong>Mijozlar uchun:</strong></p>
                        <ul>
                            <li>Buyurtmani 1 ta bosish bilan qayta berish</li>
                            <li>Sevimli manzillar (uy, ish, universitet)</li>
                            <li>Haydovchi reyting tizimi yangilandi</li>
                        </ul>`
                },
                ru: {
                    tag: 'Обновление', date: '5 Июля 2026',
                    title: 'Приложение такси обновлено — вышла v3.2',
                    body: `
                        <p>Официально вышла версия v3.2 приложения Orbita Go Такси! В этой версии добавлено множество полезных новинок для водителей и пассажиров.</p>
                        <div class="highlight-box">
                            🚖 Для водителей — новая панель доходов: отслеживайте ежедневный, еженедельный и ежемесячный заработок в реальном времени!
                        </div>
                        <p><strong>Для водителей:</strong></p>
                        <ul>
                            <li>Новый калькулятор доходов и панель статистики</li>
                            <li>Бонусы за оборот — больше поездок = больше бонусов</li>
                            <li>Улучшена навигация (офлайн-карта)</li>
                        </ul>
                        <p><strong>Для пассажиров:</strong></p>
                        <ul>
                            <li>Повтор заказа одним нажатием</li>
                            <li>Избранные адреса (дом, работа, университет)</li>
                            <li>Обновлена система рейтинга водителей</li>
                        </ul>`
                },
                en: {
                    tag: 'Update', date: 'July 5, 2026',
                    title: 'Taxi App Updated — v3.2 Released',
                    body: `
                        <p>Orbita Go Taxi v3.2 is officially released! This version brings many useful improvements for both drivers and passengers.</p>
                        <div class="highlight-box">
                            🚖 For Drivers — New earnings dashboard: track your daily, weekly, and monthly income in real-time!
                        </div>
                        <p><strong>For Drivers:</strong></p>
                        <ul>
                            <li>New earnings calculator and statistics panel</li>
                            <li>Turnover bonuses — more rides = more bonuses</li>
                            <li>Improved navigation (offline maps)</li>
                        </ul>
                        <p><strong>For Passengers:</strong></p>
                        <ul>
                            <li>One-tap trip re-booking</li>
                            <li>Saved favorite addresses (home, work, university)</li>
                            <li>Updated driver rating system</li>
                        </ul>`
                }
            };
            return c[lang] || c.uz;
        }
    },
    3: {
        tagClass: 'news-tag--promo',
        icon: '<ion-icon name="pricetag-outline"></ion-icon>',
        iconStyle: 'background:rgba(16,185,129,0.12);border-color:rgba(16,185,129,0.2);color:var(--success-light)',
        getContent: (lang) => {
            const c = {
                uz: {
                    tag: 'Aksiya', date: '1 Iyul 2026',
                    title: 'Yoz aksiyasi: 30% chegirma taksi tariflariga!',
                    body: `
                        <p>Iyul oyida Orbita Go Taksi barcha foydalanuvchilarga maxsus yoz aksiyasi e'lon qilmoqda!</p>
                        <div class="highlight-box">
                            🎉 <strong>30% chegirma</strong> — barcha Start va Komfort tariflarida, butun iyul oyida!
                        </div>
                        <p><strong>Aksiya shartlari:</strong></p>
                        <ul>
                            <li>Muddati: 1 Iyul — 31 Iyul 2026</li>
                            <li>Tariflar: Start va Komfort</li>
                            <li>Chegirma avtomatik qo'llaniladi</li>
                            <li>Har qanday to'lov usuli uchun amal qiladi</li>
                            <li>Kunlik safarlar soni cheklanmagan</li>
                        </ul>
                        <p>Chegirmadan foydalanish uchun Orbita Go ilovasini hoziroq yuklab oling va safar buyurtma bering!</p>`
                },
                ru: {
                    tag: 'Акция', date: '1 Июля 2026',
                    title: 'Летняя акция: скидка 30% на тарифы такси!',
                    body: `
                        <p>В июле Orbita Go Такси объявляет специальную летнюю акцию для всех пользователей!</p>
                        <div class="highlight-box">
                            🎉 <strong>Скидка 30%</strong> — на все тарифы Старт и Комфорт весь июль!
                        </div>
                        <p><strong>Условия акции:</strong></p>
                        <ul>
                            <li>Срок: 1 Июля — 31 Июля 2026</li>
                            <li>Тарифы: Старт и Комфорт</li>
                            <li>Скидка применяется автоматически</li>
                            <li>Действует для любого способа оплаты</li>
                            <li>Количество поездок в день не ограничено</li>
                        </ul>
                        <p>Скачайте Orbita Go прямо сейчас и пользуйтесь скидкой!</p>`
                },
                en: {
                    tag: 'Promo', date: 'July 1, 2026',
                    title: 'Summer Promo: 30% Off All Taxi Fares!',
                    body: `
                        <p>This July, Orbita Go Taxi is announcing a special summer promotion for all users!</p>
                        <div class="highlight-box">
                            🎉 <strong>30% discount</strong> — on all Start and Comfort fares, all through July!
                        </div>
                        <p><strong>Promotion terms:</strong></p>
                        <ul>
                            <li>Period: July 1 — July 31, 2026</li>
                            <li>Fares: Start and Comfort</li>
                            <li>Discount is applied automatically</li>
                            <li>Valid for any payment method</li>
                            <li>No daily ride limit</li>
                        </ul>
                        <p>Download Orbita Go now and enjoy the discount on every ride!</p>`
                }
            };
            return c[lang] || c.uz;
        }
    }
};

function openNewsModal(articleId) {
    const article = NEWS_ARTICLES[articleId];
    if (!article) return;
    const lang = localStorage.getItem('orbita_lang') || 'uz';
    const content = article.getContent(lang);
    const overlay = document.getElementById('news-modal');

    // Fill tag
    const tagEl = document.getElementById('nm-tag');
    tagEl.className = 'news-tag ' + article.tagClass;
    tagEl.textContent = content.tag;

    // Fill date
    document.querySelector('#nm-date span').textContent = content.date;

    // Fill icon
    const iconEl = document.getElementById('nm-icon');
    iconEl.innerHTML = article.icon;
    iconEl.style.cssText = article.iconStyle;

    // Fill title & body
    document.getElementById('nm-title').textContent = content.title;
    document.getElementById('nm-body').innerHTML = content.body;

    overlay.classList.add('open');
    document.body.style.overflow = 'hidden';
}

function closeNewsModal() {
    const overlay = document.getElementById('news-modal');
    if (overlay) { overlay.classList.remove('open'); document.body.style.overflow = ''; }
}

document.addEventListener('DOMContentLoaded', () => {
    // News card buttons → open article modal
    document.querySelectorAll('.news-card__btn').forEach((btn, i) => {
        btn.addEventListener('click', e => { e.preventDefault(); openNewsModal(i + 1); });
    });

    // News modal close
    const nmClose = document.getElementById('news-modal-close');
    if (nmClose) nmClose.addEventListener('click', closeNewsModal);
    const nmOverlay = document.getElementById('news-modal');
    if (nmOverlay) nmOverlay.addEventListener('click', e => { if (e.target === nmOverlay) closeNewsModal(); });

    // Load ecosystem configurations dynamically
    loadEcosystemSettings();
});

/* ============================================================
   DYNAMIC ECOSYSTEM SETTINGS LOAD
   ============================================================ */
async function loadEcosystemSettings() {
    try {
        const res = await fetch(`${API_BASE}/api/settings`);
        const d = await res.json();
        if (d.success && d.settings) {
            applyEcosystemSettings(d.settings);
        }
    } catch (err) {
        console.warn('Failed to load dynamic ecosystem settings, using static fallbacks.', err);
    }
}

function applyEcosystemSettings(s) {
    if (!s) return;
    
    // 1. Update contact phone numbers and links
    if (s.company?.phone) {
        const phoneLinks = document.querySelectorAll('a[href^="tel:"]');
        phoneLinks.forEach(link => {
            link.href = `tel:${s.company.phone.replace(/[^+\\d]/g, '')}`;
            // If the innerText is a phone number, update it
            if (link.textContent.includes('+998') || link.textContent.includes('030')) {
                link.textContent = s.company.phone;
            }
        });
    }

    // 2. Update contact email
    if (s.company?.email) {
        // Find elements containing email icon/text
        const emailElements = document.querySelectorAll('.footer-contact p');
        emailElements.forEach(p => {
            if (p.querySelector('ion-icon[name="mail-outline"]')) {
                p.innerHTML = `<ion-icon name="mail-outline"></ion-icon> ${s.company.email}`;
            }
        });
    }

    // 3. Update Telegram link
    if (s.company?.telegram) {
        const tgLinks = document.querySelectorAll('a[href*="t.me"]');
        tgLinks.forEach(link => {
            const username = s.company.telegram.replace('@', '');
            link.href = `https://t.me/${username}`;
        });
    }

    // 4. Update App Download links in the download modal
    if (s.downloads) {
        // Passenger link
        if (s.downloads.passenger) {
            const passengerGoogle = document.querySelector('.dl-app-primary a.dl-google');
            if (passengerGoogle) passengerGoogle.href = s.downloads.passenger;
        }
        // Driver link
        if (s.downloads.driver) {
            const driverGoogle = document.querySelector('.dl-app-card:nth-child(2) a.dl-google');
            if (driverGoogle) driverGoogle.href = s.downloads.driver;
        }
        // Walk link
        if (s.downloads.walk) {
            const walkGoogle = document.querySelector('.dl-app-card:nth-child(3) a.dl-google');
            if (walkGoogle) walkGoogle.href = s.downloads.walk;
        }
        // Games link
        if (s.downloads.games) {
            const gamesGoogle = document.querySelector('.dl-app-card:nth-child(4) a.dl-google');
            if (gamesGoogle) gamesGoogle.href = s.downloads.games;
        }
    }

    // 5. Update Taxi Pricing configurations
    if (s.taxiPricing) {
        GLOBAL_TAXI_PRICES = {
            START: s.taxiPricing.startBase || 5000,
            startKm: s.taxiPricing.startKm || 1200,
            KOMFORT: s.taxiPricing.komfortBase || 8000,
            komfortKm: s.taxiPricing.komfortKm || 1600,
            BIZNES: s.taxiPricing.biznesBase || 12000,
            biznesKm: s.taxiPricing.biznesKm || 2200
        };
        
        // Update landing page UI base price labels
        const pStart = document.getElementById('price-start');
        const pKomfort = document.getElementById('price-komfort');
        const pBiznes = document.getElementById('price-biznes');
        if (pStart) pStart.textContent = `${GLOBAL_TAXI_PRICES.START.toLocaleString()} UZS`;
        if (pKomfort) pKomfort.textContent = `${GLOBAL_TAXI_PRICES.KOMFORT.toLocaleString()} UZS`;
        if (pBiznes) pBiznes.textContent = `${GLOBAL_TAXI_PRICES.BIZNES.toLocaleString()} UZS`;
    }
}
