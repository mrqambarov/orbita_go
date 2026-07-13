/* ==========================================================================
   Orbita Go — admin.routes.ts
   Admin Panel uchun Backend API Endpointlar
   ========================================================================== */

import { Router, Request, Response, NextFunction } from 'express';
import prisma from '../lib/prisma';
import fs from 'fs';
import path from 'path';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import https from 'https';

const router = Router();

/* ---- Admin foydalanuvchilari (parollar faqat server-side, bcrypt hash) ----
   Login: POST /api/admin/login { username, password } -> { token }
   Keyingi so'rovlar: x-admin-key: <token> (JWT, ADMIN_SECRET bilan imzolangan) */
const ADMIN_USERS: Record<string, { hash: string; role: string }> = {
    mrqambarov:   { hash: '$2a$10$LcCOe7XMWRZcwC7cgsIrNOo9D43aaTCA7tbhsnBLa4fnyfZsdO05q', role: 'SUPERADMIN' },
    operator:     { hash: '$2a$10$yx0eztrQfQQ2AYWZrLjop.J30PS53ABTDQYfVyABCCcHdriIW.PBq', role: 'OPERATOR' },
    bugalter:     { hash: '$2a$10$BTs77GZuvN7oKPm1u1106utbE6qRRObjlD7AdEMxwwOcZFLlG/ODC', role: 'BUGALTER' },
    boshqaruvchi: { hash: '$2a$10$YVMhw6vfcGpAfFmaJs3JMumpfB9oAV84OavIH5wMI9WB7sGCZyEjG', role: 'BOSHQARUVCHI' },
};

function getAdminSecret(): string {
    const secret = process.env.ADMIN_SECRET;
    if (!secret) throw new Error('ADMIN_SECRET .env da o\'rnatilmagan');
    return secret;
}

/* ============================================================
   POST /api/admin/login — Username/parol bilan JWT token olish
   ============================================================ */
router.post('/login', async (req: Request, res: Response) => {
    try {
        const { username, password } = req.body || {};
        const user = username ? ADMIN_USERS[username] : undefined;
        const valid = user && await bcrypt.compare(password || '', user.hash);
        if (!valid || !user) {
            res.status(401).json({ success: false, message: 'Login yoki parol noto\'g\'ri' });
            return;
        }
        const token = jwt.sign({ username, role: user.role }, getAdminSecret(), { expiresIn: '12h' });
        res.json({ success: true, token, role: user.role, username });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ---- Admin Auth Middleware (JWT) ---- */
const adminAuth = (req: Request, res: Response, next: NextFunction): void => {
    const key = (req.headers['x-admin-key'] || req.query.adminKey) as string | undefined;
    if (!key) {
        res.status(401).json({ success: false, message: "Admin privileges required" });
        return;
    }
    try {
        const payload = jwt.verify(key, getAdminSecret()) as { username: string; role: string };
        (req as any).admin = payload;
        next();
    } catch {
        res.status(401).json({ success: false, message: "Admin privileges required" });
    }
};

/* ============================================================
   POST /api/admin/emails/incoming — Public Webhook for incoming emails
   cPanel Email Pipe or webhook parses and posts here.
   ============================================================ */
router.post('/emails/incoming', async (req: Request, res: Response) => {
    try {
        const token = req.query.token || req.headers['x-webhook-token'];
        const validToken = process.env.EMAIL_WEBHOOK_SECRET;

        if (!validToken || token !== validToken) {
            res.status(401).json({ success: false, message: "Unauthorized webhook token" });
            return;
        }

        const { account, from, subject, body } = req.body;
        if (!account || !from || !subject || !body) {
            res.status(400).json({ success: false, message: "Missing required fields" });
            return;
        }

        const newEmail = await prisma.emailMessage.create({
            data: {
                account,
                from,
                subject,
                body
            }
        });

        res.json({ success: true, message: "Email message saved", id: newEmail.id });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

// Apply auth middleware to all admin endpoints
router.use(adminAuth);

/* ============================================================
   GET /api/admin/stats — Overall Statistics
   ============================================================ */
router.get('/stats', async (_req: Request, res: Response) => {
    try {
        const totalOrders = await prisma.order.count();
        const totalUsers = await prisma.user.count();
        const totalDrivers = await prisma.driverProfile.count();
        const activeDrivers = await prisma.driverProfile.count({ where: { isOnline: true } });
        const ordersToday = await prisma.order.count({
            where: { createdAt: { gte: new Date(new Date().setHours(0,0,0,0)) } }
        });
        const newUsersToday = await prisma.user.count({
            where: { createdAt: { gte: new Date(new Date().setHours(0,0,0,0)) } }
        });

        // Weekly tournament total score count
        let tournamentTotalScore = 0;
        try {
            const weekStart = new Date();
            weekStart.setDate(weekStart.getDate() - weekStart.getDay());
            weekStart.setHours(0,0,0,0);
            const agg = await (prisma as any).gameStat.aggregate({
                _sum: { highScore: true }
            });
            tournamentTotalScore = agg._sum?.highScore || 0;
        } catch { /* GameStat table custom fallback */ }

        res.json({
            success: true,
            stats: {
                totalOrders, totalUsers, totalDrivers, activeDrivers,
                ordersToday, newUsersToday, driversOnline: activeDrivers,
                tournamentTotalScore,
                activePlayers: Math.round(totalUsers * 0.14) || 0,
            }
        });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   GET /api/admin/analytics — Analytics Data for Charts
   ============================================================ */
router.get('/analytics', async (_req: Request, res: Response) => {
    try {
        const orderCounts = [];
        const days = ['Ya', 'Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sha'];
        const today = new Date();
        
        for (let i = 6; i >= 0; i--) {
            const d = new Date();
            d.setDate(today.getDate() - i);
            const startOfDay = new Date(d.setHours(0,0,0,0));
            const endOfDay = new Date(d.setHours(23,59,59,999));
            
            const count = await prisma.order.count({
                where: {
                    createdAt: {
                        gte: startOfDay,
                        lte: endOfDay
                    }
                }
            });
            const dayLabel = days[startOfDay.getDay()];
            orderCounts.push({ day: dayLabel, count });
        }

        const startCount = await prisma.order.count({ where: { tariff: 'START' } });
        const komfortCount = await prisma.order.count({ where: { tariff: 'KOMFORT' } });
        const biznesCount = await prisma.order.count({ where: { tariff: 'BIZNES' } });

        res.json({
            success: true,
            analytics: {
                ordersOverTime: orderCounts,
                tariffs: {
                    START: startCount,
                    KOMFORT: komfortCount,
                    BIZNES: biznesCount
                }
            }
        });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   GET /api/admin/logs — Read Winston System Logs
   ============================================================ */
router.get('/logs', async (req: Request, res: Response) => {
    try {
        const type = req.query.type as string || 'combined';
        const logFile = path.join(process.cwd(), 'logs', `${type}.log`);
        
        if (!fs.existsSync(logFile)) {
            res.json({ success: true, logs: ["Log file does not exist yet."] });
            return;
        }

        const data = fs.readFileSync(logFile, 'utf8');
        const lines = data.trim().split('\n').slice(-100).reverse();
        
        res.json({ success: true, logs: lines });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   GET /api/admin/orders — All Orders
   ============================================================ */
router.get('/orders', async (req: Request, res: Response) => {
    try {
        const limit  = Math.min(parseInt(req.query.limit as string) || 50, 200);
        const skip   = parseInt(req.query.skip as string) || 0;
        const status = req.query.status as string | undefined;

        const where: any = {};
        if (status && status !== 'ALL') where.status = status;

        const orders = await prisma.order.findMany({
            where,
            orderBy: { createdAt: 'desc' },
            take: limit,
            skip,
            include: {
                client: { select: { id: true, fullName: true, phoneNumber: true } },
                driver: { select: { id: true, fullName: true, phoneNumber: true } },
            }
        });
        const total = await prisma.order.count({ where });

        const mapped = orders.map(o => ({
            id:         o.id,
            clientId:   o.clientId,
            clientName: o.client?.fullName || '—',
            driverName: o.driver?.fullName || '—',
            fromAddress:o.fromAddress,
            toAddress:  o.toAddress,
            tariff:     o.tariff || 'START',
            price:      o.price || 0,
            status:     o.status,
            createdAt:  o.createdAt,
        }));

        res.json({ success: true, orders: mapped, total, limit, skip });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   GET /api/admin/drivers — Driver Profiles List
   ============================================================ */
router.get('/drivers', async (req: Request, res: Response) => {
    try {
        const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
        const skip  = parseInt(req.query.skip as string) || 0;

        const drivers = await prisma.driverProfile.findMany({
            orderBy: { createdAt: 'desc' },
            take: limit,
            skip,
            include: {
                user: { select: { fullName: true, phoneNumber: true } }
            }
        });
        const total = await prisma.driverProfile.count();

        const mapped = drivers.map(d => ({
            id: d.id,
            fullName: d.user?.fullName || '—',
            phone: d.user?.phoneNumber || '—',
            carModel: d.carModel,
            carColor: d.carColor,
            carNumber: d.carNumber,
            rating: d.rating,
            isBlocked: !d.isVerified, // Verify toggling maps to block/unblock logic
            isAvailable: d.isOnline,
            totalTrips: d.totalTrips,
            createdAt: d.createdAt,
        }));

        res.json({ success: true, drivers: mapped, total, limit, skip });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   GET /api/admin/users — Users List
   ============================================================ */
router.get('/users', async (req: Request, res: Response) => {
    try {
        const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
        const skip  = parseInt(req.query.skip as string) || 0;

        const users = await prisma.user.findMany({
            orderBy: { createdAt: 'desc' },
            take: limit,
            skip,
            include: {
                gameStats: true,
                _count: { select: { clientOrders: true } }
            }
        });
        const total = await prisma.user.count();

        const mapped = users.map(u => {
            const totalGameScore = u.gameStats.reduce((sum, stat) => sum + stat.highScore, 0);
            const gamesList = u.gameStats.map(s => `${s.gameType}: ${s.highScore}`).join(', ') || 'yo\'q';
            const loyaltyPoints = Math.round(u.totalStepsRedeemed / 100) + (u._count.clientOrders * 50);

            return {
                id: u.id,
                fullName: u.fullName || '—',
                phone: u.phoneNumber || '—',
                email: u.email || '',
                totalSteps: u.totalStepsRedeemed,
                walletBalance: u.walletBalance,
                score: u.walletBalance,
                isBlocked: !u.isVerified,
                totalOrders: u._count.clientOrders,
                createdAt: u.createdAt,
                loyaltyPoints,
                totalGameScore,
                gamesList
            };
        });

        res.json({ success: true, users: mapped, total, limit, skip });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   PATCH /api/admin/driver/:id/block — Block/Unblock Driver
   ============================================================ */
router.patch('/driver/:id/block', async (req: Request, res: Response) => {
    try {
        const driver = await prisma.driverProfile.findUnique({ where: { id: req.params.id } });
        if (!driver) {
            res.status(404).json({ success: false, message: "Driver profile not found" });
            return;
        }
        const updated = await prisma.driverProfile.update({
            where: { id: req.params.id },
            data: { isVerified: !driver.isVerified },
        });
        res.json({
            success: true,
            message: !updated.isVerified ? 'Driver blocked' : 'Driver active',
            isBlocked: !updated.isVerified,
        });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   PATCH /api/admin/driver/:id/car — Edit Driver Car Information
   ============================================================ */
router.patch('/driver/:id/car', async (req: Request, res: Response) => {
    try {
        const { carModel, carColor, carNumber } = req.body;
        if (!carModel || !carColor || !carNumber) {
            res.status(400).json({ success: false, message: "Barcha avtomobil ma'lumotlarini kiriting" });
            return;
        }
        
        const updated = await prisma.driverProfile.update({
            where: { id: req.params.id },
            data: { carModel, carColor, carNumber },
        });
        
        res.json({ success: true, message: "Avtomobil ma'lumotlari yangilandi", driver: updated });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   PATCH /api/admin/user/:id/block — Block/Unblock User
   ============================================================ */
router.patch('/user/:id/block', async (req: Request, res: Response) => {
    try {
        const user = await prisma.user.findUnique({ where: { id: req.params.id } });
        if (!user) {
            res.status(404).json({ success: false, message: "Foydalanuvchi topilmadi" });
            return;
        }
        
        const updated = await prisma.user.update({
            where: { id: req.params.id },
            data: { isVerified: !user.isVerified },
        });
        
        res.json({
            success: true,
            message: !updated.isVerified ? 'Foydalanuvchi bloklandi' : 'Foydalanuvchi blokdan chiqarildi',
            isBlocked: !updated.isVerified,
        });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   PATCH /api/admin/user/:id/balance — Update User Wallet Balance
   ============================================================ */
router.patch('/user/:id/balance', async (req: Request, res: Response) => {
    try {
        const { balance } = req.body;
        if (balance === undefined || isNaN(parseFloat(balance))) {
            res.status(400).json({ success: false, message: "Noto'g'ri balans qiymati" });
            return;
        }
        
        const user = await prisma.user.update({
            where: { id: req.params.id },
            data: { walletBalance: parseFloat(balance) },
        });
        
        // Tranzaksiya jurnaliga yozish
        await prisma.transaction.create({
            data: {
                userId: user.id,
                title: "Admin Balans Tuzatmasi",
                subtitle: "Tizim administratori tomonidan o'zgartirildi",
                amount: parseFloat(balance),
                isCredit: true,
                type: "TOPUP"
            }
        });
        
        res.json({ success: true, message: "Foydalanuvchi balansi yangilandi", balance: user.walletBalance });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   DELETE /api/admin/user/:id — Delete User Account
   ============================================================ */
router.delete('/user/:id', async (req: Request, res: Response) => {
    try {
        await prisma.user.delete({ where: { id: req.params.id } });
        res.json({ success: true, message: "Foydalanuvchi tizimdan o'chirib yuborildi" });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   GET /api/admin/analytics/weekly — Weekly Analytics Data
   ============================================================ */
router.get('/analytics/weekly', async (_req: Request, res: Response) => {
    try {
        const days = Array.from({ length: 7 }, (_, i) => {
            const d = new Date();
            d.setDate(d.getDate() - (6 - i));
            d.setHours(0,0,0,0);
            return d;
        });

        const counts = await Promise.all(
            days.map(day => {
                const next = new Date(day); next.setDate(next.getDate() + 1);
                return prisma.order.count({ where: { createdAt: { gte: day, lt: next } } });
            })
        );

        const labels = ['Du','Se','Ch','Pa','Ju','Sha','Ya'];
        res.json({ success: true, labels, data: counts });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   GET /api/admin/settings — Get ecosystem settings
   ============================================================ */
router.get('/settings', async (_req: Request, res: Response) => {
    try {
        const filePath = path.join(__dirname, '../settings.json');
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

/* ============================================================
   POST /api/admin/settings — Update ecosystem settings
   ============================================================ */
router.post('/settings', async (req: Request, res: Response) => {
    try {
        const filePath = path.join(__dirname, '../settings.json');
        fs.writeFileSync(filePath, JSON.stringify(req.body, null, 2), 'utf8');
        // Copy to public settings.json in backend/src as well for the public endpoint
        const publicFilePath = path.join(__dirname, '../settings.json');
        fs.writeFileSync(publicFilePath, JSON.stringify(req.body, null, 2), 'utf8');
        
        res.json({ success: true, message: "Settings updated successfully" });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   GET /api/admin/emails — Retrieve all email messages
   ============================================================ */
router.get('/emails', async (req: Request, res: Response) => {
    try {
        const account = req.query.account as string | undefined; // Optional filter by "info@orbitago.uz" or "support@orbitago.uz"
        
        const where: any = {};
        if (account) where.account = account;

        const emails = await prisma.emailMessage.findMany({
            where,
            orderBy: { createdAt: 'desc' }
        });

        res.json({ success: true, emails });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   PATCH /api/admin/emails/:id/read — Toggle email read status
   ============================================================ */
router.patch('/emails/:id/read', async (req: Request, res: Response) => {
    try {
        const email = await prisma.emailMessage.findUnique({ where: { id: req.params.id } });
        if (!email) {
            res.status(404).json({ success: false, message: "Email topilmadi" });
            return;
        }

        const updated = await prisma.emailMessage.update({
            where: { id: req.params.id },
            data: { isRead: !email.isRead }
        });

        res.json({ success: true, isRead: updated.isRead });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   DELETE /api/admin/emails/:id — Delete an email message
   ============================================================ */
router.delete('/emails/:id', async (req: Request, res: Response) => {
    try {
        await prisma.emailMessage.delete({ where: { id: req.params.id } });
        res.json({ success: true, message: "Xabar o'chirildi" });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   POST /api/admin/broadcast — Send real-time notification to apps
   ============================================================ */
router.post('/broadcast', async (req: Request, res: Response) => {
    try {
        const { title, message, target, type } = req.body;
        if (!title || !message) {
            res.status(400).json({ success: false, message: "Sarlavha va xabar matnini kiriting" });
            return;
        }

        const io = (global as any).io;
        if (io) {
            io.emit('broadcast_notification', {
                title,
                message,
                target: target || 'ALL',
                type: type || 'info',
                createdAt: new Date()
            });
        }

        res.json({ success: true, message: "Xabarnoma muvaffaqiyatli yuborildi" });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   GET /api/admin/transactions — Retrieve all wallet transactions
   ============================================================ */
router.get('/transactions', async (req: Request, res: Response) => {
    try {
        const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
        const skip  = parseInt(req.query.skip as string) || 0;

        const transactions = await prisma.transaction.findMany({
            orderBy: { createdAt: 'desc' },
            take: limit,
            skip,
            include: {
                user: { select: { fullName: true, phoneNumber: true } }
            }
        });
        const total = await prisma.transaction.count();

        res.json({ success: true, transactions, total, limit, skip });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   POST /api/admin/driver — Manual Driver Registration
   ============================================================ */
router.post('/driver', async (req: Request, res: Response) => {
    try {
        const { fullName, phoneNumber, password, carModel, carColor, carNumber } = req.body;
        if (!fullName || !phoneNumber || !password || !carModel || !carColor || !carNumber) {
            res.status(400).json({ success: false, message: "Barcha ma'lumotlarni kiriting" });
            return;
        }

        const cleanPhone = '+' + phoneNumber.replace(/\D/g, '');

        const userExists = await prisma.user.findFirst({
            where: {
                OR: [
                    { phoneNumber: cleanPhone }
                ]
            }
        });
        if (userExists) {
            res.status(400).json({ success: false, message: "Ushbu telefon raqamli foydalanuvchi allaqachon mavjud" });
            return;
        }

        const carExists = await prisma.driverProfile.findUnique({
            where: { carNumber }
        });
        if (carExists) {
            res.status(400).json({ success: false, message: "Ushbu davlat raqamli mashina allaqachon ro'yxatdan o'tgan" });
            return;
        }

        const hashedPw = await bcrypt.hash(password, 10);
        const orbitaId = `ORB-${Math.floor(100000 + Math.random() * 900000)}`;

        const result = await prisma.$transaction(async (tx) => {
            const user = await tx.user.create({
                data: {
                    orbitaId,
                    password: hashedPw,
                    phoneNumber: cleanPhone,
                    fullName,
                    role: 'DRIVER',
                    isVerified: false,
                    walletBalance: 0.0
                }
            });

            const profile = await tx.driverProfile.create({
                data: {
                    userId: user.id,
                    carModel,
                    carColor,
                    carNumber,
                    rating: 5.0,
                    totalTrips: 0,
                    isOnline: false,
                    isVerified: false
                }
            });

            return { user, profile };
        });

        // Notify via Telegram Bot with verify/reject buttons if configured
        const tgToken = process.env.TELEGRAM_BOT_TOKEN;
        const tgChatId = process.env.TELEGRAM_CHAT_ID;

        if (tgToken && tgChatId) {
            const tgText = `🚖 <b>── YANGI HAYDOVCHI RO'YXATDAN O'TDI ──</b>\n\n` +
                           `👤 <b>Ismi:</b> <code>${fullName}</code>\n` +
                           `📞 <b>Telefon:</b> <code>${cleanPhone}</code>\n` +
                           `🚗 <b>Mashina:</b> <code>${carModel} (${carColor})</code>\n` +
                           `🔢 <b>Raqami:</b> <code>${carNumber}</code>\n\n` +
                           `Siz ushbu haydovchini tasdiqlashingiz yoki rad etishingiz mumkin.`;

            const replyMarkup = {
                inline_keyboard: [
                    [
                        { text: '✅ Tasdiqlash', callback_data: `verify_drv:${result.user.id}` },
                        { text: '❌ Rad etish', callback_data: `reject_drv:${result.user.id}` }
                    ]
                ]
            };

            const postData = JSON.stringify({
                chat_id: tgChatId,
                text: tgText,
                parse_mode: 'HTML',
                reply_markup: replyMarkup
            });

            const options = {
                hostname: 'api.telegram.org',
                port: 443,
                path: `/bot${tgToken}/sendMessage`,
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(postData, 'utf8')
                }
            };

            const reqTelegram = https.request(options, (resTg) => {
                resTg.resume();
            });
            reqTelegram.on('error', (err) => {
                console.error('⚠️ Telegram notification error for new driver:', err.message);
            });
            reqTelegram.write(postData);
            reqTelegram.end();
        }

        res.json({ success: true, message: "Haydovchi muvaffaqiyatli ro'yxatga olindi. Tasdiqlash uchun operatorga so'rov yuborildi.", driver: { id: result.profile.id, fullName, phone: cleanPhone } });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   POST /api/admin/emails/:id/reply — Send Mock Helpdesk Email Reply
   ============================================================ */
router.post('/emails/:id/reply', async (req: Request, res: Response) => {
    try {
        const { message } = req.body;
        if (!message) {
            res.status(400).json({ success: false, message: "Javob xabari bo'sh bo'lishi mumkin emas" });
            return;
        }

        const email = await prisma.emailMessage.findUnique({ where: { id: req.params.id } });
        if (!email) {
            res.status(404).json({ success: false, message: "Email topilmadi" });
            return;
        }

        await prisma.emailMessage.update({
            where: { id: req.params.id },
            data: { isRead: true }
        });

        console.log(`✉️ Mock email replied to: ${email.from} (Subject: RE: ${email.subject}) -> Body: ${message}`);

        res.json({ success: true, message: "Javob muvaffaqiyatli yuborildi (Mock)" });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   POST /api/admin/leaderboard/reset — Reset Tournament & Award Prizes
   ============================================================ */
router.post('/leaderboard/reset', async (req: Request, res: Response) => {
    try {
        const gameStats = await prisma.gameStat.findMany({
            orderBy: { highScore: 'desc' },
            take: 3,
            include: { user: true }
        });

        if (gameStats.length === 0) {
            res.json({ success: true, message: "Turnir ishtirokchilari yo'q, mukofot tarqatilmadi" });
            return;
        }

        const prizePool = [150000, 80000, 40000];

        const results = await prisma.$transaction(async (tx) => {
            const payed = [];
            for (let i = 0; i < gameStats.length; i++) {
                const stat = gameStats[i];
                const prize = prizePool[i] || 10000;

                const updatedUser = await tx.user.update({
                    where: { id: stat.userId },
                    data: { walletBalance: { increment: prize } }
                });

                await tx.transaction.create({
                    data: {
                        userId: stat.userId,
                        title: `Turnir G'olibi (${i+1}-o'rin)`,
                        subtitle: `Haftalik o'yin turniri mukofoti`,
                        amount: prize,
                        isCredit: true,
                        type: "TOURNAMENT"
                    }
                });

                payed.push({
                    name: updatedUser.fullName || stat.userId,
                    rank: i + 1,
                    prize
                });
            }

            await tx.gameStat.updateMany({
                data: { highScore: 0 }
            });

            return payed;
        });

        const io = (global as any).io;
        if (io) {
            io.emit('tournament_reset', { winners: results });
        }

        res.json({ success: true, message: "Haftalik turnir yakunlandi, sovrinlar tarqatildi!", winners: results });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   GET /api/admin/news — Barcha yangiliklar (chop etilmagan ham)
   ============================================================ */
router.get('/news', async (_req: Request, res: Response) => {
    try {
        const news = await prisma.newsPost.findMany({ orderBy: { publishedAt: 'desc' } });
        res.json({ success: true, news });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   POST /api/admin/news — Yangilik yaratish
   ============================================================ */
router.post('/news', async (req: Request, res: Response) => {
    try {
        const { tag, tagLabel, icon, iconColor, title, description, ctaLink, isFeatured, isPublished, publishedAt } = req.body;
        if (!tagLabel || !title || !description) {
            res.status(400).json({ success: false, message: "tagLabel, title va description shart" });
            return;
        }
        const post = await prisma.newsPost.create({
            data: {
                tag: tag || 'update',
                tagLabel,
                icon: icon || 'megaphone-outline',
                iconColor: iconColor || 'default',
                title,
                description,
                ctaLink: ctaLink || '#download',
                isFeatured: !!isFeatured,
                isPublished: isPublished !== false,
                publishedAt: publishedAt ? new Date(publishedAt) : new Date(),
            }
        });
        res.json({ success: true, news: post });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   PATCH /api/admin/news/:id — Yangilikni tahrirlash
   ============================================================ */
router.patch('/news/:id', async (req: Request, res: Response) => {
    try {
        const { tag, tagLabel, icon, iconColor, title, description, ctaLink, isFeatured, isPublished, publishedAt } = req.body;
        const data: any = {};
        if (tag !== undefined) data.tag = tag;
        if (tagLabel !== undefined) data.tagLabel = tagLabel;
        if (icon !== undefined) data.icon = icon;
        if (iconColor !== undefined) data.iconColor = iconColor;
        if (title !== undefined) data.title = title;
        if (description !== undefined) data.description = description;
        if (ctaLink !== undefined) data.ctaLink = ctaLink;
        if (isFeatured !== undefined) data.isFeatured = !!isFeatured;
        if (isPublished !== undefined) data.isPublished = !!isPublished;
        if (publishedAt !== undefined) data.publishedAt = new Date(publishedAt);

        const post = await prisma.newsPost.update({ where: { id: req.params.id }, data });
        res.json({ success: true, news: post });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   DELETE /api/admin/news/:id — Yangilikni o'chirish
   ============================================================ */
router.delete('/news/:id', async (req: Request, res: Response) => {
    try {
        await prisma.newsPost.delete({ where: { id: req.params.id } });
        res.json({ success: true, message: "Yangilik o'chirildi" });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

export default router;


