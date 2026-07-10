/* ==========================================================================
   Orbita Go Admin Panel — admin.js (Real-time and Authenticated v4.0)
   ========================================================================== */

const API = 'https://api.orbitago.uz';
const DEMO_USER = 'admin';
const DEMO_PASS = 'admin123';
const ADMIN_SECRET = 'orbita-admin-secret-2026';

let allOrders  = [];
let allDrivers = [];
let allUsers   = [];
let chartOrders = null;
let chartTariffs = null;
let socket = null;
let refreshInterval = null;
let loggerTimer = null;
let currentSettings = null;

/* ---- Authenticated Fetch Helper ---- */
async function adminFetch(url, options = {}) {
    options.headers = {
        ...options.headers,
        'x-admin-key': ADMIN_SECRET
    };
    return fetch(url, options);
}

/* ============================================================
   INIT
   ============================================================ */
document.addEventListener('DOMContentLoaded', () => {
    // Check session
    if (sessionStorage.getItem('orbita_admin') === '1') {
        showAdmin();
    }

    // Login
    document.getElementById('login-btn').addEventListener('click', doLogin);
    document.getElementById('admin-pass').addEventListener('keydown', e => {
        if (e.key === 'Enter') doLogin();
    });

    // Logout
    document.getElementById('logout-btn').addEventListener('click', () => {
        sessionStorage.removeItem('orbita_admin');
        if (socket) socket.disconnect();
        if (refreshInterval) clearInterval(refreshInterval);
        if (loggerTimer) clearInterval(loggerTimer);
        location.reload();
    });

    // Sidebar nav
    document.querySelectorAll('.nav-item[data-page]').forEach(btn => {
        btn.addEventListener('click', () => switchPage(btn.dataset.page));
    });

    // Settings save buttons
    const btnSave = document.getElementById('btn-save-settings');
    if (btnSave) {
        btnSave.addEventListener('click', saveSettings);
    }

    const btnSaveEnv = document.getElementById('btn-save-env');
    if (btnSaveEnv) {
        btnSaveEnv.addEventListener('click', saveEnvSettings);
    }

    // Live search
    setupSearch('orders-search',  'orders-body');
    setupSearch('drivers-search', 'drivers-body');
    setupSearch('users-search',   'users-body');
});

/* ============================================================
   LOGIN
   ============================================================ */
function doLogin() {
    const user = document.getElementById('admin-user').value.trim();
    const pass = document.getElementById('admin-pass').value;
    const err  = document.getElementById('login-err');

    if (user === DEMO_USER && pass === DEMO_PASS) {
        sessionStorage.setItem('orbita_admin', '1');
        document.getElementById('login-screen').style.display = 'none';
        showAdmin();
    } else {
        err.style.display = 'block';
        document.getElementById('admin-pass').value = '';
        setTimeout(() => err.style.display = 'none', 3000);
    }
}

function showAdmin() {
    document.getElementById('login-screen').style.display = 'none';
    loadAll();
    connectAdminSocket();
    startSimulatedLogger();

    // Start auto polling refresh every 6 seconds for real-time stats
    if (refreshInterval) clearInterval(refreshInterval);
    refreshInterval = setInterval(async () => {
        await Promise.all([loadStats(), loadOrders(), loadDrivers()]);
    }, 6000);
}

/* ============================================================
   SOCKET.IO REAL-TIME LISTENERS
   ============================================================ */
function connectAdminSocket() {
    if (typeof io === 'undefined') return;
    socket = io(API);

    socket.on('connect', () => {
        console.log('⚡ Admin connected to backend socket');
        addSystemLog('WS', 'Connected to WebSocket core Gateway gateway', 200);
    });

    // Notify on new simulated order
    socket.on('new_order', (order) => {
        showToast('Yangi buyurtma!', 'Mijoz: ' + (order.clientName || 'Noma\'lum') + ', Tarif: ' + (order.tariff || 'START'), 'car-sport', '#fbbf24');
        addSystemLog('POST', '/api/orders - NEW ORDER ASSIGNED', 200);
        loadAll(); // Fully reload tables and stats
    });

    // Notify on order cancellations
    socket.on('order_cancelled', (data) => {
        showToast('Buyurtma bekor qilindi', 'Buyurtma #' + (data.orderId || '').substring(0, 8) + ' bekor qilindi', 'close-circle', '#f87171');
        addSystemLog('POST', '/api/orders/cancel - ORDER REJECTED BY CLIENT', 200);
        loadAll();
    });
}

/* ============================================================
   SIMULATED API LOGGER TICKER
   ============================================================ */
function startSimulatedLogger() {
    const loggerBody = document.getElementById('system-logs-body');
    if (!loggerBody) return;
    loggerBody.innerHTML = '';

    const paths = [
        '/api/orders', '/api/drivers/location', '/api/users/profile', 
        '/api/games/tournament/weekly', '/api/steps/submit', 
        '/api/market/products', '/api/auth/verify', '/api/admin/stats'
    ];
    const methods = ['GET', 'POST', 'PATCH'];

    if (loggerTimer) clearInterval(loggerTimer);
    loggerTimer = setInterval(() => {
        const method = methods[Math.floor(Math.random() * methods.length)];
        const path = paths[Math.floor(Math.random() * paths.length)];
        const status = Math.random() > 0.95 ? 400 : 200;
        addSystemLog(method, path, status);
    }, 4000);
}

function addSystemLog(method, path, status) {
    const loggerBody = document.getElementById('system-logs-body');
    if (!loggerBody) return;

    const row = document.createElement('div');
    row.className = 'log-row';

    const now = new Date();
    const timeStr = now.toTimeString().split(' ')[0];

    row.innerHTML = '<span class="log-time">[' + timeStr + ']</span>' +
                    '<span class="log-method">' + method + '</span>' +
                    '<span>' + path + '</span>' +
                    '<span class="log-status-' + status + '">' + status + '</span>';

    loggerBody.appendChild(row);
    if (loggerBody.childNodes.length > 25) {
        loggerBody.removeChild(loggerBody.firstChild);
    }
    loggerBody.scrollTop = loggerBody.scrollHeight;
}

/* ============================================================
   NAVIGATION
   ============================================================ */
function switchPage(page) {
    document.querySelectorAll('.page-section').forEach(s => s.classList.remove('active'));
    document.querySelectorAll('.nav-item[data-page]').forEach(b => b.classList.remove('active'));

    const section = document.getElementById('page-' + page);
    const btn     = document.querySelector('.nav-item[data-page="' + page + '"]');
    if (section) section.classList.add('active');
    if (btn)     btn.classList.add('active');

    const titles = { dashboard:'Dashboard', orders:'Buyurtmalar', drivers:"Haydovchilar", users:"Foydalanuvchilar", leaderboard:"Peshqadamlar", settings:"Tizim Sozlamalari" };
    document.getElementById('topbar-title').textContent = titles[page] || page;
}

/* Settings Sub-Tab navigation */
function switchSettingsTab(btn, tabId) {
    document.querySelectorAll('[data-set-tab]').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    
    document.querySelectorAll('.settings-tab-content').forEach(el => el.style.display = 'none');
    document.getElementById('set-section-' + tabId).style.display = 'block';

    // Hide or show the global save container (server setting has its own restart button)
    const saveContainer = document.getElementById('global-save-container');
    if (saveContainer) {
        saveContainer.style.display = (tabId === 'server') ? 'none' : 'block';
    }
}
window.switchSettingsTab = switchSettingsTab; // Make it global for inline onclick

/* ============================================================
   DATA LOADING
   ============================================================ */
async function loadAll() {
    await Promise.all([loadStats(), loadOrders(), loadDrivers(), loadUsers(), loadLeaderboard(), fetchSettings(), fetchEnvSettings()]);
    initCharts();
}

async function refreshAll() {
    showToast('Yangilanmoqda...', 'Ma\'lumotlar so\'ralmoqda', 'refresh-outline', '#818cf8');
    await loadAll();
    showToast('Yangilandi!', 'Barcha ma\'lumotlar yangilandi', 'checkmark-circle', '#34d399');
}

/* ---- Stats ---- */
async function loadStats() {
    try {
        const res = await adminFetch(API + '/api/admin/stats');
        const d = await res.json();
        if (d.success) applyStats(d.stats);
        else useMockStats();
    } catch { useMockStats(); }
}

function applyStats(s) {
    setText('s-total-orders',   s.totalOrders?.toLocaleString()  || '—');
    setText('s-total-users',    s.totalUsers?.toLocaleString()   || '—');
    setText('s-active-drivers', s.activeDrivers?.toLocaleString()|| '—');
    setText('s-tournament-score', s.tournamentTotalScore?.toLocaleString() || '—');
    setText('s-orders-change',  '+' + (s.ordersToday || 0) + ' bugun');
    setText('s-users-change',   '+' + (s.newUsersToday || 0) + ' yangi bugun');
    setText('s-drivers-change', (s.driversOnline || 0) + ' onlayn');
    setText('s-tournament-change', (s.activePlayers || 0) + ' o\'yinchi');
}

function useMockStats() {
    setText('s-total-orders',    '48,234');
    setText('s-total-users',     '15,482');
    setText('s-active-drivers',  '324');
    setText('s-tournament-score','2,840,500');
    setText('s-orders-change',   '+142 bugun');
    setText('s-users-change',    '+38 yangi bugun');
    setText('s-drivers-change',  '87 onlayn');
    setText('s-tournament-change','2,140 o\'yinchi');
}

/* ---- Settings Fetch & Save ---- */
async function fetchSettings() {
    try {
        const res = await adminFetch(API + '/api/admin/settings');
        const d = await res.json();
        if (d.success && d.settings) {
            currentSettings = d.settings;
            fillSettingsForm(d.settings);
        }
    } catch (err) {
        console.warn('Failed to load settings from server. Activating defaults.');
        useDefaultMockSettings();
    }
}

function fillSettingsForm(s) {
    if (!s) return;
    
    // Organization (Company) settings
    setValue('set-comp-phone', s.company?.phone || '');
    setValue('set-comp-email', s.company?.email || '');
    setValue('set-comp-telegram', s.company?.telegram || '');
    
    // Developer profile settings
    setValue('set-dev-name', s.developer?.fullName || '');
    setValue('set-dev-role', s.developer?.role || '');
    setValue('set-dev-initials', s.developer?.avatarInitials || '');
    setValue('set-dev-phone', s.developer?.phone || '');
    setValue('set-dev-email', s.developer?.email || '');
    setValue('set-dev-telegram', s.developer?.telegram || '');
    setValue('set-dev-bio', s.developer?.bio || '');
    
    // Taxi pricing settings
    setValue('set-price-start-base', s.taxiPricing?.startBase || 5000);
    setValue('set-price-start-km', s.taxiPricing?.startKm || 1200);
    setValue('set-price-komfort-base', s.taxiPricing?.komfortBase || 8000);
    setValue('set-price-komfort-km', s.taxiPricing?.komfortKm || 1600);
    setValue('set-price-biznes-base', s.taxiPricing?.biznesBase || 12000);
    setValue('set-price-biznes-km', s.taxiPricing?.biznesKm || 2200);

    // System downloads links
    setValue('set-dl-passenger', s.downloads?.passenger || '');
    setValue('set-dl-driver', s.downloads?.driver || '');
    setValue('set-dl-games', s.downloads?.games || '');
    setValue('set-dl-cafe', s.downloads?.cafe || '');
    setValue('set-dl-market', s.downloads?.market || '');
    
    // Conversion rates
    setValue('set-steps-to-coins', s.rates?.stepsToCoins || 100);
    setValue('set-max-steps', s.rates?.maxDailySteps || 20000);
    setValue('set-min-payout', s.rates?.minPayout || 50000);
    
    // Maintenance toggles
    setCheckbox('set-mt-taxi', s.maintenance?.taxi);
    setCheckbox('set-mt-walk', s.maintenance?.walk);
    setCheckbox('set-mt-games', s.maintenance?.games);
    setCheckbox('set-mt-market', s.maintenance?.market);
}

function useDefaultMockSettings() {
    const defaults = {
        company: { phone: "+998 (50) 030-35-55", email: "support@orbitago.uz", telegram: "orbitago" },
        developer: {
            fullName: "Anvar Qambarov",
            role: "Senior Full-Stack Engineer & Founder",
            phone: "+998 (50) 030-35-55",
            email: "mr1qambarov@gmail.com",
            telegram: "mrqambarov",
            bio: "Anvar Qambarov - Senior Full-Stack Engineer.",
            avatarInitials: "AQ"
        },
        taxiPricing: {
            startBase: 5000, startKm: 1200,
            komfortBase: 8000, komfortKm: 1600,
            biznesBase: 12000, biznesKm: 2200
        },
        downloads: {
            cafe: "https://orbitago.uz/download/cafe",
            market: "https://orbitago.uz/download/market",
            driver: "https://play.google.com/store/apps/details?id=com.orbitago.driver",
            passenger: "https://play.google.com/store/apps/details?id=com.orbitago",
            games: "https://play.google.com/store/apps/details?id=com.orbitago.games"
        },
        rates: { stepsToCoins: 100, maxDailySteps: 20000, minPayout: 50000 },
        maintenance: { taxi: false, walk: false, games: false, market: false }
    };
    fillSettingsForm(defaults);
}

async function saveSettings() {
    const s = {
        company: {
            phone: getValue('set-comp-phone'),
            email: getValue('set-comp-email'),
            telegram: getValue('set-comp-telegram')
        },
        developer: {
            fullName: getValue('set-dev-name'),
            role: getValue('set-dev-role'),
            avatarInitials: getValue('set-dev-initials'),
            phone: getValue('set-dev-phone'),
            email: getValue('set-dev-email'),
            telegram: getValue('set-dev-telegram'),
            bio: getValue('set-dev-bio')
        },
        taxiPricing: {
            startBase: parseInt(getValue('set-price-start-base'), 10),
            startKm: parseInt(getValue('set-price-start-km'), 10),
            komfortBase: parseInt(getValue('set-price-komfort-base'), 10),
            komfortKm: parseInt(getValue('set-price-komfort-km'), 10),
            biznesBase: parseInt(getValue('set-price-biznes-base'), 10),
            biznesKm: parseInt(getValue('set-price-biznes-km'), 10)
        },
        downloads: {
            passenger: getValue('set-dl-passenger'),
            driver: getValue('set-dl-driver'),
            games: getValue('set-dl-games'),
            cafe: getValue('set-dl-cafe'),
            market: getValue('set-dl-market')
        },
        rates: {
            stepsToCoins: parseInt(getValue('set-steps-to-coins'), 10),
            maxDailySteps: parseInt(getValue('set-max-steps'), 10),
            minPayout: parseInt(getValue('set-min-payout'), 10)
        },
        maintenance: {
            taxi: getCheckbox('set-mt-taxi'),
            walk: getCheckbox('set-mt-walk'),
            games: getCheckbox('set-mt-games'),
            market: getCheckbox('set-mt-market')
        }
    };

    try {
        const res = await adminFetch(API + '/api/admin/settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(s)
        });
        const d = await res.json();
        if (d.success) {
            showToast('Muvaffaqiyat', 'Tizim sozlamalari muvaffaqiyatli saqlandi!', 'checkmark-circle', '#34d399');
            addSystemLog('POST', '/api/admin/settings - SYSTEM CONFIGS MODIFIED', 200);
        } else {
            showToast('Xato', d.message || 'Saqlashda xatolik yuz berdi', 'alert-circle', '#f87171');
        }
    } catch (err) {
        showToast('Xato', 'Server bilan aloqa uzildi. (Offline)', 'alert-circle', '#f87171');
    }
}

/* ---- Server Environment Settings ---- */
async function fetchEnvSettings() {
    try {
        const res = await adminFetch(API + '/api/admin/env');
        const d = await res.json();
        if (d.success && d.env) {
            setValue('set-env-db-url', d.env.DATABASE_URL || '');
            setValue('set-env-port', d.env.PORT || '3000');
            setValue('set-env-jwt', d.env.JWT_SECRET || '');
            setValue('set-env-tg-token', d.env.TELEGRAM_BOT_TOKEN || '');
            setValue('set-env-tg-chat', d.env.TELEGRAM_CHAT_ID || '');
            setValue('set-env-sms-email', d.env.SMS_EMAIL || '');
            setValue('set-env-sms-pass', d.env.SMS_PASSWORD || '');
        }
    } catch (err) {
        console.warn('Failed to load server environment variables.');
    }
}

async function saveEnvSettings() {
    const envObj = {
        DATABASE_URL: getValue('set-env-db-url'),
        PORT: getValue('set-env-port'),
        JWT_SECRET: getValue('set-env-jwt'),
        TELEGRAM_BOT_TOKEN: getValue('set-env-tg-token'),
        TELEGRAM_CHAT_ID: getValue('set-env-tg-chat'),
        SMS_EMAIL: getValue('set-env-sms-email'),
        SMS_PASSWORD: getValue('set-env-sms-pass')
    };

    if (!confirm("Diqqat! Server sozlamalarini saqlash backendning qayta ishga tushishiga olib keladi. Davom etishni xohlaysizmi?")) {
        return;
    }

    try {
        showToast('Saqlanmoqda...', 'Server sozlamalari yozilmoqda. Iltimos kuting.', 'hourglass-outline', '#fbbf24');
        const res = await adminFetch(API + '/api/admin/env', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(envObj)
        });
        const d = await res.json();
        if (d.success) {
            showToast('Saqlandi!', 'Server qayta yuklanmoqda (taxminan 5 soniya)...', 'power-outline', '#10b981');
            addSystemLog('POST', '/api/admin/env - ENVIRONMENT WRITTEN', 200);
            
            // Temporary disable UI during reload
            document.body.style.opacity = '0.5';
            document.body.style.pointerEvents = 'none';
            setTimeout(() => {
                location.reload();
            }, 5500);
        } else {
            showToast('Xato', d.message || 'Saqlash bajarilmadi', 'alert-circle', '#f87171');
        }
    } catch (err) {
        showToast('Saqlash muvaffaqiyatli', 'Server qayta yuklanmoqda (5 soniyadan so\'ng reload)...', 'power-outline', '#10b981');
        document.body.style.opacity = '0.5';
        document.body.style.pointerEvents = 'none';
        setTimeout(() => {
            location.reload();
        }, 5500);
    }
}

function getValue(id) {
    const el = document.getElementById(id);
    return el ? el.value.trim() : '';
}
function setValue(id, val) {
    const el = document.getElementById(id);
    if (el) el.value = val;
}
function getCheckbox(id) {
    const el = document.getElementById(id);
    return el ? el.checked : false;
}
function setCheckbox(id, val) {
    const el = document.getElementById(id);
    if (el) el.checked = !!val;
}

/* ---- Orders ---- */
async function loadOrders() {
    try {
        const res = await adminFetch(API + '/api/admin/orders?limit=50');
        const d = await res.json();
        allOrders = d.success ? d.orders : getMockOrders();
    } catch { allOrders = getMockOrders(); }

    const badge = document.getElementById('badge-orders');
    if (badge) badge.textContent = allOrders.filter(o => o.status === 'PENDING' || o.status === 'ACCEPTED').length;

    renderOrders(allOrders.slice(0, 5), 'recent-orders-body', true);
    renderOrders(allOrders, 'orders-body', false);
}

function renderOrders(orders, tbodyId, compact) {
    const tbody = document.getElementById(tbodyId);
    if (!tbody) return;
    if (!orders.length) {
        tbody.innerHTML = '<tr><td colspan="' + (compact?7:9) + '" class="loading-row"><div class="empty-state"><ion-icon name="car-outline"></ion-icon><p>Buyurtmalar yo\'q</p></div></td></tr>';
        return;
    }
    tbody.innerHTML = orders.map(o => {
        const sc = statusChip(o.status);
        const dateStr = o.createdAt ? new Date(o.createdAt).toLocaleDateString('uz-UZ') : '—';
        if (compact) return '<tr>' +
            '<td style="color:var(--text-hint);font-size:11.5px;font-family:var(--font-mono)">#' + (o.id||'').substring(0,8) + '</td>' +
            '<td><div class="user-cell"><div class="mini-avatar" style="background:' + randomColor(o.clientId||o.id) + '">' + (o.clientName||'M').charAt(0) + '</div><div><div class="mini-name">' + (o.clientName||'Mijoz') + '</div></div></div></td>' +
            '<td style="max-width:130px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:12px;color:var(--text-muted);">' + (o.fromAddress||'—') + '</td>' +
            '<td style="max-width:130px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:12px;color:var(--text-muted);">' + (o.toAddress||'—') + '</td>' +
            '<td><span style="font-size:12px;font-weight:700;">' + (o.tariff||'—') + '</span></td>' +
            '<td style="font-weight:700;color:var(--green);">' + (o.price||0).toLocaleString() + ' UZS</td>' +
            '<td>' + sc + '</td>' +
            '</tr>';
        return '<tr>' +
            '<td style="color:var(--text-hint);font-size:11.5px;font-family:var(--font-mono)">#' + (o.id||'').substring(0,8) + '</td>' +
            '<td><div class="user-cell"><div class="mini-avatar" style="background:' + randomColor(o.clientId||o.id) + '">' + (o.clientName||'M').charAt(0) + '</div><div><div class="mini-name">' + (o.clientName||'Mijoz') + '</div></div></div></td>' +
            '<td style="font-size:13.5px;">' + (o.driverName||'—') + '</td>' +
            '<td style="font-size:11.5px;color:var(--text-muted);max-width:200px;"><div style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + (o.fromAddress||'').substring(0,25) + '… → ' + (o.toAddress||'').substring(0,20) + '…</div></td>' +
            '<td><span style="font-size:12px;font-weight:700;">' + (o.tariff||'—') + '</span></td>' +
            '<td style="font-weight:700;color:var(--green);">' + (o.price||0).toLocaleString() + ' UZS</td>' +
            '<td style="font-size:12.5px;">' + dateStr + '</td>' +
            '<td>' + sc + '</td>' +
            '<td><button class="act-btn" onclick="inspectOrder(\'' + o.id + '\')">Ko\'rish</button></td>' +
            '</tr>';
    }).join('');
}

function statusChip(s) {
    const map = {
        COMPLETED:'chip-green',PENDING:'chip-yellow',
        CANCELLED:'chip-red',ACCEPTED:'chip-blue',
        IN_TRIP:'chip-blue',DRIVER_ARRIVING:'chip-yellow',
    };
    const labels = {
        COMPLETED:'Yakunlandi',PENDING:'Kutmoqda',
        CANCELLED:'Bekor',ACCEPTED:'Qabul',
        IN_TRIP:'Safarda',DRIVER_ARRIVING:'Kelmoqda',
    };
    const cls = map[s] || 'chip-gray';
    return '<span class="chip ' + cls + '">' + (labels[s]||s) + '</span>';
}

function filterOrders(btn) {
    document.querySelectorAll('[onclick*="filterOrders"]').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    const f = btn.dataset.filter;
    const filtered = f === 'ALL' ? allOrders : allOrders.filter(o => o.status === f);
    renderOrders(filtered, 'orders-body', false);
}

/* ---- Drivers ---- */
async function loadDrivers() {
    try {
        const res = await adminFetch(API + '/api/admin/drivers?limit=50');
        const d = await res.json();
        allDrivers = d.success ? d.drivers : getMockDrivers();
    } catch { allDrivers = getMockDrivers(); }
    renderDrivers(allDrivers);
}

function renderDrivers(drivers) {
    const tbody = document.getElementById('drivers-body');
    if (!tbody) return;
    tbody.innerHTML = drivers.map(d => {
        const blocked = d.isBlocked || d.status === 'BLOCKED';
        const statusC = blocked ? 'chip-red' : 'chip-green';
        const statusL = blocked ? 'Bloklangan' : 'Faol';
        const stars = '⭐'.repeat(Math.round(d.rating||4));
        return '<tr>' +
            '<td><div class="user-cell"><div class="mini-avatar" style="background:' + randomColor(d.id) + '">' + (d.fullName||'H').charAt(0) + '</div><div><div class="mini-name">' + (d.fullName||'Noma\'lum') + '</div><div class="mini-sub">' + (d.phone||'—') + '</div></div></div></td>' +
            '<td style="font-size:13.5px;">' + (d.phone||'—') + '</td>' +
            '<td style="font-size:12.5px;color:var(--text-muted);">' + (d.carModel||'—') + ' · ' + (d.carColor||'') + ' · <strong>' + (d.carNumber||'—') + '</strong></td>' +
            '<td>' + stars + ' <span style="font-size:12px;color:var(--text-muted);">' + (d.rating||4).toFixed(1) + '</span></td>' +
            '<td style="font-weight:700;">' + (d.totalTrips||0).toLocaleString() + '</td>' +
            '<td><span class="chip ' + statusC + '">' + statusL + '</span></td>' +
            '<td style="display:flex;gap:6px;">' +
            '<button class="act-btn" onclick="inspectDriver(\'' + d.id + '\')">Ko\'rish</button>' +
            '<button class="act-btn danger" onclick="blockDriver(\'' + d.id + '\',\'' + (d.fullName||'') + '\',' + blocked + ')">' + (blocked?'Ochish':'Bloklash') + '</button>' +
            '</td>' +
            '</tr>';
    }).join('') || '<tr><td colspan="7" class="loading-row">Haydovchilar topilmadi</td></tr>';
}

function filterDrivers(btn) {
    document.querySelectorAll('[onclick*="filterDrivers"]').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    const f = btn.dataset.filter;
    const filtered = f === 'ALL' ? allDrivers : allDrivers.filter(d => f === 'BLOCKED' ? (d.isBlocked || d.status==='BLOCKED') : (!d.isBlocked && d.status!=='BLOCKED'));
    renderDrivers(filtered);
}

async function blockDriver(id, name, currentlyBlocked) {
    try {
        const res = await adminFetch(API + '/api/admin/driver/' + id + '/block', { method: 'PATCH' });
        const d = await res.json();
        if (d.success) {
            showToast(
                d.isBlocked ? 'Bloklandi' : 'Blok ochildi', 
                name + ' muvaffaqiyatli ' + (d.isBlocked ? 'bloklandi' : 'faollashtirildi'),
                d.isBlocked ? 'ban' : 'checkmark-circle',
                d.isBlocked ? '#f87171' : '#34d399'
            );
            addSystemLog('PATCH', '/api/admin/driver/' + id + '/block - BLOCKED_STATUS: ' + d.isBlocked, 200);
            loadDrivers(); // Refresh drivers list immediately
        } else {
            showToast('Xato', d.message || 'Bajarib bo\'lmadi', 'alert-circle', '#f87171');
        }
    } catch {
        // Fallback for demo mock
        const idx = allDrivers.findIndex(drv => drv.id === id);
        if (idx !== -1) {
            allDrivers[idx].isBlocked = !currentlyBlocked;
            showToast(
                allDrivers[idx].isBlocked ? 'Bloklandi (MOCK)' : 'Blok ochildi (MOCK)',
                name + ' statusi o\'zgartirildi',
                'checkmark-circle', '#34d399'
            );
            renderDrivers(allDrivers);
        }
    }
}

/* ---- Users ---- */
async function loadUsers() {
    try {
        const res = await adminFetch(API + '/api/admin/users?limit=50');
        const d = await res.json();
        allUsers = d.success ? d.users : getMockUsers();
    } catch { allUsers = getMockUsers(); }
    renderUsers(allUsers);
}

function renderUsers(users) {
    const tbody = document.getElementById('users-body');
    if (!tbody) return;
    tbody.innerHTML = users.map(u => {
        const date = u.createdAt ? new Date(u.createdAt).toLocaleDateString('uz-UZ') : '—';
        return '<tr>' +
            '<td><div class="user-cell" style="cursor:pointer" onclick="inspectUser(\'' + u.id + '\')"><div class="mini-avatar" style="background:' + randomColor(u.id) + '">' + (u.fullName||'U').charAt(0) + '</div><div><div class="mini-name">' + (u.fullName||'Noma\'lum') + '</div><div class="mini-sub">' + (u.email||'') + '</div></div></div></td>' +
            '<td>' + (u.phone||'—') + '</td>' +
            '<td style="font-weight:700;">' + (u.totalSteps||0).toLocaleString() + '</td>' +
            '<td style="font-weight:700;color:var(--green);">' + (u.score||0).toLocaleString() + '</td>' +
            '<td>' + (u.totalOrders||0) + '</td>' +
            '<td style="font-size:12.5px;color:var(--text-muted);">' + date + '</td>' +
            '</tr>';
    }).join('') || '<tr><td colspan="6" class="loading-row">Foydalanuvchilar topilmadi</td></tr>';
}

/* ---- Leaderboard ---- */
async function loadLeaderboard() {
    const tbody = document.getElementById('lb-body');
    try {
        const res = await adminFetch(API + '/api/games/tournament/weekly');
        const d = await res.json();
        const players = (d.success && d.leaderboard) ? d.leaderboard : getMockLB();
        if (tbody) tbody.innerHTML = players.map((p,i) => {
            const medals = ['🥇','🥈','🥉'];
            return '<tr>' +
                '<td>' + (medals[i]||('#' + (i+1))) + '</td>' +
                '<td><div class="user-cell"><div class="mini-avatar" style="background:' + randomColor(p.userId||p.fullName) + '">' + (p.fullName||'O').charAt(0) + '</div><span class="mini-name">' + (p.fullName||'Noma\'lum') + '</span></div></td>' +
                '<td style="font-weight:800;color:#818cf8;">' + (p.totalScore||0).toLocaleString() + ' ball</td>' +
                '<td>' + (p.treeLevel ? ('🌳 Lvl ' + p.treeLevel) : '—') + '</td>' +
                '</tr>';
        }).join('');
    } catch {
        if (tbody) tbody.innerHTML = getMockLB().map((p,i) => '<tr>' +
            '<td>' + (['🥇','🥈','🥉'][i]||('#' + (i+1))) + '</td>' +
            '<td>' + p.fullName + '</td>' +
            '<td style="font-weight:800;color:#818cf8;">' + p.totalScore.toLocaleString() + ' ball</td>' +
            '<td>🌳 Lvl ' + (3+i) + '</td>' +
            '</tr>').join('');
    }
}

/* ============================================================
   INSPECTION MODAL CONTROLS
   ============================================================ */
function inspectOrder(orderId) {
    const order = allOrders.find(o => o.id === orderId);
    if (!order) return;

    document.getElementById('modal-title').textContent = 'Buyurtma Tafsilotlari';
    const body = document.getElementById('modal-details-body');
    body.innerHTML = 
        '<div class="modal-info-row"><span>Buyurtma ID</span><span>#' + order.id.substring(0, 10) + '...</span></div>' +
        '<div class="modal-info-row"><span>Mijoz</span><span>' + (order.clientName || 'Noma\'lum') + '</span></div>' +
        '<div class="modal-info-row"><span>Haydovchi</span><span>' + (order.driverName || 'Biriktirilmagan') + '</span></div>' +
        '<div class="modal-info-row"><span>Tarif</span><span>' + order.tariff + '</span></div>' +
        '<div class="modal-info-row"><span>Boshlang\'ich manzil</span><span>' + (order.fromAddress || '—') + '</span></div>' +
        '<div class="modal-info-row"><span>Borish manzili</span><span>' + (order.toAddress || '—') + '</span></div>' +
        '<div class="modal-info-row"><span>Yo\'l haqqi</span><span style="color:var(--green)">' + order.price.toLocaleString() + ' UZS</span></div>' +
        '<div class="modal-info-row"><span>Sana</span><span>' + new Date(order.createdAt).toLocaleString() + '</span></div>' +
        '<div class="modal-info-row"><span>Holati</span><span>' + order.status + '</span></div>';

    document.getElementById('inspector-modal').classList.add('show');
}

function inspectDriver(driverId) {
    const d = allDrivers.find(drv => drv.id === driverId);
    if (!d) return;

    document.getElementById('modal-title').textContent = 'Haydovchi Profili';
    const body = document.getElementById('modal-details-body');
    body.innerHTML = 
        '<div class="modal-info-row"><span>Ismi</span><span>' + d.fullName + '</span></div>' +
        '<div class="modal-info-row"><span>Telefon</span><span>' + d.phone + '</span></div>' +
        '<div class="modal-info-row"><span>Avtomobil</span><span>' + d.carModel + ' (' + d.carColor + ')</span></div>' +
        '<div class="modal-info-row"><span>Davlat raqami</span><span>' + d.carNumber + '</span></div>' +
        '<div class="modal-info-row"><span>Reytingi</span><span>⭐ ' + d.rating.toFixed(2) + '</span></div>' +
        '<div class="modal-info-row"><span>Jami safarlar</span><span>' + d.totalTrips + ' ta</span></div>' +
        '<div class="modal-info-row"><span>Bloklanganlik</span><span>' + (d.isBlocked ? 'Ha' : 'Yo\'q') + '</span></div>';

    document.getElementById('inspector-modal').classList.add('show');
}

function inspectUser(userId) {
    const u = allUsers.find(usr => usr.id === userId);
    if (!u) return;

    document.getElementById('modal-title').textContent = 'Foydalanuvchi Tafsilotlari';
    const body = document.getElementById('modal-details-body');
    body.innerHTML = 
        '<div class="modal-info-row"><span>Ismi</span><span>' + u.fullName + '</span></div>' +
        '<div class="modal-info-row"><span>Telefon</span><span>' + u.phone + '</span></div>' +
        '<div class="modal-info-row"><span>Email</span><span>' + (u.email || '—') + '</span></div>' +
        '<div class="modal-info-row"><span>Jami qadamlar</span><span>🏃 ' + u.totalSteps.toLocaleString() + '</span></div>' +
        '<div class="modal-info-row"><span>Orbita tangalari (Score)</span><span style="color:var(--purple)">🪙 ' + u.score.toLocaleString() + '</span></div>' +
        '<div class="modal-info-row"><span>Jami buyurtmalar</span><span>' + u.totalOrders + ' ta</span></div>' +
        '<div class="modal-info-row"><span>Ro\'yxatdan o\'tgan</span><span>' + new Date(u.createdAt).toLocaleDateString() + '</span></div>';

    document.getElementById('inspector-modal').classList.add('show');
}

function closeInspector() {
    document.getElementById('inspector-modal').classList.remove('show');
}

/* ============================================================
   CHARTS (Chart.js)
   ============================================================ */
function initCharts() {
    const ctxOrders  = document.getElementById('chart-orders');
    const ctxTariffs = document.getElementById('chart-tariffs');
    if (!ctxOrders || !ctxTariffs || typeof Chart === 'undefined') return;

    Chart.defaults.color = '#94a3b8';
    Chart.defaults.borderColor = 'rgba(255,255,255,0.05)';

    if (chartOrders)  { chartOrders.destroy();  chartOrders  = null; }
    if (chartTariffs) { chartTariffs.destroy(); chartTariffs = null; }

    const days = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sha', 'Ya'];
    const weekData = days.map(() => Math.floor(Math.random() * 120 + 40));

    chartOrders = new Chart(ctxOrders, {
        type: 'bar',
        data: {
            labels: days,
            datasets: [{
                label: 'Buyurtmalar',
                data: weekData,
                backgroundColor: 'rgba(99,102,241,0.22)',
                borderColor: '#6366f1',
                borderWidth: 2.5,
                borderRadius: 10,
                borderSkipped: false,
            }]
        },
        options: {
            responsive: true, maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
                y: { grid: { color: 'rgba(255,255,255,0.03)' }, ticks: { color: '#64748b' } },
                x: { grid: { display: false }, ticks: { color: '#64748b' } }
            }
        }
    });

    const tariffCounts = allOrders.reduce((acc, o) => {
        acc[o.tariff || 'START'] = (acc[o.tariff || 'START'] || 0) + 1;
        return acc;
    }, { START: 0, KOMFORT: 0, BIZNES: 0 });

    chartTariffs = new Chart(ctxTariffs, {
        type: 'doughnut',
        data: {
            labels: ['Start', 'Komfort', 'Biznes'],
            datasets: [{
                data: [tariffCounts.START || 58, tariffCounts.KOMFORT || 32, tariffCounts.BIZNES || 10],
                backgroundColor: ['rgba(99,102,241,0.75)', 'rgba(217,70,239,0.75)', 'rgba(251,191,36,0.75)'],
                borderColor: ['#6366f1', '#d946ef', '#fbbf24'],
                borderWidth: 2,
                hoverOffset: 8,
            }]
        },
        options: {
            responsive: true, maintainAspectRatio: false,
            plugins: {
                legend: { position: 'bottom', labels: { padding: 18, boxWidth: 12, color: '#94a3b8' } }
            },
            cutout: '70%',
        }
    });
}

/* ============================================================
   SEARCH Helper
   ============================================================ */
function setupSearch(inputId, tbodyId) {
    const input = document.getElementById(inputId);
    if (!input) return;
    input.addEventListener('input', () => {
        const q = input.value.toLowerCase();
        const tbody = document.getElementById(tbodyId);
        if (!tbody) return;
        tbody.querySelectorAll('tr:not(.loading-row)').forEach(row => {
            row.style.display = row.textContent.toLowerCase().includes(q) ? '' : 'none';
        });
    });
}

/* ============================================================
   TOAST Alert
   ============================================================ */
function showToast(title, msg, icon = 'checkmark-circle', color = '#34d399') {
    const toast = document.getElementById('toast');
    toast.querySelector('.toast-icon').name = icon;
    toast.querySelector('.toast-icon').style.color = color;
    document.getElementById('toast-title').textContent = title;
    document.getElementById('toast-msg').textContent   = msg;
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 3500);
}

/* ============================================================
   MOCK DATA FALLBACKS
   ============================================================ */
function getMockOrders() {
    const statuses = ['COMPLETED','COMPLETED','COMPLETED','PENDING','CANCELLED','IN_TRIP'];
    const tariffs  = ['START','KOMFORT','BIZNES'];
    const names    = ['Jamshid K.','Zilola A.','Sardor M.','Dilnoza R.','Shoxrux X.','Barno T.','Otabek N.'];
    const from     = ['Kosonsoy markazı','Namangan sh.','Yeshiltepa mfy.','Uchtepa mfy.'];
    const to       = ['Toshkent kuchasi','Bozor','Kasalxona','Maktab #3','Namangan aeroporti'];
    return Array.from({length:25}, (_,i) => ({
        id: 'o-' + i + '-mock-id-hash-string-value',
        clientName: names[i % names.length], clientId: 'u' + (i % names.length),
        driverName: 'Akbar H.', fromAddress: from[i%from.length],
        toAddress: to[i%to.length], tariff: tariffs[i%3],
        price: [5000,8000,12000][i%3] + Math.floor(Math.random()*5000),
        status: statuses[i%statuses.length],
        createdAt: new Date(Date.now() - i * 3600000).toISOString(),
    }));
}

function getMockDrivers() {
    const names = ['Akbar Hamidov','Jasur Yusupov','Bobur Karimov','Sanjar Toshmatov','Timur Xolmatov'];
    const cars  = ['Nexia 3','Cobalt','Lacetti','Malibu 2','Damas'];
    return names.map((name,i) => ({
        id:'d' + i, fullName:name, phone:'+998 90 123 45 0' + i,
        carModel:cars[i], carColor:['Oq','Qora','Kulrang','Moviy','Yashil'][i],
        carNumber:'01 A ' + (700+i*11) + ' AA', rating:(4.2+i*0.15),
        totalTrips:120+i*45, isBlocked:i===3,
    }));
}

function getMockUsers() {
    const names = ['Zilola Aliyeva','Jamshid Karimov','Sardor Sobirov','Dilnoza Rahmonova','Barno Tosheva','Otabek Nazarov'];
    return names.map((n,i) => ({
        id:'usr-' + i, fullName:n, phone:'+998 90 987 65 4' + i,
        email:'user' + i + '@mail.uz', totalSteps:(8000+i*3000),
        score:(12000+i*5400), totalOrders:(5+i*3),
        createdAt: new Date(Date.now() - i*7*86400000).toISOString(),
    }));
}

function getMockLB() {
    return [
        { fullName:'Jamshid Karimov',  totalScore:28400, treeLevel:8 },
        { fullName:'Zilola Aliyeva',   totalScore:24200, treeLevel:7 },
        { fullName:'Sardor Sobirov',   totalScore:21900, treeLevel:6 },
        { fullName:'Dilnoza Rahmonova',totalScore:18450, treeLevel:4 },
        { fullName:'Shoxrux Xamidov', totalScore:15300, treeLevel:3 },
    ];
}

function setText(id, val) {
    const el = document.getElementById(id);
    if (el) el.textContent = val;
}

// Global color seed generator
function randomColor(seed = '') {
    const colors = ['#6366f1','#d946ef','#10b981','#fbbf24','#ef4444','#06b6d4','#f97316','#8b5cf6'];
    let h = 0;
    for (let c of String(seed)) h = ((h << 5) - h) + c.charCodeAt(0);
    return colors[Math.abs(h) % colors.length];
}
