import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import axios from 'axios';
import prisma from '../lib/prisma';
import { generateToken, authenticateToken, AuthRequest } from '../middleware/auth.middleware';

const router = Router();

// Seed default users if they don't exist
async function seedDefaultUsers() {
  try {
    const user1 = await prisma.user.findUnique({ where: { orbitaId: 'ORB-100200' } });
    if (!user1) {
      const hashedPw = await bcrypt.hash('123456', 10);
      await prisma.user.create({
        data: {
          orbitaId: 'ORB-100200',
          password: hashedPw,
          fullName: 'Toshmatov Ali',
          username: 'ali',
          phoneNumber: '+998991112233',
          role: 'CLIENT',
          isVerified: true,
          walletBalance: 150000.0,
        }
      });
      console.log('✅ Default User 1 seeded (ORB-100200)');
    }

    const user2 = await prisma.user.findUnique({ where: { orbitaId: 'ORB-777777' } });
    if (!user2) {
      const hashedPw = await bcrypt.hash('123456', 10);
      await prisma.user.create({
        data: {
          orbitaId: 'ORB-777777',
          password: hashedPw,
          fullName: 'Valiyev Vali',
          username: 'vali',
          role: 'CLIENT',
          isVerified: true,
          walletBalance: 150000.0,
        }
      });
      console.log('✅ Default User 2 seeded (ORB-777777)');
    }

    const driver = await prisma.user.findUnique({ where: { orbitaId: 'ORB-888888' } });
    if (!driver) {
      const hashedPw = await bcrypt.hash('123456', 10);
      const driverUser = await prisma.user.create({
        data: {
          orbitaId: 'ORB-888888',
          password: hashedPw,
          fullName: 'Aliyev Davron',
          username: 'davron',
          phoneNumber: '+998901234567',
          role: 'DRIVER',
          isVerified: true,
          walletBalance: 0.0,
        }
      });
      await prisma.driverProfile.create({
        data: {
          userId: driverUser.id,
          carModel: 'Chevrolet Nexia 3',
          carColor: 'Oq',
          carNumber: '01 A 777 AA',
          rating: 4.9,
          totalTrips: 42,
          isOnline: true,
          currentLat: 41.3111,
          currentLng: 69.2797,
        }
      });
      console.log('✅ Default Driver seeded (ORB-888888)');
    }

    // Seed default RideQuests templates if they don't exist
    const questsCount = await prisma.rideQuest.count();
    if (questsCount === 0) {
      await prisma.rideQuest.createMany({
        data: [
          { title: 'Birinchi qadam', description: 'Tizimda ilk bor 1 ta taksi safarini yakunlang', targetCount: 1, rewardPrice: 3000.0 },
          { title: 'Faol yo\'lovchi', description: 'Hafta davomida 3 ta taksi safarini yakunlang', targetCount: 3, rewardPrice: 10000.0 },
          { title: 'Sayohatchi', description: '5 ta taksi safarini yakunlang', targetCount: 5, rewardPrice: 20000.0 },
        ]
      });
      console.log('✅ Default RideQuests templates seeded');
    }
  } catch (err) {
    console.error('Error seeding default users:', err);
  }
}
if (process.env.NODE_ENV === 'development') {
  seedDefaultUsers();
}

// Telefon validatsiya
function isValidPhone(phone: string): boolean {
  return /^(\+998|998)[0-9]{9}$/.test(phone.replace(/\s/g, ''));
}

// Normalizatsiya
function normalizePhone(phone: string): string {
  const digits = phone.replace(/\D/g, '');
  if (digits.startsWith('998') && digits.length === 12) return `+${digits}`;
  if (digits.length === 9) return `+998${digits}`;
  return phone;
}

// POST /api/auth/check-identifier
router.post('/check-identifier', async (req: Request, res: Response) => {
  const { identifier } = req.body;
  if (!identifier) {
    return res.status(400).json({ success: false, message: 'Identifikator kiritish lozim' });
  }

  const phone = normalizePhone(identifier);
  try {
    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { orbitaId: identifier },
          { username: identifier },
          { email: identifier },
          ...(isValidPhone(phone) ? [{ phoneNumber: phone }] : []),
        ],
      },
    });

    return res.json({
      success: true,
      exists: user !== null,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Xatolik yuz berdi' });
  }
});

// POST /api/auth/login
router.post('/login', async (req: Request, res: Response) => {
  const { identifier, password } = req.body;
  if (!identifier || !password) {
    return res.status(400).json({ success: false, message: 'Identifikator va parol kiritish lozim' });
  }

  const phone = normalizePhone(identifier);
  try {
    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { orbitaId: identifier },
          { username: identifier },
          { email: identifier },
          ...(isValidPhone(phone) ? [{ phoneNumber: phone }] : []),
        ],
      },
    });

    if (!user) {
      return res.status(400).json({ success: false, message: 'Foydalanuvchi topilmadi' });
    }

    // Bcrypt bilan parolni tekshirish (legacy plain-text fallback ham qo'llab-quvvatlash)
    let passwordMatch = false;
    if (user.password.startsWith('$2')) {
      // Hashed parol
      passwordMatch = await bcrypt.compare(password, user.password);
    } else {
      // Legacy plain-text (migration uchun) — to'g'ri bo'lsa hash qilib saqlaymiz
      if (user.password === password) {
        passwordMatch = true;
        // Avtomatik migrate qilamiz
        const hashedPw = await bcrypt.hash(password, 10);
        await prisma.user.update({ where: { id: user.id }, data: { password: hashedPw } });
        console.log(`🔐 Parol migrate qilindi: ${user.orbitaId}`);
      }
    }

    if (!passwordMatch) {
      return res.status(400).json({ success: false, message: 'Noto\'g\'ri parol' });
    }

    const token = generateToken({ id: user.id, phoneNumber: user.phoneNumber || '', role: user.role });

    return res.json({
      success: true,
      token,
      user: {
        id: user.id,
        orbitaId: user.orbitaId,
        phoneNumber: user.phoneNumber,
        email: user.email,
        fullName: user.fullName,
        username: user.username,
        role: user.role,
        avatarUrl: user.avatarUrl,
        walletBalance: user.walletBalance,
        isVerified: user.isVerified,
      },
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Xatolik yuz berdi' });
  }
});

// POST /api/auth/register
router.post('/register', async (req: Request, res: Response) => {
  const { identifier, password, fullName, referredByCode } = req.body;
  if (!identifier || !password || !fullName) {
    return res.status(400).json({ success: false, message: 'Barcha maydonlarni to\'ldirish shart' });
  }

  if (password.length < 6) {
    return res.status(400).json({ success: false, message: 'Parol kamida 6 ta belgidan iborat bo\'lishi kerak' });
  }

  const phone = normalizePhone(identifier);
  let phoneNumber: string | null = null;
  let email: string | null = null;
  let username: string | null = null;

  if (isValidPhone(phone)) {
    phoneNumber = phone;
  } else if (identifier.includes('@')) {
    email = identifier;
  } else {
    username = identifier;
  }

  const orbitaId = `ORB-${Math.floor(100000 + Math.random() * 900000)}`;

  try {
    // Check conflicts
    const conflict = await prisma.user.findFirst({
      where: {
        OR: [
          ...(phoneNumber ? [{ phoneNumber }] : []),
          ...(email ? [{ email }] : []),
          ...(username ? [{ username }] : []),
        ],
      },
    });

    if (conflict) {
      return res.status(400).json({ success: false, message: 'Ushbu foydalanuvchi ma\'lumoti band' });
    }

    // Referral code tekshirish
    let referredById: string | null = null;
    if (referredByCode && typeof referredByCode === 'string') {
      const refCode = referredByCode.trim().toUpperCase();
      const referrer = await prisma.user.findUnique({ where: { orbitaId: refCode } });
      if (referrer) {
        referredById = referrer.id;
      }
    }

    // Parolni hash qilamiz
    const hashedPw = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
      data: {
        orbitaId,
        password: hashedPw,
        fullName,
        phoneNumber,
        email,
        username,
        role: 'CLIENT',
        isVerified: true,
        walletBalance: 5000.0,
        ...(referredById && { referredById }),
        transactions: {
          create: {
            title: "Orbita Go'dan sovg'a",
            subtitle: "Ro'yxatdan o'tganingiz uchun",
            amount: 5000.0,
            isCredit: true,
            type: "REGISTRATION_BONUS"
          }
        }
      },
    });

    const token = generateToken({ id: user.id, phoneNumber: user.phoneNumber || '', role: user.role });

    return res.json({
      success: true,
      token,
      user: {
        id: user.id,
        orbitaId: user.orbitaId,
        phoneNumber: user.phoneNumber,
        email: user.email,
        fullName: user.fullName,
        username: user.username,
        role: user.role,
        avatarUrl: user.avatarUrl,
        walletBalance: user.walletBalance,
        isVerified: user.isVerified,
      },
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Ro\'yxatdan o\'tishda xatolik yuz berdi' });
  }
});

// GET /api/auth/me
router.get('/me', authenticateToken, async (req: AuthRequest, res: Response) => {
  const user = await prisma.user.findUnique({
    where: { id: req.user!.id },
    select: {
      id: true,
      orbitaId: true,
      phoneNumber: true,
      email: true,
      fullName: true,
      username: true,
      role: true,
      avatarUrl: true,
      walletBalance: true,
      isVerified: true,
      createdAt: true,
    },
  });

  if (!user) {
    return res.status(404).json({ success: false, message: 'Foydalanuvchi topilmadi' });
  }

  return res.json({ success: true, user });
});

// PATCH /api/auth/profile
router.patch('/profile', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { fullName, username } = req.body;

  try {
    const user = await prisma.user.update({
      where: { id: req.user!.id },
      data: {
        ...(fullName && { fullName }),
        ...(username && { username }),
      },
      select: {
        id: true,
        orbitaId: true,
        phoneNumber: true,
        email: true,
        fullName: true,
        username: true,
        role: true,
        avatarUrl: true,
        walletBalance: true,
      },
    });
    return res.json({ success: true, user });
  } catch (err: any) {
    if (err.code === 'P2002') {
      return res.status(400).json({ success: false, message: 'Bu username band' });
    }
    return res.status(500).json({ success: false, message: 'Xatolik yuz berdi' });
  }
});

// PATCH /api/auth/change-password
router.patch('/change-password', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { oldPassword, newPassword } = req.body;
  if (!oldPassword || !newPassword) {
    return res.status(400).json({ success: false, message: 'Eski va yangi parol kiritilishi shart' });
  }
  if (newPassword.length < 6) {
    return res.status(400).json({ success: false, message: 'Yangi parol kamida 6 ta belgidan iborat bo\'lishi kerak' });
  }

  try {
    const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
    if (!user) return res.status(404).json({ success: false, message: 'Foydalanuvchi topilmadi' });

    let passwordMatch = false;
    if (user.password.startsWith('$2')) {
      passwordMatch = await bcrypt.compare(oldPassword, user.password);
    } else {
      passwordMatch = user.password === oldPassword;
    }
    if (!passwordMatch) {
      return res.status(400).json({ success: false, message: 'Eski parol noto\'g\'ri' });
    }

    const hashedPw = await bcrypt.hash(newPassword, 10);
    await prisma.user.update({ where: { id: req.user!.id }, data: { password: hashedPw } });

    return res.json({ success: true, message: 'Parol muvaffaqiyatli yangilandi' });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/auth/driver/verify — Request & Auto-verify driver for testing/demo
router.post('/driver/verify', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const profile = await prisma.driverProfile.upsert({
      where: { userId: req.user!.id },
      update: { isVerified: true },
      create: {
        userId: req.user!.id,
        carModel: req.body.carModel || 'Chevrolet Nexia 3',
        carColor: req.body.carColor || 'Oq',
        carNumber: req.body.carNumber || `01 A ${Math.floor(100 + Math.random() * 900)} AA`,
        isVerified: true
      }
    });
    // Also update parent User model
    await prisma.user.update({
      where: { id: req.user!.id },
      data: { isVerified: true }
    });
    return res.json({ success: true, profile });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PATCH /api/auth/driver/profile — Haydovchi mashina ma'lumotlarini yangilash
router.patch('/driver/profile', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { carModel, carColor, carNumber } = req.body;
  try {
    const profile = await prisma.driverProfile.update({
      where: { userId: req.user!.id },
      data: {
        ...(carModel && { carModel }),
        ...(carColor && { carColor }),
        ...(carNumber && { carNumber }),
      }
    });
    return res.json({ success: true, profile });
  } catch (err: any) {
    if (err.code === 'P2002') {
      return res.status(400).json({ success: false, message: 'Bu mashina raqami allaqachon ro\'yxatda bor' });
    }
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/auth/driver/topup — Top up driver wallet
router.post('/driver/topup', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { amount = 50000 } = req.body;
  try {
    const amountVal = Number(amount);
    const updatedUser = await prisma.user.update({
      where: { id: req.user!.id },
      data: { 
        walletBalance: { increment: amountVal },
        transactions: {
          create: {
            title: "Hamyon to'ldirish",
            subtitle: "Tizim orqali",
            amount: amountVal,
            isCredit: true,
            type: "TOPUP"
          }
        }
      },
      select: {
        id: true,
        orbitaId: true,
        phoneNumber: true,
        email: true,
        fullName: true,
        username: true,
        role: true,
        avatarUrl: true,
        walletBalance: true,
      }
    });
    return res.json({ success: true, user: updatedUser });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// Helper: Check and grant referral bonus when milestone is reached
async function checkAndGrantReferralBonus(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, referredById: true, isReferralRewardClaimed: true, totalStepsRedeemed: true },
  });
  if (!user || !user.referredById || user.isReferralRewardClaimed) return;

  const STEPS_MILESTONE = 50000;
  if (user.totalStepsRedeemed < STEPS_MILESTONE) return;

  // Milestone qo'lga kiritildi — ikkalasiga 5,000 UZS beramiz
  const BONUS = 5000.0;
  await prisma.$transaction([
    // Do'sti (yangi foydalanuvchi)ga bonus
    prisma.user.update({
      where: { id: user.id },
      data: {
        walletBalance: { increment: BONUS },
        isReferralRewardClaimed: true,
        transactions: {
          create: {
            title: 'Taklif bonusi',
            subtitle: 'Do\'stingizni taklif qilganingiz uchun sovg\'a',
            amount: BONUS,
            isCredit: true,
            type: 'REFERRAL_BONUS',
          },
        },
      },
    }),
    // Taklif qiluvchi (referrer)ga bonus
    prisma.user.update({
      where: { id: user.referredById },
      data: {
        walletBalance: { increment: BONUS },
        transactions: {
          create: {
            title: 'Taklif bonusi',
            subtitle: 'Taklif qilgan do\'stingiz 50,000 qadam bosdi',
            amount: BONUS,
            isCredit: true,
            type: 'REFERRAL_BONUS',
          },
        },
      },
    }),
  ]);
  console.log(`🎁 Referral bonus berildi: userId=${user.id}, referrerId=${user.referredById}`);
}

// POST /api/auth/walk/redeem — Convert walk rewards (steps) to wallet balance
router.post('/walk/redeem', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { steps = 0, amount = 0 } = req.body;
  if (amount <= 0) {
    return res.status(400).json({ success: false, message: 'Nolga teng yoki kichik miqdorni o\'tkazib bo\'lmaydi' });
  }
  try {
    const stepsVal = Number(steps);
    const amountVal = Number(amount);
    const updatedUser = await prisma.user.update({
      where: { id: req.user!.id },
      data: {
        walletBalance: { increment: amountVal },
        totalStepsRedeemed: { increment: stepsVal },
        transactions: {
          create: {
            title: "Orbita Walk mukofoti",
            subtitle: `${stepsVal.toLocaleString()} ta qadam uchun`,
            amount: amountVal,
            isCredit: true,
            type: "WALK_REWARD"
          }
        }
      },
      select: {
        id: true,
        orbitaId: true,
        phoneNumber: true,
        email: true,
        fullName: true,
        username: true,
        role: true,
        avatarUrl: true,
        walletBalance: true,
        totalStepsRedeemed: true,
        isReferralRewardClaimed: true,
        referredById: true,
      }
    });
    // Referral milestone tekshiramiz (await qilmaymiz — background)
    checkAndGrantReferralBonus(req.user!.id).catch(console.error);
    return res.json({ success: true, user: updatedUser });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/auth/walk/geo-quests — Landmark geo-kvestlar ro'yxati
router.get('/walk/geo-quests', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const count = await prisma.geoQuest.count();
    if (count === 0) {
      await prisma.geoQuest.createMany({
        data: [
          { title: 'Amir Temur Xiyoboni', lat: 41.3111, lng: 69.2797, radius: 500, goalSteps: 2000, rewardCoins: 200, rewardCouponCode: 'TEMUR-2000' },
          { title: 'Tashkent City Park', lat: 41.3031, lng: 69.2523, radius: 400, goalSteps: 3000, rewardCoins: 300, rewardCouponCode: 'CITY-3000' },
          { title: 'Magic City', lat: 41.2982, lng: 69.2435, radius: 300, goalSteps: 1500, rewardCoins: 150, rewardCouponCode: 'MAGIC-1500' },
          { title: 'Chorsu Bozori', lat: 41.3272, lng: 69.2427, radius: 600, goalSteps: 2500, rewardCoins: 250, rewardCouponCode: 'CHORSU-2500' }
        ]
      });
    }

    const quests = await prisma.geoQuest.findMany();
    return res.json({ success: true, quests });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/auth/walk/geo-quests/claim — Geo-kvest mukofotini olish
router.post('/walk/geo-quests/claim', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { questId } = req.body;
  if (!questId) {
    return res.status(400).json({ success: false, message: 'Kvest ID ko\'rsatilishi shart' });
  }

  try {
    const quest = await prisma.geoQuest.findUnique({ where: { id: questId } });
    if (!quest) {
      return res.status(404).json({ success: false, message: 'Kvest topilmadi' });
    }

    const rewardPrice = quest.rewardCoins * 10.0;

    await prisma.user.update({
      where: { id: req.user!.id },
      data: {
        walletBalance: { increment: rewardPrice },
        transactions: {
          create: {
            title: `Landmark Kvest Mukofoti: ${quest.title}`,
            subtitle: `${quest.goalSteps.toLocaleString()} ta qadam uchun`,
            amount: rewardPrice,
            isCredit: true,
            type: "QUEST_REWARD"
          }
        }
      }
    });

    return res.json({
      success: true,
      message: `Tabriklaymiz! Kvest muvaffaqiyatli topshirildi va hamyoningizga ${rewardPrice} UZS o'tkazildi.`,
      couponCode: quest.rewardCouponCode
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/auth/walk/leaderboard — Fetch top 10 walking leaderboard users
router.get('/walk/leaderboard', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    // 1. Group WALK_REWARD transactions to sum redeemed steps per user
    const groupedRewards = await prisma.transaction.groupBy({
      by: ['userId'],
      where: {
        type: 'WALK_REWARD',
      },
      _sum: {
        amount: true,
      },
      orderBy: {
        _sum: {
          amount: 'desc',
        },
      },
      take: 10,
    });

    const rankedUserIds = groupedRewards.map(r => r.userId);

    // 2. Fetch details for these ranked users
    const rankedUsers = await prisma.user.findMany({
      where: {
        id: { in: rankedUserIds },
      },
      select: {
        id: true,
        fullName: true,
        orbitaId: true,
        avatarUrl: true,
      },
    });

    // Map to result format
    let leaderboard = groupedRewards.map(reward => {
      const user = rankedUsers.find(u => u.id === reward.userId);
      return {
        id: reward.userId,
        fullName: user?.fullName || 'Foydalanuvchi',
        orbitaId: user?.orbitaId || 'ORB-000000',
        avatarUrl: user?.avatarUrl || null,
        steps: reward._sum.amount ? Math.round(reward._sum.amount) : 0,
      };
    });

    // 3. Fallback: If we have fewer than 10 users, pad with other users to show a full podium list
    if (leaderboard.length < 10) {
      const extraUsers = await prisma.user.findMany({
        where: {
          id: { notIn: rankedUserIds },
        },
        take: 10 - leaderboard.length,
        select: {
          id: true,
          fullName: true,
          orbitaId: true,
          avatarUrl: true,
        },
      });

      const padded = extraUsers.map(u => ({
        id: u.id,
        fullName: u.fullName || 'Foydalanuvchi',
        orbitaId: u.orbitaId || 'ORB-000000',
        avatarUrl: u.avatarUrl || null,
        steps: 0,
      }));

      leaderboard = [...leaderboard, ...padded];
    }

    // Sort final list by steps descending just in case
    leaderboard.sort((a, b) => b.steps - a.steps);

    return res.json({ success: true, leaderboard });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/auth/referrals — Mening taklif qilgan do'stlarimni ko'rish
router.get('/referrals', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: {
        orbitaId: true,
        isReferralRewardClaimed: true,
        referrals: {
          select: {
            id: true,
            fullName: true,
            orbitaId: true,
            avatarUrl: true,
            totalStepsRedeemed: true,
            isReferralRewardClaimed: true,
            createdAt: true,
            clientOrders: {
              where: { status: 'COMPLETED' },
              select: { id: true },
            },
          },
        },
      },
    });
    if (!user) return res.status(404).json({ success: false, message: 'Foydalanuvchi topilmadi' });

    const referrals = user.referrals.map(r => ({
      id: r.id,
      fullName: r.fullName || 'Foydalanuvchi',
      orbitaId: r.orbitaId,
      avatarUrl: r.avatarUrl,
      totalStepsRedeemed: r.totalStepsRedeemed,
      completedTrips: r.clientOrders.length,
      isReferralRewardClaimed: r.isReferralRewardClaimed,
      joinedAt: r.createdAt,
      milestoneProgress: Math.min(r.totalStepsRedeemed, 50000),
      milestoneTarget: 50000,
    }));

    return res.json({
      success: true,
      myReferralCode: user.orbitaId,
      totalReferrals: referrals.length,
      claimedCount: referrals.filter(r => r.isReferralRewardClaimed).length,
      referrals,
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/auth/otp/send — Generate and send OTP code
router.post('/otp/send', async (req: Request, res: Response) => {
  const { phoneNumber } = req.body;
  if (!phoneNumber) {
    return res.status(400).json({ success: false, message: 'Telefon raqam kiritilishi shart' });
  }

  const phone = normalizePhone(phoneNumber);
  if (!isValidPhone(phone)) {
    return res.status(400).json({ success: false, message: 'Noto\'g\'ri telefon raqami shakli' });
  }

  // Generate 6-digit code
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 3 * 60 * 1000); // 3 minutes expiry

  try {
    // Delete any old OTPs for this phone number to avoid database clutter
    await prisma.otp.deleteMany({ where: { phoneNumber: phone } });

    // Save to database
    await prisma.otp.create({
      data: {
        phoneNumber: phone,
        code,
        expiresAt,
      }
    });

    // Check for Eskiz credentials in .env
    const smsEmail = process.env.SMS_EMAIL;
    const smsPassword = process.env.SMS_PASSWORD;

    if (smsEmail && smsPassword && smsEmail.trim() !== '' && smsPassword.trim() !== '') {
      console.log(`✉️ [SMS] Production: Sending OTP ${code} to ${phone} via Eskiz...`);
      // Future production Eskiz.uz SMS dispatch call can go here
    }

    console.log(`🔑 [OTP] Development OTP code for ${phone} is: ${code}`);

    return res.json({
      success: true,
      message: 'Tasdiqlash kodi telefoningizga yuborildi',
      ...(process.env.NODE_ENV === 'development' ? { devOtp: code } : {})
    });
  } catch (err: any) {
    console.error('Send OTP error:', err);
    return res.status(500).json({ success: false, message: 'OTP yuborishda xatolik yuz berdi' });
  }
});

// POST /api/auth/otp/verify — Verify OTP code and login/register
router.post('/otp/verify', async (req: Request, res: Response) => {
  const { phoneNumber, code, fullName, referredByCode } = req.body;
  if (!phoneNumber || !code) {
    return res.status(400).json({ success: false, message: 'Telefon raqam va kod kiritilishi shart' });
  }

  const phone = normalizePhone(phoneNumber);
  try {
    const otpRecord = await prisma.otp.findFirst({
      where: {
        phoneNumber: phone,
        isUsed: false,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    if (!otpRecord) {
      return res.status(400).json({ success: false, message: 'Tasdiqlash kodi topilmadi yoki eskirgan' });
    }

    if (otpRecord.expiresAt < new Date()) {
      return res.status(400).json({ success: false, message: 'Tasdiqlash kodining muddati tugagan' });
    }

    if (otpRecord.code !== code) {
      // Increment attempts
      await prisma.otp.update({
        where: { id: otpRecord.id },
        data: { attempts: { increment: 1 } },
      });

      if (otpRecord.attempts >= 3) {
        await prisma.otp.update({
          where: { id: otpRecord.id },
          data: { isUsed: true },
        });
        return res.status(400).json({ success: false, message: 'Urinishlar soni tugadi. Yangi kod so\'rang.' });
      }

      return res.status(400).json({ success: false, message: 'Noto\'g\'ri tasdiqlash kodi' });
    }

    // Mark OTP as used
    await prisma.otp.update({
      where: { id: otpRecord.id },
      data: { isUsed: true },
    });

    // Check if user exists
    let user = await prisma.user.findUnique({
      where: { phoneNumber: phone },
    });

    let isNewUser = false;
    if (!user) {
      isNewUser = true;
      const orbitaId = `ORB-${Math.floor(100000 + Math.random() * 900000)}`;
      const name = fullName || 'Foydalanuvchi';

      let referredBy: any = null;
      if (referredByCode && referredByCode.trim().length > 0) {
        referredBy = await prisma.user.findUnique({
          where: { orbitaId: referredByCode.trim() },
        });
      }

      user = await prisma.user.create({
        data: {
          orbitaId,
          phoneNumber: phone,
          fullName: name,
          isVerified: true,
          walletBalance: 5000.0,
          referredById: referredBy ? referredBy.id : undefined,
        },
      });

      await prisma.transaction.create({
        data: {
          userId: user.id,
          title: "Ro'yxatdan o'tish bonusi",
          subtitle: "Orbita Go tizimiga qo'shilganingiz uchun",
          amount: 5000.0,
          isCredit: true,
          type: "REGISTRATION_BONUS"
        }
      });

      console.log(`👤 Yangi foydalanuvchi OTP orqali ro'yxatdan o'tdi: ${phone} (${orbitaId})`);
    }

    const token = generateToken({ id: user.id, phoneNumber: user.phoneNumber || '', role: user.role });

    return res.json({
      success: true,
      token,
      isNewUser,
      user: {
        id: user.id,
        orbitaId: user.orbitaId,
        phoneNumber: user.phoneNumber,
        email: user.email,
        fullName: user.fullName,
        username: user.username,
        role: user.role,
        avatarUrl: user.avatarUrl,
        walletBalance: user.walletBalance,
        isVerified: user.isVerified,
      },
    });
  } catch (err: any) {
    console.error('Verify OTP error:', err);
    return res.status(500).json({ success: false, message: 'OTP tasdiqlashda xatolik yuz berdi' });
  }
});

export default router;
