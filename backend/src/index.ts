import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { createServer } from 'http';
import { Server } from 'socket.io';
import rateLimit from 'express-rate-limit';
import https from 'https';
import prisma from './lib/prisma';
import { queueManager } from './lib/queue';
import logger from './lib/logger';

import authRoutes from './routes/auth.routes';
import orderRoutes from './routes/order.routes';
import driverRoutes from './routes/driver.routes';
import gamesRoutes from './routes/games.routes';
import adminRoutes from './routes/admin.routes';

dotenv.config();

// ── ENV VALIDATION ────────────────────────────────────
const requiredEnvVars = ['JWT_SECRET', 'DATABASE_URL'];
const missingVars = requiredEnvVars.filter(v => !process.env[v]);
if (missingVars.length > 0) {
  console.error(`\n❌ FATAL: Quyidagi muhim ENV o'zgaruvchilar yo'q: ${missingVars.join(', ')}`);
  console.error('❌ .env faylini tekshiring va qaytadan ishga tushiring.\n');
  process.exit(1);
}

const app = express();
app.set('trust proxy', true);
const httpServer = createServer(app);
const PORT = process.env.PORT || 3001;
const NODE_ENV = process.env.NODE_ENV || 'development';

// ── CORS ──────────────────────────────────────────────
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
  : [];

const isOriginAllowed = (origin: string | undefined): boolean => {
  if (!origin || NODE_ENV === 'development') return true;
  if (allowedOrigins.includes(origin)) return true;
  // Faqat aniq orbitago.uz domeni yoki uning subdomenlari (nuqta bilan chegaralangan)
  try {
    const { hostname } = new URL(origin);
    if (hostname === 'orbitago.uz' || hostname.endsWith('.orbitago.uz')) return true;
  } catch {
    return false;
  }
  return false;
};

const io = new Server(httpServer, {
  cors: {
    origin: (origin, cb) => {
      if (isOriginAllowed(origin)) return cb(null, true);
      cb(new Error(`CORS: ${origin} ruxsat etilmagan`));
    },
    methods: ['GET', 'POST', 'PATCH', 'DELETE'],
    credentials: true,
  },
});

// Socket.io global ga saqlaymiz (routesda ishlatish uchun)
(global as any).io = io;

app.use(cors({
  origin: (origin, cb) => {
    if (isOriginAllowed(origin)) return cb(null, true);
    cb(new Error(`CORS: ${origin} ruxsat etilmagan`));
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-admin-key', 'x-webhook-token'],
  credentials: true,
}));

app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

const SENSITIVE_BODY_KEYS = ['password', 'code', 'otp', 'token', 'secret'];
function maskSensitive(body: any) {
  if (!body || typeof body !== 'object') return body;
  const masked: any = Array.isArray(body) ? [...body] : { ...body };
  for (const key of Object.keys(masked)) {
    if (SENSITIVE_BODY_KEYS.some(s => key.toLowerCase().includes(s))) {
      masked[key] = '***';
    }
  }
  return masked;
}

app.use((req, _res, next) => {
  const logMsg = `🌐 ${req.method} ${req.url} - body: ${JSON.stringify(maskSensitive(req.body))}`;
  console.log(logMsg);
  logger.info(logMsg);
  next();
});

// ── RATE LIMITING ─────────────────────────────────────
// Load-test bypass faqat production'dan tashqarida va faqat ENVdan o'qilgan qiymat bilan ishlaydi
const LOAD_TEST_BYPASS = process.env.LOAD_TEST_BYPASS_KEY;
const isLoadTestBypass = (req: express.Request) =>
  NODE_ENV !== 'production' && !!LOAD_TEST_BYPASS && req.headers['x-load-test'] === LOAD_TEST_BYPASS;

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 daqiqa
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Juda ko\'p so\'rov. 15 daqiqadan keyin urinib ko\'ring.' },
  skip: (req) => isLoadTestBypass(req) || req.path === '/api/emails/incoming' || req.path === '/api/health'
});

const authLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 daqiqa
  max: 20,
  message: { success: false, message: 'Juda ko\'p urinish. 5 daqiqadan keyin qaytadan urinib ko\'ring.' },
  skip: (req) => isLoadTestBypass(req)
});

app.use('/api', generalLimiter);
app.use('/api/auth', authLimiter);

// ── PUBLIC SETTINGS ENDPOINT ──────────────────────────
import fs from 'fs';
import path from 'path';

app.get('/api/settings', (_req, res) => {
  try {
    const filePath = path.join(__dirname, 'settings.json');
    if (fs.existsSync(filePath)) {
      const data = fs.readFileSync(filePath, 'utf8');
      res.json({ success: true, settings: JSON.parse(data) });
    } else {
      const defaults = {
        contact: {
          phone: "+998 (50) 030-35-55",
          email: "mr1qambarov@gmail.com",
          telegram: "mrqambarov"
        },
        downloads: {
          cafe: "https://orbitago.uz/download/cafe",
          market: "https://orbitago.uz/download/market",
          driver: "https://play.google.com/store/apps/details?id=com.orbitago.driver",
          passenger: "https://play.google.com/store/apps/details?id=com.orbitago",
          games: "https://play.google.com/store/apps/details?id=com.orbitago.games"
        },
        rates: {
          stepsToCoins: 100,
          maxDailySteps: 20000,
          minPayout: 50000
        },
        maintenance: {
          taxi: false,
          walk: false,
          games: false,
          market: false
        }
      };
      fs.writeFileSync(filePath, JSON.stringify(defaults, null, 2), 'utf8');
      res.json({ success: true, settings: defaults });
    }
  } catch (err: any) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── ROUTES ────────────────────────────────────────────
app.use('/api/auth',   authRoutes);
app.use('/api/order',  orderRoutes);
app.use('/api/driver', driverRoutes);
app.use('/api/games',  gamesRoutes);
app.use('/api/admin',  adminRoutes);

// Health Check — DB ping bilan
app.get('/api/health', async (_req, res) => {
  let dbStatus = 'unknown';
  let dbLatencyMs = 0;
  try {
    const start = Date.now();
    await prisma.$queryRaw`SELECT 1`;
    dbLatencyMs = Date.now() - start;
    dbStatus = 'ok';
  } catch {
    dbStatus = 'error';
  }

  let onlineDrivers = 0;
  let todayOrders = 0;
  try {
    if (dbStatus === 'ok') {
      onlineDrivers = await prisma.driverProfile.count({ where: { isOnline: true } });
      todayOrders = await prisma.order.count({
        where: { createdAt: { gte: new Date(new Date().setHours(0,0,0,0)) } }
      });
    }
  } catch (e) {
    // ignore
  }

  const uptime = process.uptime();
  const memUsage = process.memoryUsage();

  res.json({
    status: dbStatus === 'ok' ? 'ok' : 'degraded',
    message: 'Orbita Go Backend ✅',
    env: NODE_ENV,
    timestamp: new Date().toISOString(),
    uptime: `${Math.floor(uptime / 60)}m ${Math.floor(uptime % 60)}s`,
    db: {
      status: dbStatus,
      latencyMs: dbLatencyMs,
    },
    memory: {
      heapUsedMb: Math.round(memUsage.heapUsed / 1024 / 1024),
      heapTotalMb: Math.round(memUsage.heapTotal / 1024 / 1024),
    },
    stats: {
      onlineDrivers,
      todayOrders
    }
  });
});

interface Operator {
  telegramId: number;
  name: string;
  username?: string;
  status: 'online' | 'offline';
  lastActive: number;
}

const operatorsList = new Map<number, Operator>();

// Loyiha rahbarini dastlab oflayn holatda ro'yxatga qo'shamiz
operatorsList.set(99999999, {
  telegramId: 99999999,
  name: 'Akbar H.',
  username: 'akbar_director',
  status: 'offline',
  lastActive: Date.now() - 24 * 60 * 60 * 1000
});

function registerOperator(fromUser: any) {
  if (!fromUser) return;
  const operatorId = fromUser.id;
  
  // Ismini chiroyli formatda yig'amiz
  const firstName = fromUser.first_name || '';
  const lastName = fromUser.last_name || '';
  let operatorName = `${firstName} ${lastName}`.trim();
  if (!operatorName) {
    operatorName = fromUser.username || `Operator #${operatorId}`;
  }

  operatorsList.set(operatorId, {
    telegramId: operatorId,
    name: operatorName,
    username: fromUser.username,
    status: 'online',
    lastActive: Date.now()
  });
  console.log(`🤖 Operator yangilandi/ro'yxatdan o'tdi: ${operatorName}`);
}

// Telegram Notification Router
app.post('/api/telegram/notify', async (req, res) => {
  const { type, data } = req.body;
  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;

  if (!token || !chatId) {
    console.warn('⚠️ Telegram Bot Token yoki Chat ID topilmadi. Bildirishnoma faqat konsolga yozildi.');
    console.log('🤖 Telegram Log:', type, data);
    return res.json({ success: true, warning: 'ENV variables not set, logged to console' });
  }

  let text = '';
  if (type === 'order') {
    text = `🚖 <b>─── ORBITA GO TAKSI ───</b> 🚖\n` +
           `✨ <i>Yangi safar buyurtmasi (Simulyator)</i>\n\n` +
           `📍 <b>Qayerdan:</b>\n` +
           `┗ <code>${data.pickup}</code>\n\n` +
           `🏁 <b>Qayerga:</b>\n` +
           `┗ <code>${data.dest}</code>\n\n` +
           `📏 <b>Masofa:</b> <code>${data.distance}</code>\n` +
           `⏱ <b>Safar vaqti:</b> <code>${data.duration}</code>\n` +
           `🏷 <b>Tarif:</b> <code>${data.tariff}</code>\n` +
           `💵 <b>Jami to'lov:</b> <code>${data.price}</code>\n\n` +
           `👤 <b>Haydovchi:</b> <code>${data.driverName || 'Noma\'lum'}</code>\n` +
           `🚗 <b>Avtomobil:</b> <code>${data.driverCar || 'Noma\'lum'}</code>\n\n` +
           `🟢 <b>Navbatchi operatorlar:</b> <code>FAOL (Sardor M., Madina A.)</code>\n` +
           `📅 <b>Sana/Vaqt:</b> <i>${new Date().toLocaleString('uz-UZ')}</i>\n` +
           `───────────────────`;
  } else if (type === 'partner') {
    text = `🤝 <b>─── HAMKORLIK ARIZASI ───</b> 🤝\n` +
           `✨ <i>Yangi arizachi ma'lumotlari</i>\n\n` +
           `👤 <b>Ism:</b> <code>${data.name}</code>\n` +
           `📞 <b>Telefon:</b> <code>${data.phone}</code>\n` +
           `🏢 <b>Kompaniya/Faoliyat:</b> <code>${data.business}</code>\n\n` +
           `🟢 <b>Navbatchi operatorlar:</b> <code>FAOL (Sardor M., Madina A.)</code>\n` +
           `📅 <b>Sana/Vaqt:</b> <i>${new Date().toLocaleString('uz-UZ')}</i>\n` +
           `───────────────────`;
  } else if (type === 'subscribe') {
    text = `📧 <b>─── YANGI OBUNACHI ───</b> 📧\n` +
           `✨ <i>Newsletter xabarnomasi obunachisi</i>\n\n` +
           `📪 <b>Email:</b> <code>${data.email}</code>\n` +
           `📌 <b>Obuna bo'limi:</b> <code>${data.section.toUpperCase()}</code>\n\n` +
           `🟢 <b>Navbatchi operatorlar:</b> <code>FAOL (Sardor M., Madina A.)</code>\n` +
           `📅 <b>Sana/Vaqt:</b> <i>${new Date().toLocaleString('uz-UZ')}</i>\n` +
           `───────────────────`;
  } else if (type === 'donate') {
    text = `❤️ <b>─── DONAT BOSILISHI ───</b> ❤️\n` +
           `✨ <i>Rivojlanish uchun xayriya qilish istagi</i>\n\n` +
           `💰 <b>Tanlangan tizim:</b> <code>${data.method}</code>\n` +
           `💳 <b>Karta egasi:</b> <code>A.Qambarov</code>\n` +
           `💬 <b>Izoh:</b> <code>${data.comment || 'Izohsiz'}</code>\n\n` +
           `🟢 <b>Navbatchi operatorlar:</b> <code>FAOL (Sardor M., Madina A.)</code>\n` +
           `📅 <b>Sana/Vaqt:</b> <i>${new Date().toLocaleString('uz-UZ')}</i>\n` +
           `───────────────────`;
  }

  let replyMarkup = {};
  if (type === 'partner' || type === 'order') {
    replyMarkup = {
      inline_keyboard: [
        [
          { text: '✅ Bog\'lanildi', callback_data: `contacted` },
          { text: '❌ Rad etish', callback_data: `rejected` }
        ]
      ]
    };
  }

  const postData = JSON.stringify({
    chat_id: chatId,
    text: text,
    parse_mode: 'HTML',
    reply_markup: replyMarkup
  });

  const options = {
    hostname: 'api.telegram.org',
    port: 443,
    path: `/bot${token}/sendMessage`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData, 'utf8')
    }
  };

  try {
    const apiReq = https.request(options, (apiRes) => {
      let body = '';
      apiRes.on('data', (chunk) => body += chunk);
      apiRes.on('end', () => {
        console.log('🤖 Telegram API javobi:', body);
        res.json({ success: true, data: JSON.parse(body) });
      });
    });

    apiReq.on('error', (err) => {
      res.status(500).json({ success: false, error: err.message });
    });

    apiReq.write(postData);
    apiReq.end();
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Telegram Callback Webhook Endpoint
app.post('/api/telegram/callback', async (req, res) => {
  const { callback_query } = req.body;
  if (!callback_query) {
    return res.sendStatus(200);
  }
  try {
    await handleTelegramUpdate(req.body);
  } catch (err: any) {
    console.error('Webhook handleTelegramUpdate error:', err.message);
  }
  res.sendStatus(200);
});

// GET Active Operators Endpoint
app.get('/api/telegram/operators', (req, res) => {
  const now = Date.now();
  const list = Array.from(operatorsList.values()).map(op => {
    let isOnline = false;
    if (op.telegramId === 99999999) {
      isOnline = (now - op.lastActive) < 15 * 60 * 1000;
    } else {
      isOnline = (now - op.lastActive) < 2 * 60 * 60 * 1000; // 2 soat davomida online ko'rinadi
    }
    
    return {
      name: op.name,
      status: isOnline ? 'online' : 'offline'
    };
  });

  res.json(list);
});

// 404
app.use((_req, res) => {
  res.status(404).json({ success: false, message: 'Endpoint topilmadi' });
});

// Global error handler
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Server xatosi:', err.message);
  res.status(500).json({ success: false, message: 'Serverda xatolik' });
});

// ── SOCKET.IO ────────────────────────────────────────
io.on('connection', (socket) => {
  console.log(`🔌 Ulandi: ${socket.id}`);

  // Mijoz o'z xonasiga qo'shiladi
  socket.on('join_client_room', (clientId: string) => {
    socket.join(`client_${clientId}`);
    console.log(`👤 Mijoz ${clientId} xonaga qo'shildi`);
  });

  socket.on('join_user_room', (clientId: string) => {
    socket.join(`client_${clientId}`);
    console.log(`👤 Mijoz (user_room) ${clientId} xonaga qo'shildi`);
  });

  // Haydovchi o'z xonasiga qo'shiladi
  socket.on('join_driver_room', (driverId: string) => {
    socket.join(`driver_${driverId}`);
    console.log(`🚗 Haydovchi ${driverId} xonaga qo'shildi`);
  });

  socket.on('send_message', async (data: { orderId: string; senderId: string; senderRole: string; text: string }) => {
    const { orderId, senderId, senderRole, text } = data;
    try {
      const message = await prisma.message.create({
        data: { orderId, senderId, senderRole, text }
      });
      const order = await prisma.order.findUnique({ where: { id: orderId } });
      if (order) {
        io.to(`client_${order.clientId}`).emit('new_message', message);
        if (order.driverId) {
          io.to(`driver_${order.driverId}`).emit('new_message', message);
        }
      }
    } catch (err) {
      console.error('Socket chat message error:', err);
    }
  });

  socket.on('driver_location_update', async (data: { orderId: string; lat: number; lng: number }) => {
    const { orderId, lat, lng } = data;
    try {
      const order = await prisma.order.findUnique({ where: { id: orderId } });
      if (order && order.driverId) {
        await prisma.driverProfile.update({
          where: { userId: order.driverId },
          data: { currentLat: lat, currentLng: lng }
        });
        io.to(`client_${order.clientId}`).emit('driver_location_update', {
          orderId,
          lat,
          lng
        });
      }
    } catch (err) {
      console.error('Socket driver location update error:', err);
    }
  });

  // --- DUEL MODE ---
  socket.on('join_duel_queue', async (data: { userId: string, gameType: string }) => {
    const { userId, gameType } = data;
    try {
      await queueManager.joinQueue(gameType, userId);
      console.log(`🎮 User ${userId} joined duel queue for ${gameType}`);

      const match = await queueManager.getMatch(gameType);
      if (match) {
        const { p1, p2 } = match;
        const duelId = `duel_${Date.now()}`;
        const seed = Math.floor(Math.random() * 1000000);

        io.to(`client_${p1}`).emit('duel_start', { duelId, opponentId: p2, gameType, seed, isP1: true });
        io.to(`client_${p2}`).emit('duel_start', { duelId, opponentId: p1, gameType, seed, isP1: false });

        console.log(`🔥 Duel started: ${duelId} between ${p1} and ${p2}`);
      }
    } catch (err) {
      console.error('join_duel_queue error:', err);
    }
  });

  socket.on('leave_duel_queue', async (data: { userId: string, gameType: string }) => {
    const { userId, gameType } = data;
    try {
      await queueManager.leaveQueue(gameType, userId);
    } catch (err) {
      console.error('leave_duel_queue error:', err);
    }
  });

  socket.on('duel_progress', (data: { duelId: string, userId: string, opponentId: string, score: number }) => {
    io.to(`client_${data.opponentId}`).emit('opponent_progress', { score: data.score });
  });

  socket.on('duel_finish', (data: { duelId: string, userId: string, opponentId: string, score: number }) => {
    io.to(`client_${data.opponentId}`).emit('opponent_finished', { score: data.score });
  });

  socket.on('error', (err) => {
    console.error(`Socket xatosi ${socket.id}:`, err);
  });

  socket.on('disconnect', () => {
    console.log(`❌ Uzildi: ${socket.id}`);
  });
});

let lastUpdateId = 0;

async function handleTelegramUpdate(update: any) {
  const { callback_query } = update;
  if (!callback_query) return;

  // Register operator dynamically
  registerOperator(callback_query.from);

  const token = process.env.TELEGRAM_BOT_TOKEN;
  const callbackId = callback_query.id;

  // Format operator's full name
  const fromUser = callback_query.from;
  const firstName = fromUser.first_name || '';
  const lastName = fromUser.last_name || '';
  let operatorName = `${firstName} ${lastName}`.trim();
  if (!operatorName) {
    operatorName = fromUser.username || `Operator #${fromUser.id}`;
  }

  const originalText = callback_query.message.text || '';
  const messageId = callback_query.message.message_id;
  const chatId = callback_query.message.chat.id;
  const action = callback_query.data;

  let statusText = '';
  let answerText = 'Muvaffaqiyatli bajarildi!';

  if (action === 'contacted') {
    statusText = `\n\n✅ <b>Aloqaga chiqildi:</b> <code>${operatorName} tomondan</code>`;
    answerText = 'Aloqaga chiqildi!';
  } else if (action === 'rejected') {
    statusText = `\n\n❌ <b>Bekor qilindi:</b> <code>${operatorName} tomondan</code>`;
    answerText = 'Bekor qilindi!';
  } else if (action.startsWith('verify_drv:')) {
    const userId = action.split(':')[1];
    try {
      await prisma.$transaction([
        prisma.user.update({ where: { id: userId }, data: { isVerified: true } }),
        prisma.driverProfile.update({ where: { userId }, data: { isVerified: true, isOnline: true } })
      ]);
      statusText = `\n\n✅ <b>Tasdiqlandi va faollashtirildi:</b> <code>${operatorName} tomondan</code>`;
      answerText = 'Haydovchi muvaffaqiyatli tasdiqlandi!';
    } catch (e: any) {
      statusText = `\n\n⚠️ <b>Xatolik (Tasdiqlashda):</b> <code>${e.message}</code>`;
      answerText = 'Tasdiqlashda xatolik yuz berdi!';
    }
  } else if (action.startsWith('reject_drv:')) {
    const userId = action.split(':')[1];
    try {
      await prisma.$transaction([
        prisma.user.update({ where: { id: userId }, data: { isVerified: false } }),
        prisma.driverProfile.update({ where: { userId }, data: { isVerified: false, isOnline: false } })
      ]);
      statusText = `\n\n❌ <b>Rad etildi:</b> <code>${operatorName} tomondan</code>`;
      answerText = 'Haydovchilik so\'rovi rad etildi!';
    } catch (e: any) {
      statusText = `\n\n⚠️ <b>Xatolik (Rad etishda):</b> <code>${e.message}</code>`;
      answerText = 'Rad etishda xatolik yuz berdi!';
    }
  }

  const newText = originalText + statusText;

  // Answer Callback Query
  const answerData = JSON.stringify({
    callback_query_id: callbackId,
    text: answerText
  });

  const answerOptions = {
    hostname: 'api.telegram.org',
    port: 443,
    path: `/bot${token}/answerCallbackQuery`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(answerData, 'utf8')
    }
  };

  const answerReq = https.request(answerOptions);
  answerReq.on('error', (err) => console.error('Callback Answer Error (Polling):', err.message));
  answerReq.write(answerData);
  answerReq.end();

  // Edit Message Text to update status and remove inline buttons
  const editData = JSON.stringify({
    chat_id: chatId,
    message_id: messageId,
    text: newText,
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: []
    }
  });

  const editOptions = {
    hostname: 'api.telegram.org',
    port: 443,
    path: `/bot${token}/editMessageText`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(editData, 'utf8')
    }
  };

  const editReq = https.request(editOptions, (editRes) => {
    let editBody = '';
    editRes.on('data', (d) => editBody += d);
    editRes.on('end', () => {
      console.log('🤖 Telegram xabari yangilandi (Polling):', editBody);
    });
  });
  editReq.on('error', (err) => console.error('Message Edit Error (Polling):', err.message));
  editReq.write(editData);
  editReq.end();
}

function startPolling(token: string) {
  // First delete webhook to enable polling
  https.get(`https://api.telegram.org/bot${token}/deleteWebhook`, (res) => {
    res.resume();
    console.log('🤖 Telegram Webhook o\'chirildi (Polling rejimi faollashdi)');
    poll();
  });

  function poll() {
    const url = `https://api.telegram.org/bot${token}/getUpdates?offset=${lastUpdateId + 1}&timeout=30`;
    https.get(url, (apiRes) => {
      let body = '';
      apiRes.on('data', (d) => body += d);
      apiRes.on('end', () => {
        try {
          const data = JSON.parse(body);
          if (data.ok && data.result.length > 0) {
            for (const update of data.result) {
              lastUpdateId = update.update_id;
              handleTelegramUpdate(update);
            }
          }
        } catch (e) {
          // ignore error
        }
        setTimeout(poll, 1000);
      });
    }).on('error', (err) => {
      console.error('⚠️ Telegram Polling ulanish xatoligi:', err.message);
      setTimeout(poll, 5000);
    });
  }
}

// ── START ─────────────────────────────────────────────
httpServer.listen(PORT, () => {
  console.log('');
  console.log('🚀 ================================');
  console.log(`🚀  Orbita Go Backend`);
  console.log(`🚀  Port: ${PORT}`);
  console.log(`🚀  Mode: ${NODE_ENV}`);
  console.log(`🚀  URL: http://localhost:${PORT}`);
  console.log(`🚀  Tunnel: api.orbitago.uz -> :${PORT}`);
  if (NODE_ENV === 'development') {
    console.log(`🚀  Dev OTP: 123456 (hamma uchun)`);
  }
  console.log('🚀 ================================');
  console.log('');

  // Register Telegram Webhook or Start Polling fallback
  const token = process.env.TELEGRAM_BOT_TOKEN;
  if (token) {
    if (NODE_ENV === 'production') {
      const webhookUrl = `https://api.orbitago.uz/api/telegram/callback`;
      const setWebhookUrl = `https://api.telegram.org/bot${token}/setWebhook?url=${encodeURIComponent(webhookUrl)}`;
      https.get(setWebhookUrl, (apiRes) => {
        let body = '';
        apiRes.on('data', (d) => body += d);
        apiRes.on('end', () => {
          console.log('🤖 Telegram Webhook holati (Prod):', body);
        });
      }).on('error', (e) => {
        console.error('⚠️ Telegram Webhook o\'rnatishda xatolik:', e.message);
      });
    } else {
      // Local development -> use long polling
      startPolling(token);
    }
  }
});
