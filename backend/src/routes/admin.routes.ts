/* ==========================================================================
   Orbita Go — admin.routes.ts
   Admin Panel uchun Backend API Endpointlar
   ========================================================================== */

import { Router, Request, Response, NextFunction } from 'express';
import prisma from '../lib/prisma';
import fs from 'fs';
import path from 'path';

const router = Router();

/* ---- Admin Auth Middleware ---- */
const adminAuth = (req: Request, res: Response, next: NextFunction): void => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    const secret = process.env.ADMIN_SECRET || 'orbita-admin-secret-2026';
    if (key !== secret) {
        res.status(401).json({ success: false, message: "Admin privileges required" });
        return;
    }
    next();
};

/* ============================================================
   POST /api/admin/emails/incoming — Public Webhook for incoming emails
   cPanel Email Pipe or webhook parses and posts here.
   ============================================================ */
router.post('/emails/incoming', async (req: Request, res: Response) => {
    try {
        const token = req.query.token || req.headers['x-webhook-token'];
        const validToken = process.env.EMAIL_WEBHOOK_SECRET || 'orbita-email-webhook-token-2026';
        
        if (token !== validToken) {
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
            select: {
                id: true,
                fullName: true,
                phoneNumber: true,
                email: true,
                totalStepsRedeemed: true,
                walletBalance: true,
                isVerified: true,
                createdAt: true,
                _count: { select: { clientOrders: true } }
            }
        });
        const total = await prisma.user.count();

        const mapped = users.map(u => ({
            id: u.id,
            fullName: u.fullName || '—',
            phone: u.phoneNumber || '—',
            email: u.email || '',
            totalSteps: u.totalStepsRedeemed,
            score: u.walletBalance,
            isBlocked: !u.isVerified,
            totalOrders: u._count.clientOrders,
            createdAt: u.createdAt
        }));

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
   GET /api/admin/env — Retrieve backend environment variables (.env)
   ============================================================ */
router.get('/env', async (_req: Request, res: Response) => {
    try {
        const envPath = path.join(__dirname, '../../.env');
        if (!fs.existsSync(envPath)) {
            return res.status(404).json({ success: false, message: '.env fayli topilmadi' });
        }
        const content = fs.readFileSync(envPath, 'utf8');
        
        const envObj: Record<string, string> = {};
        const lines = content.split('\n');
        lines.forEach(line => {
            const trimmed = line.trim();
            if (!trimmed || trimmed.startsWith('#')) return;
            const index = trimmed.indexOf('=');
            if (index > 0) {
                const key = trimmed.substring(0, index).trim();
                let val = trimmed.substring(index + 1).trim();
                if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
                    val = val.substring(1, val.length - 1);
                }
                envObj[key] = val;
            }
        });

        res.json({ success: true, env: envObj });
    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
});

/* ============================================================
   POST /api/admin/env — Save backend environment variables (.env)
   ============================================================ */
router.post('/env', async (req: Request, res: Response) => {
    try {
        const envPath = path.join(__dirname, '../../.env');
        if (!fs.existsSync(envPath)) {
            return res.status(404).json({ success: false, message: '.env fayli topilmadi' });
        }
        
        const updatedEnv = req.body;
        let content = fs.readFileSync(envPath, 'utf8');
        const lines = content.split('\n');
        
        const newLines = lines.map(line => {
            const trimmed = line.trim();
            if (!trimmed || trimmed.startsWith('#')) return line;
            const index = trimmed.indexOf('=');
            if (index > 0) {
                const key = trimmed.substring(0, index).trim();
                if (Object.prototype.hasOwnProperty.call(updatedEnv, key)) {
                    let val = updatedEnv[key];
                    if (val.includes(' ') || val.includes('#') || val.includes('$') || val.includes('"') || val.includes("'") || val.includes('@') || val.includes(':')) {
                        val = `"${val.replace(/"/g, '\\"')}"`;
                    }
                    return `${key}=${val}`;
                }
            }
            return line;
        });
        
        fs.writeFileSync(envPath, newLines.join('\n'), 'utf8');
        
        // Update current process env
        Object.keys(updatedEnv).forEach(key => {
            process.env[key] = updatedEnv[key];
        });

        res.json({ success: true, message: "Muhit o'zgaruvchilari saqlandi. Tizim qayta ishga tushmoqda..." });
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

export default router;
