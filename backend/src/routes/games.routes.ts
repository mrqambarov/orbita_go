import { Router, Response, Request } from 'express';
import prisma from '../lib/prisma';
import { authenticateToken, AuthRequest } from '../middleware/auth.middleware';

const router = Router();

// --- STATS & LEADERBOARD ---

// POST /api/games/stats — Oliy ball yoki darajani yangilash
router.post('/stats', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { gameType, score, level } = req.body;
  if (!gameType) return res.status(400).json({ success: false, message: 'Game type is required' });

  try {
    const stat = await prisma.gameStat.upsert({
      where: {
        userId_gameType: {
          userId: req.user!.id,
          gameType: gameType
        }
      },
      update: {
        highScore: { set: score ? Math.max(score, 0) : undefined },
        level: { set: level ? Math.max(level, 1) : undefined }
      },
      create: {
        userId: req.user!.id,
        gameType: gameType,
        highScore: score || 0,
        level: level || 1
      }
    });

    // Update missions progress
    const activeMissions = await prisma.dailyMission.findMany({
      where: { gameType: gameType, isActive: true }
    });

    for (const mission of activeMissions) {
      const userMission = await prisma.userMission.findFirst({
        where: { userId: req.user!.id, missionId: mission.id }
      });

      const newValue = Math.max(
        userMission?.currentValue || 0,
        score || 0,
        level || 0
      );

      const isCompleted = newValue >= mission.goalValue;

      if (userMission) {
        await prisma.userMission.update({
          where: { id: userMission.id },
          data: {
            currentValue: newValue,
            isCompleted: userMission.isCompleted ? true : isCompleted
          }
        });
      } else {
        await prisma.userMission.create({
          data: {
            userId: req.user!.id,
            missionId: mission.id,
            currentValue: newValue,
            isCompleted: isCompleted
          }
        });
      }
    }

    return res.json({ success: true, stat });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/games/leaderboard — O'yinlar bo'yicha reyting
router.get('/leaderboard', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { gameType } = req.query;
  if (!gameType) return res.status(400).json({ success: false, message: 'Game type is required' });

  try {
    const stats = await prisma.gameStat.findMany({
      where: { gameType: String(gameType) },
      orderBy: [
        { level: 'desc' },
        { highScore: 'desc' }
      ],
      take: 20,
      include: {
        user: {
          select: { fullName: true, orbitaId: true, avatarUrl: true }
        }
      }
    });

    return res.json({ success: true, leaderboard: stats });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// --- MISSIONS ---

// GET /api/games/missions — Kunlik topshiriqlar
router.get('/missions', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    // 1. Get active daily missions
    const activeMissions = await prisma.dailyMission.findMany({
      where: { isActive: true }
    });

    // 2. Get or create user missions for these active ones
    const userMissions = await Promise.all(activeMissions.map(async (m) => {
      let um = await prisma.userMission.findFirst({
        where: { userId: req.user!.id, missionId: m.id }
      });

      if (!um) {
        um = await prisma.userMission.create({
          data: { userId: req.user!.id, missionId: m.id }
        });
      }
      return { ...m, ...um, id: m.id, userMissionId: um.id };
    }));

    return res.json({ success: true, missions: userMissions });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/games/missions/claim — Mukofotni olish
router.post('/missions/claim', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { missionId } = req.body;
  
  try {
    const um = await prisma.userMission.findFirst({
      where: { userId: req.user!.id, missionId, isCompleted: true, isClaimed: false }
    });

    if (!um) return res.status(400).json({ success: false, message: 'Topshiriq hali yakunlanmagan yoki mukofot olingan' });

    const mission = await prisma.dailyMission.findUnique({ where: { id: missionId } });
    if (!mission) return res.status(404).json({ success: false, message: 'Topshiriq topilmadi' });

    await prisma.$transaction([
      prisma.userMission.update({
        where: { id: um.id },
        data: { isClaimed: true }
      }),
      prisma.user.update({
        where: { id: req.user!.id },
        data: { walletBalance: { increment: mission.reward } }
      })
    ]);

    return res.json({ success: true, reward: mission.reward });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// --- GARDEN ---

// GET /api/games/garden — Bog' holatini ko'rish
router.get('/garden', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    let garden = await prisma.gardenState.findUnique({
      where: { userId: req.user!.id }
    });

    if (!garden) {
      garden = await prisma.gardenState.create({
        data: { userId: req.user!.id }
      });
    }

    return res.json({ success: true, garden });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/games/garden/water — Daraxtga suv quyish
router.post('/garden/water', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { amount = 1 } = req.body;

  try {
    const garden = await prisma.gardenState.update({
      where: { userId: req.user!.id },
      data: {
        water: { increment: amount }
      }
    });

    // Check for level up
    if (garden.water >= garden.level * 100) {
      const updated = await prisma.gardenState.update({
        where: { userId: req.user!.id },
        data: {
          level: { increment: 1 },
          water: 0
        }
      });
      return res.json({ success: true, garden: updated, leveledUp: true });
    }

    return res.json({ success: true, garden });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/games/garden/water-friend — Do'stining daraxtiga suv quyish (co-op)
router.post('/garden/water-friend', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { friendOrbitaId } = req.body;
  if (!friendOrbitaId) {
    return res.status(400).json({ success: false, message: 'Do\'stingizning Orbita ID raqami kiritilishi shart' });
  }

  try {
    const friend = await prisma.user.findUnique({
      where: { orbitaId: friendOrbitaId },
      include: { garden: true }
    });

    if (!friend) {
      return res.status(404).json({ success: false, message: 'Foydalanuvchi topilmadi' });
    }

    if (friend.id === req.user!.id) {
      return res.status(400).json({ success: false, message: 'O\'zingizning daraxtingizga bu yerda suv quya olmaysiz' });
    }

    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const alreadyWatered = await prisma.gardenCoopAction.findFirst({
      where: {
        giverId: req.user!.id,
        receiverId: friend.id,
        createdAt: { gte: startOfDay }
      }
    });

    if (alreadyWatered) {
      return res.status(400).json({ success: false, message: 'Siz bugun ushbu do\'stingizga yordam berib bo\'ldingiz. Ertaga qayta urinib ko\'ring.' });
    }

    let friendGarden = friend.garden;
    if (!friendGarden) {
      friendGarden = await prisma.gardenState.create({
        data: { userId: friend.id }
      });
    }

    const waterIncrement = 10;
    const amountVal = 50.0; // 50 UZS bonus to taksi hamyon

    await prisma.$transaction([
      prisma.gardenCoopAction.create({
        data: { giverId: req.user!.id, receiverId: friend.id }
      }),
      prisma.gardenState.update({
        where: { id: friendGarden.id },
        data: { water: { increment: waterIncrement } }
      }),
      prisma.user.update({
        where: { id: req.user!.id },
        data: {
          walletBalance: { increment: amountVal },
          transactions: {
            create: {
              title: "Do'stga ko'mak mukofoti",
              subtitle: `${friend.fullName || "Do'stingiz"}ning daraxtini sug'organingiz uchun`,
              amount: amountVal,
              isCredit: true,
              type: "COOP_REWARD"
            }
          }
        }
      })
    ]);

    return res.json({
      success: true,
      message: `Muvaffaqiyatli bajarildi! ${friend.fullName || "Do'stingiz"}ning daraxtiga +10 suv quyildi va siz 50 UZS hamyon mukofoti oldingiz.`
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// --- SHOP ---

// GET /api/games/shop — Do'kon
router.get('/shop', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const items = await prisma.shopItem.findMany({ where: { isActive: true } });
    const inventory = await prisma.userInventory.findMany({ where: { userId: req.user!.id } });
    
    return res.json({ success: true, items, inventory });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/games/shop/buy — Buyum sotib olish
router.post('/shop/buy', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { itemId } = req.body;

  try {
    const item = await prisma.shopItem.findUnique({ where: { id: itemId } });
    if (!item) return res.status(404).json({ success: false, message: 'Buyum topilmadi' });

    const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
    if (user!.walletBalance < item.price) {
      return res.status(400).json({ success: false, message: 'Mablag\' yetarli emas' });
    }

    if (item.category === 'PROMO') {
      const promoCode = `ORBITA-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
      await prisma.$transaction([
        prisma.user.update({
          where: { id: req.user!.id },
          data: { walletBalance: { decrement: item.price } }
        }),
        prisma.promoCode.create({
          data: { code: promoCode, amount: 5000, userId: req.user!.id }
        }),
        prisma.userInventory.create({
          data: { userId: req.user!.id, itemId: itemId }
        })
      ]);
      return res.json({ success: true, message: `Sotib olindi! Promo kodingiz: ${promoCode}`, promoCode });
    }

    await prisma.$transaction([
      prisma.user.update({
        where: { id: req.user!.id },
        data: { walletBalance: { decrement: item.price } }
      }),
      prisma.userInventory.create({
        data: { userId: req.user!.id, itemId: itemId }
      })
    ]);

    return res.json({ success: true, message: 'Muvaffaqiyatli sotib olindi' });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// --- LEGACY CONVERT ---

router.post('/runner/convert', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { coins } = req.body;
  if (!coins || coins <= 0) return res.status(400).json({ success: false, message: 'Tangalar noto\'g\'ri' });

  try {
    const rate = 10; // 1 coin = 10 UZS
    const amount = coins * rate;

    const user = await prisma.user.update({
      where: { id: req.user!.id },
      data: {
        walletBalance: { increment: amount }
      }
    });

    return res.json({ success: true, message: `${amount} UZS hamyoningizga o'tkazildi!`, user });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// --- DAILY CHECK-IN ---

// GET /api/games/check-in — Kunlik kirish holati
router.get('/check-in', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
    if (!user) return res.status(404).json({ success: false, message: 'Foydalanuvchi topilmadi' });

    const now = new Date();
    let hasCheckedInToday = false;

    if (user.lastCheckInAt) {
      const lastCheckIn = new Date(user.lastCheckInAt);
      hasCheckedInToday = 
        lastCheckIn.getDate() === now.getDate() &&
        lastCheckIn.getMonth() === now.getMonth() &&
        lastCheckIn.getFullYear() === now.getFullYear();
    }

    // Check if streak is broken (last check-in > 48h)
    let currentStreak = user.checkInStreak;
    if (user.lastCheckInAt) {
      const diffTime = Math.abs(now.getTime() - new Date(user.lastCheckInAt).getTime());
      const diffHours = diffTime / (1000 * 60 * 60);
      if (diffHours > 48) {
        currentStreak = 0;
      }
    }

    const rewards = [10, 25, 50, 80, 120, 180, 300]; // In coins

    return res.json({
      success: true,
      hasCheckedInToday,
      streak: currentStreak,
      rewards
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/games/check-in/claim — Kunlik kirish mukofotini olish
router.post('/check-in/claim', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
    if (!user) return res.status(404).json({ success: false, message: 'Foydalanuvchi topilmadi' });

    const now = new Date();
    if (user.lastCheckInAt) {
      const lastCheckIn = new Date(user.lastCheckInAt);
      const hasCheckedInToday = 
        lastCheckIn.getDate() === now.getDate() &&
        lastCheckIn.getMonth() === now.getMonth() &&
        lastCheckIn.getFullYear() === now.getFullYear();

      if (hasCheckedInToday) {
        return res.status(400).json({ success: false, message: 'Bugun allaqachon mukofot olgansiz' });
      }
    }

    let streak = user.checkInStreak;
    if (user.lastCheckInAt) {
      const diffTime = Math.abs(now.getTime() - new Date(user.lastCheckInAt).getTime());
      const diffHours = diffTime / (1000 * 60 * 60);
      if (diffHours > 48) {
        streak = 0;
      }
    }

    // Increment streak, reset to 1 if it was 7
    streak = (streak % 7) + 1;

    const rewards = [10, 25, 50, 80, 120, 180, 300];
    const xpRewards = [10, 20, 30, 40, 50, 75, 150];
    const coinReward = rewards[streak - 1];
    const xpReward = xpRewards[streak - 1];

    const updatedUser = await prisma.user.update({
      where: { id: req.user!.id },
      data: {
        lastCheckInAt: now,
        checkInStreak: streak
      }
    });

    return res.json({
      success: true,
      streak,
      coins: coinReward,
      xp: xpReward,
      user: updatedUser,
      message: `Tabriklaymiz! Kunlik mukofot: +${coinReward} tanga va +${xpReward} XP!`
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// --- SEEDING (Dev only) ---
router.post('/dev/seed', async (req: Request, res: Response) => {
  try {
    await prisma.dailyMission.deleteMany();
    await prisma.dailyMission.createMany({
      data: [
        { title: 'Matematika ustasi', description: 'Math Dashda 200 ball to\'pla', reward: 50, goalValue: 200, gameType: 'MATH_DASH' },
        { title: 'So\'z ustasi', description: 'Word Questda 2 ta darajani yut', reward: 100, goalValue: 2, gameType: 'WORD_QUEST' },
        { title: 'Kosmik sayyoh', description: 'Gravity Runda 500 ball to\'pla', reward: 80, goalValue: 500, gameType: 'GRAVITY_RUN' },
        { title: 'Xotira mutaxassisi', description: 'Memoryda 1000 ball to\'pla', reward: 120, goalValue: 1000, gameType: 'MEMORY' },
      ]
    });

    await prisma.shopItem.deleteMany();
    await prisma.shopItem.createMany({
      data: [
        { name: 'Oltin Raketa', description: 'Gravity Run uchun oltin dizayn', price: 1000, category: 'SKIN' },
        { name: 'Qizil Raketa', description: 'Gravity Run uchun qizil dizayn', price: 500, category: 'SKIN' },
        { name: 'Qalqon x2', description: 'O\'yin boshida 2 ta qalqon', price: 200, category: 'POWERUP' },
        { name: 'Vaqtni to\'xtatish', description: 'Memoryda 5 soniya qo\'shimcha vaqt', price: 300, category: 'POWERUP' },
        { name: '5000 UZS Chegirma', description: 'Orbita Go safari uchun 5000 so\'mlik promo-kod', price: 5000, category: 'PROMO' },
      ]
    });

    return res.json({ success: true, message: 'Game data seeded' });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/games/tournament/weekly — Haftalik o'yin turniri natijalari
router.get('/tournament/weekly', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const stats = await prisma.gameStat.findMany({
      include: {
        user: { select: { fullName: true, orbitaId: true, avatarUrl: true } }
      }
    });

    const userScores: Record<string, { userId: string, fullName: string, orbitaId: string, avatarUrl: string | null, totalScore: number }> = {};
    for (const stat of stats) {
      if (!userScores[stat.userId]) {
        userScores[stat.userId] = {
          userId: stat.userId,
          fullName: stat.user.fullName || 'Foydalanuvchi',
          orbitaId: stat.user.orbitaId,
          avatarUrl: stat.user.avatarUrl,
          totalScore: 0
        };
      }
      userScores[stat.userId].totalScore += stat.highScore;
    }

    const leaderboard = Object.values(userScores).sort((a, b) => b.totalScore - a.totalScore).slice(0, 10);

    const nextSunday = new Date();
    nextSunday.setDate(nextSunday.getDate() + (7 - nextSunday.getDay()) % 7);
    nextSunday.setHours(23, 59, 59, 999);
    const timeRemainingMs = nextSunday.getTime() - Date.now();

    return res.json({
      success: true,
      leaderboard,
      resetCountdownSeconds: Math.max(0, Math.floor(timeRemainingMs / 1000))
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

export default router;
