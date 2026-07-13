/* ==========================================================================
   Orbita Go — app.js v3.1
   Particle Canvas · Animated Counters · Scroll Reveal
   Hamburger Menu · FAQ Accordion · Confetti
   Leaflet.js Interactive Map · Multi-language · PWA Install
   ========================================================================== */

// Auto-detect API base: point directly to the live online server
const API_BASE = 'https://api.orbitago.uz';
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
    initCustomCursor();
    init3DTilt();
    initSpotlightCards();
    initTextRevealAnimations();
    initMagneticButtons();
    initClickRipple();
    initParallaxBlobs();
    initTaxiCanvasAnimation();
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
    const COUNT = 85;
    const COLORS = ['rgba(99,102,241,', 'rgba(217,70,239,', 'rgba(6,182,212,', 'rgba(168,85,247,'];
    
    // Warp speed factor for page load explosion
    let warpSpeed = 1;

    // Mouse coordinates tracker
    let mouse = { x: null, y: null, radius: 160 };
    window.addEventListener('mousemove', e => {
        mouse.x = e.clientX;
        mouse.y = e.clientY;
    }, { passive: true });
    window.addEventListener('mouseleave', () => {
        mouse.x = null;
        mouse.y = null;
    }, { passive: true });

    const resize = () => { W = canvas.width = window.innerWidth; H = canvas.height = window.innerHeight; };
    const mkP = () => ({
        x: Math.random() * W, y: Math.random() * H,
        size: Math.random() * 2 + 0.6,
        color: COLORS[Math.floor(Math.random() * COLORS.length)],
        alpha: Math.random() * 0.45 + 0.15,
        vx: (Math.random() - 0.5) * 0.5, vy: (Math.random() - 0.5) * 0.5,
        pulse: Math.random() * Math.PI * 2,
    });

    const draw = () => {
        ctx.clearRect(0, 0, W, H);
        
        // Handle trigger warp speed from preloader load event
        if (window.triggerWarp) {
            warpSpeed = 16;
            window.triggerWarp = false;
        }
        if (warpSpeed > 1) {
            warpSpeed *= 0.94; // Decelerate exponentially
            if (warpSpeed < 1.01) warpSpeed = 1;
        }

        // Draw standard connection lines between particles
        for (let i = 0; i < particles.length; i++) {
            for (let j = i + 1; j < particles.length; j++) {
                const dx = particles[i].x - particles[j].x, dy = particles[i].y - particles[j].y;
                const d = Math.sqrt(dx * dx + dy * dy);
                if (d < 125) {
                    ctx.beginPath();
                    ctx.strokeStyle = `rgba(99,102,241,${0.065 * (1 - d / 125)})`;
                    ctx.lineWidth = 0.5;
                    ctx.moveTo(particles[i].x, particles[i].y);
                    ctx.lineTo(particles[j].x, particles[j].y);
                    ctx.stroke();
                }
            }
        }
        
        // Update particles and connect to mouse
        particles.forEach(p => {
            p.pulse += 0.02;
            const a = p.alpha * (0.7 + 0.3 * Math.sin(p.pulse));
            
            // Connect to mouse and pull slightly
            if (mouse.x !== null && mouse.y !== null) {
                const dx = p.x - mouse.x;
                const dy = p.y - mouse.y;
                const dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < mouse.radius) {
                    ctx.beginPath();
                    // Multi-colored mouse trail link
                    ctx.strokeStyle = `rgba(217,70,239,${0.18 * (1 - dist / mouse.radius)})`;
                    ctx.lineWidth = 0.8;
                    ctx.moveTo(p.x, p.y);
                    ctx.lineTo(mouse.x, mouse.y);
                    ctx.stroke();
                    
                    // Pull particles towards the cursor dynamically (reduced pull during warp speed)
                    if (warpSpeed === 1) {
                        p.x -= dx * 0.015;
                        p.y -= dy * 0.015;
                    }
                }
            }
            
            ctx.beginPath(); 
            ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
            ctx.fillStyle = `${p.color}${a})`; 
            ctx.fill();
            
            // Apply velocities scaled by the warpSpeed multiplier
            p.x += p.vx * warpSpeed; 
            p.y += p.vy * warpSpeed;
            
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
/* ============================================================
   MOCKUP APP PROTOTYPE STATE MACHINE & DYNAMIC INTERACTION
   ============================================================ */
const MOCKUP_STATE = {
    balance: 42500,
    steps: 14832,
    treeLevel: 7,
    treeProgress: 72,
    waterDroplets: 3,
    transactions: [
        { label: '🚶 Qadam bonus', amount: '2,450', isPlus: true, color: 'var(--success-light)' },
        { label: '🚖 Taksi safar', amount: '15,000', isPlus: true, color: 'var(--success-light)' },
        { label: '🏆 Musobaqa yutug\'i', amount: '25,000', isPlus: true, color: 'var(--success-light)' }
    ]
};

let stepClicksCount = 0;
let isTaxiTripRunning = false;

window.mockupTaxiProgress = 0;
window.mockupTaxiSpeed = 0;

function updateMockupAppUI() {
    // 1. Update Steps
    const stepsCountEl = document.getElementById('mockup-steps-count');
    const stepsRingEl = document.getElementById('mockup-steps-ring');
    if (stepsCountEl) stepsCountEl.textContent = MOCKUP_STATE.steps.toLocaleString();
    if (stepsRingEl) {
        const circumference = 2 * Math.PI * 44; // ~276.46
        const progressPct = Math.min(MOCKUP_STATE.steps / 20000, 1);
        stepsRingEl.style.strokeDashoffset = circumference * (1 - progressPct);
    }

    // 2. Update Garden
    const treeLevelEl = document.getElementById('mockup-tree-level');
    const waterCountEl = document.getElementById('mockup-water-count');
    const treePercentEl = document.getElementById('sim-tree-percent');
    const treeProgressEl = document.getElementById('sim-tree-progress');
    if (treeLevelEl) treeLevelEl.textContent = `Lvl ${MOCKUP_STATE.treeLevel}`;
    if (waterCountEl) waterCountEl.textContent = MOCKUP_STATE.waterDroplets;
    if (treePercentEl) treePercentEl.textContent = `${MOCKUP_STATE.treeProgress}%`;
    if (treeProgressEl) treeProgressEl.style.width = `${MOCKUP_STATE.treeProgress}%`;

    // 3. Update Wallet & Transactions
    const walletBalanceEl = document.getElementById('mockup-wallet-balance');
    const txContainerEl = document.getElementById('mockup-tx-container');
    if (walletBalanceEl) walletBalanceEl.textContent = `${MOCKUP_STATE.balance.toLocaleString()} UZS`;
    
    if (txContainerEl) {
        txContainerEl.innerHTML = MOCKUP_STATE.transactions.map(tx => `
            <div class="mockup-tx-item">
                <span style="color: rgba(255,255,255,0.75);">${tx.label}</span>
                <strong style="color: ${tx.color || 'var(--success-light)'};">${tx.isPlus ? '+' : ''}${tx.amount} UZS</strong>
            </div>
        `).join('');
    }
}

function prependTransaction(label, amount, isPlus) {
    const color = isPlus ? 'var(--success-light)' : 'var(--red-color)';
    MOCKUP_STATE.transactions.unshift({ label, amount, isPlus, color });
    if (MOCKUP_STATE.transactions.length > 6) {
        MOCKUP_STATE.transactions.pop();
    }
}

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

    // 1. Simulate Steps Event
    const stepBtn = document.getElementById('btn-mockup-step');
    if (stepBtn) {
        stepBtn.addEventListener('click', () => {
            MOCKUP_STATE.steps += 350;
            MOCKUP_STATE.balance += 250;
            stepClicksCount++;
            
            // Earn water droplets every 3 steps simulated
            if (stepClicksCount % 3 === 0) {
                MOCKUP_STATE.waterDroplets++;
            }
            
            prependTransaction('🚶 Qadam bonus', '250', true);

            // Floating text feedback at button
            const coin = document.createElement('span');
            coin.className = 'floating-coin-effect';
            coin.textContent = '+250 UZS';
            coin.style.left = `${stepBtn.offsetLeft + stepBtn.offsetWidth / 2}px`;
            coin.style.top = `${stepBtn.offsetTop}px`;
            stepBtn.parentElement.appendChild(coin);
            
            setTimeout(() => coin.remove(), 800);
            updateMockupAppUI();
        });
    }

    // 2. Watering Tree Event
    const waterBtn = document.getElementById('btn-sim-water');
    if (waterBtn) {
        waterBtn.addEventListener('click', () => {
            if (MOCKUP_STATE.waterDroplets <= 0) {
                alert("Sug'orish uchun suv yetarli emas! Yurish (Walk) bo'limida qadam bosib suv yiging.");
                return;
            }
            MOCKUP_STATE.waterDroplets--;
            MOCKUP_STATE.treeProgress += 10;

            const container = waterBtn.closest('.sim-tab-content');
            if (container) {
                triggerTreeWaterEffect(container);
            }

            if (MOCKUP_STATE.treeProgress >= 100) {
                MOCKUP_STATE.treeProgress = 0;
                MOCKUP_STATE.treeLevel++;
                MOCKUP_STATE.balance += 5000;
                prependTransaction('🌳 Daraxt yutug\'i', '5,000', true);
                launchConfetti();
            }
            updateMockupAppUI();
        });
    }

    // 3. Redeem Coupon Event
    const redeemBtn = document.getElementById('btn-mockup-redeem');
    if (redeemBtn) {
        redeemBtn.addEventListener('click', () => {
            if (MOCKUP_STATE.balance < 10000) {
                alert("Balans yetarli emas! Avval qadam bosib yoki daraxt o'stirib pul yig'ing.");
                return;
            }
            MOCKUP_STATE.balance -= 10000;
            prependTransaction('🍔 KFC kupon xarid', '10,000', false);
            launchConfetti();
            updateMockupAppUI();
        });
    }

    // 4. Mockup Taxi Destination Picker
    const destBtns = document.querySelectorAll('.mockup-dest-btn');
    const taxiStatusEl = document.getElementById('mockup-taxi-status');
    destBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            if (isTaxiTripRunning) return;
            const dest = btn.dataset.dest;
            
            let price = 5000;
            if (dest === 'markaz') price = 7000;
            else if (dest === 'namangan') price = 12000;

            if (MOCKUP_STATE.balance < price) {
                alert("Yo'lkira uchun balans yetarli emas! Qadam bosib pul yig'ing.");
                return;
            }

            isTaxiTripRunning = true;
            destBtns.forEach(b => b.setAttribute('disabled', 'true'));
            
            // Set canvas animation active values
            window.mockupTaxiProgress = 0;
            window.mockupTaxiSpeed = 0.006;

            if (taxiStatusEl) taxiStatusEl.textContent = '🔍 Haydovchi qidirilmoqda...';

            setTimeout(() => {
                if (taxiStatusEl) taxiStatusEl.textContent = '🚖 Haydovchi kelmoqda...';
            }, 1800);

            setTimeout(() => {
                if (taxiStatusEl) taxiStatusEl.textContent = '🚀 Safar boshlandi...';
            }, 3600);

            setTimeout(() => {
                isTaxiTripRunning = false;
                destBtns.forEach(b => b.removeAttribute('disabled'));
                if (taxiStatusEl) taxiStatusEl.textContent = '🎉 Safar tugadi! Rahmat!';
                
                MOCKUP_STATE.balance -= price;
                prependTransaction('🚖 Taksi safar', price.toLocaleString(), false);
                updateMockupAppUI();
            }, 7200);
        });
    });

    // Populate initial values
    updateMockupAppUI();
}

/* ============================================================
   INTERACTIVE PHONE SCREEN ANIMATIONS (Canvas + Physical Particles)
   ============================================================ */
function initTaxiCanvasAnimation() {
    const canvas = document.getElementById('sim-taxi-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let w = canvas.width = canvas.offsetWidth;
    let h = canvas.height = canvas.offsetHeight;

    window.addEventListener('resize', () => {
        if (canvas.offsetWidth) {
            w = canvas.width = canvas.offsetWidth;
            h = canvas.height = canvas.offsetHeight;
        }
    }, { passive: true });

    const points = [
        { x: 30, y: 75 },
        { x: 90, y: 25 },
        { x: 130, y: 80 },
        { x: 180, y: 30 }
    ];

    let progress = 0;

    function getBezierPoint(t, p0, p1, p2, p3) {
        const cx = 3 * (p1.x - p0.x);
        const bx = 3 * (p2.x - p1.x) - cx;
        const ax = p3.x - p0.x - cx - bx;

        const cy = 3 * (p1.y - p0.y);
        const by = 3 * (p2.y - p1.y) - cy;
        const ay = p3.y - p0.y - cy - by;

        const xt = ((ax * t + bx) * t + cx) * t + p0.x;
        const yt = ((ay * t + by) * t + cy) * t + p0.y;

        return { x: xt, y: yt };
    }

    function animate() {
        const taxiScreen = document.getElementById('sim-screen-taxi');
        if (taxiScreen && taxiScreen.style.display !== 'none') {
            ctx.clearRect(0, 0, w, h);

            // Draw route grid lines in background
            ctx.strokeStyle = 'rgba(255,255,255,0.03)';
            ctx.lineWidth = 1;
            for (let i = 10; i < w; i += 20) {
                ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i, h); ctx.stroke();
            }
            for (let i = 10; i < h; i += 20) {
                ctx.beginPath(); ctx.moveTo(0, i); ctx.lineTo(w, i); ctx.stroke();
            }

            // Draw full curved route path in neon purple
            ctx.beginPath();
            ctx.strokeStyle = 'rgba(217, 70, 239, 0.15)';
            ctx.lineWidth = 4;
            ctx.lineCap = 'round';
            ctx.moveTo(points[0].x, points[0].y);
            for (let t = 0; t <= 1; t += 0.01) {
                const pt = getBezierPoint(t, points[0], points[1], points[2], points[3]);
                ctx.lineTo(pt.x, pt.y);
            }
            ctx.stroke();

            // Draw animated neon active path (tied to active taxi simulation state)
            if (isTaxiTripRunning) {
                progress = window.mockupTaxiProgress;
                window.mockupTaxiProgress += window.mockupTaxiSpeed;
                if (window.mockupTaxiProgress > 1) {
                    window.mockupTaxiProgress = 1;
                }
            } else {
                progress = 0;
            }

            ctx.beginPath();
            ctx.strokeStyle = 'var(--primary-light)';
            ctx.lineWidth = 4;
            ctx.lineCap = 'round';
            ctx.moveTo(points[0].x, points[0].y);
            for (let t = 0; t <= progress; t += 0.01) {
                const pt = getBezierPoint(t, points[0], points[1], points[2], points[3]);
                ctx.lineTo(pt.x, pt.y);
            }
            ctx.stroke();

            // Draw start and end pin pulses
            const drawPulseNode = (x, y, color) => {
                ctx.beginPath();
                ctx.arc(x, y, 4 + Math.sin(Date.now() * 0.015) * 2, 0, Math.PI * 2);
                ctx.fillStyle = color;
                ctx.shadowColor = color;
                ctx.shadowBlur = 8;
                ctx.fill();
                ctx.shadowBlur = 0;
            };
            drawPulseNode(points[0].x, points[0].y, '#6366f1'); // Start Pin
            drawPulseNode(points[3].x, points[3].y, '#ef4444'); // Dest Pin

            // Draw car on current progress point
            const carPos = getBezierPoint(progress, points[0], points[1], points[2], points[3]);
            
            // Draw glowing halo around car
            ctx.beginPath();
            ctx.arc(carPos.x, carPos.y, 11, 0, Math.PI * 2);
            ctx.fillStyle = 'rgba(251, 191, 36, 0.25)';
            ctx.shadowColor = '#fbbf24';
            ctx.shadowBlur = 10;
            ctx.fill();
            ctx.shadowBlur = 0;

            // Draw yellow car dot
            ctx.beginPath();
            ctx.arc(carPos.x, carPos.y, 5, 0, Math.PI * 2);
            ctx.fillStyle = '#fbbf24';
            ctx.strokeStyle = '#fff';
            ctx.lineWidth = 1.5;
            ctx.fill();
            ctx.stroke();
        }
        requestAnimationFrame(animate);
    }
    animate();
}

function triggerTreeWaterEffect(container) {
    // Create 8 water droplets falling from top
    for (let i = 0; i < 8; i++) {
        const drop = document.createElement('div');
        drop.className = 'water-particle';
        drop.style.left = `${45 + Math.random() * 10}%`;
        drop.style.top = '15%';
        container.appendChild(drop);
        
        const angle = (Math.random() * 30 + 75) * (Math.PI / 180);
        const speed = Math.random() * 3 + 5;
        const vx = Math.cos(angle) * speed * (Math.random() > 0.5 ? 1 : -1) * 0.25;
        let vy = Math.sin(angle) * speed;
        
        let posX = 0, posY = 0;
        let opacity = 1;
        
        const flow = () => {
            posX += vx;
            posY += vy;
            vy += 0.3; // gravity
            opacity -= 0.04;
            
            drop.style.transform = `translate3d(${posX}px, ${posY}px, 0)`;
            drop.style.opacity = opacity;
            
            if (opacity > 0) requestAnimationFrame(flow);
            else drop.remove();
        };
        requestAnimationFrame(flow);
    }
    
    // Create 10 floating green leaf particles bursting outwards from center
    for (let i = 0; i < 10; i++) {
        const leaf = document.createElement('div');
        leaf.className = 'leaf-particle';
        leaf.style.left = '50%';
        leaf.style.top = '40%';
        container.appendChild(leaf);
        
        const angle = Math.random() * Math.PI * 2;
        const speed = Math.random() * 4 + 3;
        const vx = Math.cos(angle) * speed;
        let vy = Math.sin(angle) * speed - 2; // push up initially
        let rotation = Math.random() * 360;
        const spin = (Math.random() - 0.5) * 12;
        
        let posX = 0, posY = 0;
        let opacity = 1;
        
        const floatLeaf = () => {
            posX += vx;
            posY += vy;
            vy += 0.08; // subtle leaf weight
            opacity -= 0.025;
            rotation += spin;
            
            leaf.style.transform = `translate3d(${posX}px, ${posY}px, 0) rotate(${rotation}deg)`;
            leaf.style.opacity = opacity;
            
            if (opacity > 0) requestAnimationFrame(floatLeaf);
            else leaf.remove();
        };
        requestAnimationFrame(floatLeaf);
    }

    // Shake the tree
    const treeIcon = document.getElementById('sim-tree-icon');
    if (treeIcon) {
        let count = 0;
        const shake = () => {
            count++;
            if (count < 10) {
                treeIcon.style.transform = `scale(1.1) rotate(${(count % 2 === 0 ? 8 : -8)}deg)`;
                setTimeout(shake, 45);
            } else {
                treeIcon.style.transform = 'scale(1) rotate(0deg)';
            }
        };
        shake();
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
   NEWS SECTION — backend'dan dinamik yuklanadi (/api/news)
   ============================================================ */
let NEWS_POSTS = [];

const NEWS_TAG_CLASS = { feature: 'news-tag--feature', update: 'news-tag--update', promo: 'news-tag--promo', event: 'news-tag--event' };

function formatNewsDate(iso) {
    const d = new Date(iso);
    const months = ['Yanvar','Fevral','Mart','Aprel','May','Iyun','Iyul','Avgust','Sentyabr','Oktyabr','Noyabr','Dekabr'];
    return `${d.getDate()} ${months[d.getMonth()]} ${d.getFullYear()}`;
}

function newsCardHtml(post, i) {
    const iconColorClass = post.iconColor && post.iconColor !== 'default' ? ` news-card__icon--${post.iconColor}` : '';
    return `
        <article class="news-card${post.isFeatured ? ' news-card--featured' : ''} reveal-up" style="--delay: ${i * 0.1}s">
            <div class="news-card__glow"></div>
            <div class="news-card__top">
                <span class="news-tag ${NEWS_TAG_CLASS[post.tag] || 'news-tag--update'}">${post.tagLabel}</span>
                <span class="news-date"><ion-icon name="calendar-outline"></ion-icon> <span>${formatNewsDate(post.publishedAt)}</span></span>
            </div>
            <div class="news-card__icon${iconColorClass}">
                <ion-icon name="${post.icon}"></ion-icon>
            </div>
            <h3 class="news-card__title">${post.title}</h3>
            <p class="news-card__desc">${post.description}</p>
            <a href="#" class="news-card__btn" data-news-id="${post.id}">
                <span data-i18n="news.readmore">Batafsil o'qish</span>
                <ion-icon name="arrow-forward-outline"></ion-icon>
            </a>
        </article>`;
}

async function loadNews() {
    const grid = document.getElementById('news-grid');
    if (!grid) return;
    try {
        const res = await fetch(`${API_BASE}/api/news`);
        const data = await res.json();
        NEWS_POSTS = (data && data.news) || [];
        if (!NEWS_POSTS.length) { grid.innerHTML = ''; return; }
        grid.innerHTML = NEWS_POSTS.map(newsCardHtml).join('');
        grid.querySelectorAll('.news-card__btn').forEach(btn => {
            btn.addEventListener('click', e => { e.preventDefault(); openNewsModal(btn.dataset.newsId); });
        });
    } catch (e) {
        grid.innerHTML = '';
        console.warn('Yangiliklarni yuklab bo\'lmadi:', e);
    }
}

function openNewsModal(postId) {
    const post = NEWS_POSTS.find(p => p.id === postId);
    if (!post) return;
    const overlay = document.getElementById('news-modal');

    const tagEl = document.getElementById('nm-tag');
    tagEl.className = 'news-tag ' + (NEWS_TAG_CLASS[post.tag] || 'news-tag--update');
    tagEl.textContent = post.tagLabel;

    document.querySelector('#nm-date span').textContent = formatNewsDate(post.publishedAt);

    const iconEl = document.getElementById('nm-icon');
    iconEl.innerHTML = `<ion-icon name="${post.icon}"></ion-icon>`;
    iconEl.className = 'news-modal-icon' + (post.iconColor && post.iconColor !== 'default' ? ` news-card__icon--${post.iconColor}` : '');

    document.getElementById('nm-title').textContent = post.title;
    document.getElementById('nm-body').innerHTML = `<p>${post.description}</p>`;

    overlay.classList.add('open');
    document.body.style.overflow = 'hidden';
}

function closeNewsModal() {
    const overlay = document.getElementById('news-modal');
    if (overlay) { overlay.classList.remove('open'); document.body.style.overflow = ''; }
}

document.addEventListener('DOMContentLoaded', () => {
    loadNews();

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

/* ============================================================
   PREMIUM INTERACTIONS & ANIMATIONS
   ============================================================ */
function initCustomCursor() {
    if (window.matchMedia('(pointer: coarse)').matches) return;

    const ring = document.createElement('div');
    ring.className = 'custom-cursor-ring';
    const dot = document.createElement('div');
    dot.className = 'custom-cursor-dot';

    document.body.appendChild(ring);
    document.body.appendChild(dot);

    let ringX = 0, ringY = 0;
    let dotX = 0, dotY = 0;
    let mouseX = 0, mouseY = 0;

    document.addEventListener('mousemove', e => {
        mouseX = e.clientX;
        mouseY = e.clientY;
    }, { passive: true });

    const tick = () => {
        // Easing for lagging ring
        ringX += (mouseX - ringX) * 0.12;
        ringY += (mouseY - ringY) * 0.12;
        
        // Easing for dot (follows slightly faster)
        dotX += (mouseX - dotX) * 0.32;
        dotY += (mouseY - dotY) * 0.32;

        ring.style.transform = `translate3d(${ringX}px, ${ringY}px, 0)`;
        dot.style.transform = `translate3d(${dotX}px, ${dotY}px, 0)`;

        requestAnimationFrame(tick);
    };
    tick();

    // Re-check target elements dynamically
    const updateCursorHovers = () => {
        const hoverTargets = document.querySelectorAll('a, button, .feature-card, .tariff-card, .lang-btn, .faq-question, .news-card, .testimonial-card, .how-card, .partner-logo, .logo');
        hoverTargets.forEach(target => {
            if (target.dataset.hasCursorListener) return;
            target.dataset.hasCursorListener = 'true';
            target.addEventListener('mouseenter', () => {
                ring.classList.add('hover');
                dot.classList.add('hover');
            });
            target.addEventListener('mouseleave', () => {
                ring.classList.remove('hover');
                dot.classList.remove('hover');
            });
        });
    };

    updateCursorHovers();
    setInterval(updateCursorHovers, 2000);
}

function init3DTilt() {
    if (window.matchMedia('(pointer: coarse)').matches) return;
    
    const targets = document.querySelectorAll('.phone-mockup, .feature-card, .news-card, #booking-form');
    targets.forEach(target => {
        target.addEventListener('mousemove', e => {
            const rect = target.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            
            const centerX = rect.width / 2;
            const centerY = rect.height / 2;
            
            const rotateX = ((centerY - y) / centerY) * 9; // Max 9 degrees rotation for premium feel
            const rotateY = ((x - centerX) / centerX) * 9;
            
            const shadowX = -rotateY * 1.5;
            const shadowY = rotateX * 1.5;
            
            target.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) translateY(-4px)`;
            target.style.boxShadow = `${shadowX}px ${shadowY}px 35px rgba(99, 102, 241, 0.16), 0 20px 40px rgba(0, 0, 0, 0.65)`;
        }, { passive: true });
        
        target.addEventListener('mouseleave', () => {
            target.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg) translateY(0)';
            target.style.boxShadow = '';
        });
    });
}

function initSpotlightCards() {
    const cards = document.querySelectorAll('.feature-card, .news-card, .testimonial-card, .how-card, .tariff-card, #booking-form');
    cards.forEach(card => {
        card.addEventListener('mousemove', e => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            card.style.setProperty('--mouse-x', `${x}px`);
            card.style.setProperty('--mouse-y', `${y}px`);
        }, { passive: true });
    });
}

function initTextRevealAnimations() {
    const titles = document.querySelectorAll('.hero-content h1, .section-header h2, .simulator-form-container h2, .leaderboard-info h2');
    titles.forEach(title => {
        title.classList.add('reveal-text');
    });

    // Reveal hero title immediately
    const heroTitle = document.querySelector('.hero-content h1');
    if (heroTitle) {
        setTimeout(() => {
            heroTitle.classList.add('revealed');
        }, 150);
    }

    // Fail-safe fallback to ensure headers are never left invisible
    setTimeout(() => {
        titles.forEach(title => {
            if (!title.classList.contains('revealed')) {
                title.classList.add('revealed');
            }
        });
    }, 1500);
    
    const obs = new IntersectionObserver(entries => {
        entries.forEach(e => {
            if (e.isIntersecting) {
                e.target.classList.add('revealed');
                obs.unobserve(e.target);
            }
        });
    }, { threshold: 0.02 }); // Ultra-responsive intersection threshold
    
    titles.forEach(el => {
        if (!el.classList.contains('revealed')) {
            obs.observe(el);
        }
    });
}

function initMagneticButtons() {
    // Coarse pointer means touch screen (mobile), disable magnetic pull there
    if (window.matchMedia('(pointer: coarse)').matches) return;

    const magneticElems = document.querySelectorAll('.btn, .social-btn, .lang-btn, .logo, .sim-tab');
    magneticElems.forEach(el => {
        el.addEventListener('mousemove', e => {
            const rect = el.getBoundingClientRect();
            const x = e.clientX - rect.left - rect.width / 2;
            const y = e.clientY - rect.top - rect.height / 2;
            
            // Translate the button slightly towards the cursor (magnetic pull)
            el.style.transform = `translate3d(${x * 0.35}px, ${y * 0.35}px, 0) scale(1.03)`;
            el.style.boxShadow = '0 12px 28px rgba(99, 102, 241, 0.28)';
            el.style.transition = 'transform 0.08s linear, box-shadow 0.2s ease';
            
            // Subtly shift icon/text inside for 3D parallax depth
            const inner = el.querySelector('span, ion-icon');
            if (inner) {
                inner.style.transform = `translate3d(${x * 0.15}px, ${y * 0.15}px, 0)`;
                inner.style.transition = 'none';
            }
        });
        
        el.addEventListener('mouseleave', () => {
            el.style.transform = 'translate3d(0, 0, 0) scale(1)';
            el.style.boxShadow = '';
            el.style.transition = 'transform 0.4s cubic-bezier(0.25, 1, 0.5, 1), box-shadow 0.4s ease';
            
            const inner = el.querySelector('span, ion-icon');
            if (inner) {
                inner.style.transform = 'translate3d(0, 0, 0)';
                inner.style.transition = 'transform 0.4s cubic-bezier(0.25, 1, 0.5, 1)';
            }
        });
    });
}

/* ============================================================
   MODALS AND DONATION FLOW HELPERS (Extracted from index.html)
   ============================================================ */
let selectedDonateMethod = '';
let activeCardType = 'humo';
let activeCardNumber = '9860160430034589';

function showDonateModal(method) {
    selectedDonateMethod = method;
    document.getElementById('donate-modal-title').textContent = method + ' orqali donat';
    document.getElementById('donate-comment-input').value = ''; 
    document.getElementById('donate-amount-input').value = '20000'; 
    
    document.getElementById('donate-step-amount').style.display = 'block';
    document.getElementById('donate-step-card').style.display = 'none';
    document.getElementById('donate-modal').style.display = 'flex';
}

function closeDonateModal() {
    document.getElementById('donate-modal').style.display = 'none';
}

function setDonateAmount(val) {
    document.getElementById('donate-amount-input').value = val;
}

function goToDonateStep2() {
    const amountInput = document.getElementById('donate-amount-input').value;
    if (!amountInput || amountInput <= 0) {
        alert("Iltimos, xayriya miqdorini kiriting.");
        return;
    }

    document.getElementById('btn-pay-app-text').textContent = selectedDonateMethod + " ilovasida to'lash";
    selectDonationCard('humo', '9860160430034589');

    document.getElementById('donate-step-amount').style.display = 'none';
    document.getElementById('donate-step-card').style.display = 'block';
}

function goBackToDonateStep1() {
    document.getElementById('donate-step-amount').style.display = 'block';
    document.getElementById('donate-step-card').style.display = 'none';
}

function selectDonationCard(type, number) {
    activeCardType = type;
    activeCardNumber = number;

    const humoOpt = document.getElementById('card-option-humo');
    const visaOpt = document.getElementById('card-option-visa');
    const humoCheck = document.getElementById('card-check-humo');
    const visaCheck = document.getElementById('card-check-visa');

    if (!humoOpt || !visaOpt) return;

    if (type === 'humo') {
        humoOpt.style.borderColor = 'var(--primary-light)';
        humoOpt.style.opacity = '1';
        humoOpt.style.boxShadow = '0 10px 20px rgba(0,0,0,0.4)';
        humoCheck.setAttribute('name', 'checkbox');
        humoCheck.style.color = '#4ade80';

        visaOpt.style.borderColor = 'transparent';
        visaOpt.style.opacity = '0.7';
        visaOpt.style.boxShadow = '0 5px 10px rgba(0,0,0,0.3)';
        visaCheck.setAttribute('name', 'square-outline');
        visaCheck.style.color = 'rgba(255,255,255,0.4)';
    } else {
        visaOpt.style.borderColor = 'var(--primary-light)';
        visaOpt.style.opacity = '1';
        visaOpt.style.boxShadow = '0 10px 20px rgba(0,0,0,0.4)';
        visaCheck.setAttribute('name', 'checkbox');
        visaCheck.style.color = '#4ade80';

        humoOpt.style.borderColor = 'transparent';
        humoOpt.style.opacity = '0.7';
        humoOpt.style.boxShadow = '0 5px 10px rgba(0,0,0,0.3)';
        humoCheck.setAttribute('name', 'square-outline');
        humoCheck.style.color = 'rgba(255,255,255,0.4)';
    }
}

async function payViaApp() {
    const amount = document.getElementById('donate-amount-input').value;
    const comment = document.getElementById('donate-comment-input').value.trim() || 'Izohsiz';
    const payBtn = document.getElementById('btn-pay-app');

    payBtn.setAttribute('disabled', 'true');
    payBtn.style.opacity = '0.7';
    payBtn.textContent = 'Yuborilmoqda...';

    try {
        await window.sendTelegramNotification('donate', { 
            method: selectedDonateMethod + ` (${activeCardType.toUpperCase()})`,
            amount: `${Number(amount).toLocaleString()} UZS`,
            comment: comment
        });
    } catch (err) {
        console.error("Alert notify failed:", err);
    }

    let link = '';
    if (selectedDonateMethod.toLowerCase() === 'click') {
        link = `https://my.click.uz/services/p2p?card_number=${activeCardNumber}&amount=${amount}`;
        window.open(link, '_blank');
    } else {
        navigator.clipboard.writeText(activeCardNumber);
        alert("Payme uchun karta raqami nusxalandi! \nPayme ilovasiga o'tib, 'O'tkazmalar' bo'limida ushbu karta raqamini 'Joylashtirish' (Paste) qiling.");
        link = `https://payme.uz`;
        window.open(link, '_blank');
    }

    payBtn.textContent = 'Rahmat! ❤️';
    setTimeout(() => {
        closeDonateModal();
        payBtn.removeAttribute('disabled');
        payBtn.style.opacity = '1';
    }, 1000);
}

async function loadOperators() {
    const API_BASE = 'https://api.orbitago.uz';
    const container = document.getElementById('partner-operators-list');
    if (!container) return;

    try {
        const res = await fetch(API_BASE + '/api/telegram/operators');
        const operators = await res.json();
        
        if (operators.length === 0) {
            throw new Error("No active operators in backend");
        }

        container.innerHTML = operators.map(op => {
            const initials = op.name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase() || 'OP';
            const isOnline = op.status === 'online';
            const color = isOnline ? '#4ade80' : 'var(--text-hint)';
            const bg = isOnline ? 'rgba(99,102,241,0.15)' : 'rgba(255,255,255,0.05)';
            const statusText = isOnline ? 'Faol' : 'Oflayn';
            const glow = isOnline ? 'box-shadow: 0 0 8px #4ade80;' : '';

            return `
                <div style="display: flex; align-items: center; justify-content: space-between; font-size: 13px;">
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <div style="width: 28px; height: 28px; border-radius: 50%; background: ${bg}; display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: bold; color: #fff; font-family: sans-serif;">${initials}</div>
                        <span style="color: ${isOnline ? '#fff' : 'rgba(255,255,255,0.6)'}; font-weight: 600;">${op.name}</span>
                    </div>
                    <span style="color: ${color}; font-size: 12px; display: flex; align-items: center; gap: 4px; font-weight: 600;">
                        <span style="width: 6px; height: 6px; border-radius: 50%; background: ${color}; display: inline-block; ${glow}"></span>
                        ${statusText}
                    </span>
                </div>
            `;
        }).join('');
    } catch (e) {
        container.innerHTML = `
            <div style="display: flex; align-items: center; justify-content: space-between; font-size: 13px;">
                <div style="display: flex; align-items: center; gap: 8px;">
                    <div style="width: 28px; height: 28px; border-radius: 50%; background: rgba(99,102,241,0.15); display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: bold; color: #fff; font-family: sans-serif;">SM</div>
                    <span style="color: #fff; font-weight: 600;">Sardor M.</span>
                </div>
                <span style="color: #4ade80; font-size: 12px; display: flex; align-items: center; gap: 4px; font-weight: 600;">
                    <span style="width: 6px; height: 6px; border-radius: 50%; background: #4ade80; display: inline-block; box-shadow: 0 0 8px #4ade80;"></span>
                    Faol
                </span>
            </div>
            <div style="display: flex; align-items: center; justify-content: space-between; font-size: 13px; margin-top: 10px;">
                <div style="display: flex; align-items: center; gap: 8px;">
                    <div style="width: 28px; height: 28px; border-radius: 50%; background: rgba(217,70,239,0.15); display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: bold; color: #fff; font-family: sans-serif;">MA</div>
                    <span style="color: #fff; font-weight: 600;">Madina A.</span>
                </div>
                <span style="color: #4ade80; font-size: 12px; display: flex; align-items: center; gap: 4px; font-weight: 600;">
                    <span style="width: 6px; height: 6px; border-radius: 50%; background: #4ade80; display: inline-block; box-shadow: 0 0 8px #4ade80;"></span>
                    Faol
                </span>
            </div>
            <div style="display: flex; align-items: center; justify-content: space-between; font-size: 13px; margin-top: 10px;">
                <div style="display: flex; align-items: center; gap: 8px;">
                    <div style="width: 28px; height: 28px; border-radius: 50%; background: rgba(255,255,255,0.05); display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: bold; color: #aaa; font-family: sans-serif;">AK</div>
                    <span style="color: rgba(255,255,255,0.6); font-weight: 600;">Akmal K.</span>
                </div>
                <span style="color: var(--text-hint); font-size: 12px; display: flex; align-items: center; gap: 4px; font-weight: 600;">
                    <span style="width: 6px; height: 6px; border-radius: 50%; background: var(--text-hint); display: inline-block;"></span>
                    Oflayn
                </span>
            </div>
        `;
    }
}

function showPartnerModal() {
    document.getElementById('partner-modal').classList.add('open');
    loadOperators();
}
function closePartnerModal() {
    document.getElementById('partner-modal').classList.remove('open');
}

// Bind modal triggers globally
window.showDonateModal = showDonateModal;
window.closeDonateModal = closeDonateModal;
window.setDonateAmount = setDonateAmount;
window.goToDonateStep2 = goToDonateStep2;
window.goBackToDonateStep1 = goBackToDonateStep1;
window.selectDonationCard = selectDonationCard;
window.payViaApp = payViaApp;
window.showPartnerModal = showPartnerModal;
window.closePartnerModal = closePartnerModal;

document.addEventListener('DOMContentLoaded', () => {
    const partnerForm = document.getElementById('partner-form');
    if (partnerForm) {
        partnerForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const btn = document.getElementById('btn-submit-partner');
            const name = document.getElementById('partner-name').value;
            const phone = document.getElementById('partner-phone').value;
            const business = document.getElementById('partner-business').value;

            btn.setAttribute('disabled', 'true');
            btn.textContent = 'Yuborilmoqda...';

            try {
                await window.sendTelegramNotification('partner', { name, phone, business });
                btn.textContent = 'Muvaffaqiyatli yuborildi! ✅';
                setTimeout(() => {
                    closePartnerModal();
                    partnerForm.reset();
                    btn.removeAttribute('disabled');
                    btn.textContent = 'Yuborish';
                }, 1500);
            } catch {
                btn.textContent = 'Xatolik yuz berdi ❌';
                btn.removeAttribute('disabled');
            }
        });
    }
});

function initClickRipple() {
    document.addEventListener('click', e => {
        // Create shockwave ring at coordinate click point
        const ripple = document.createElement('div');
        ripple.className = 'click-ripple';
        ripple.style.left = `${e.clientX}px`;
        ripple.style.top = `${e.clientY}px`;
        document.body.appendChild(ripple);
        
        // Remove after animation completes
        setTimeout(() => {
            ripple.remove();
        }, 600);
    }, { passive: true });
}

function initParallaxBlobs() {
    if (window.matchMedia('(pointer: coarse)').matches) return;
    
    // Select glowing blobs and section backdrops
    const blobs = document.querySelectorAll('.hero-glow-1, .hero-glow-2, .features-section::before, .simulator-section::before');
    
    window.addEventListener('mousemove', e => {
        const x = (e.clientX - window.innerWidth / 2) * 0.025;
        const y = (e.clientY - window.innerHeight / 2) * 0.025;
        
        blobs.forEach(blob => {
            if (blob) {
                // translate background blobs opposite to mouse to simulate physical parallax depth
                blob.style.transform = `translate3d(${-x}px, ${-y}px, 0)`;
                blob.style.transition = 'transform 0.1s ease-out';
            }
        });

        // 3D Phone Mockup Tilt Effect
        const phone = document.querySelector('.phone-mockup');
        if (phone && window.innerWidth > 1024) {
            const rotX = (window.innerHeight / 2 - e.clientY) * 0.015;
            const rotY = (e.clientX - window.innerWidth / 2) * 0.015;
            phone.style.transform = `rotateX(${rotX}deg) rotateY(${rotY}deg)`;
        }
    }, { passive: true });
}



