import { Router, Response } from 'express';
import { Server } from 'socket.io';
import prisma from '../lib/prisma';
import { authenticateToken, AuthRequest } from '../middleware/auth.middleware';

const router = Router();

// Helper: Check referral bonus based on completed trips (milestone: 2 trips)
async function checkReferralByTrips(clientId: string) {
  const user = await prisma.user.findUnique({
    where: { id: clientId },
    select: { id: true, referredById: true, isReferralRewardClaimed: true, totalStepsRedeemed: true },
  });
  if (!user || !user.referredById || user.isReferralRewardClaimed) return;

  const TRIPS_MILESTONE = 2;
  const completedTrips = await prisma.order.count({
    where: { clientId, status: 'COMPLETED' },
  });
  if (completedTrips < TRIPS_MILESTONE) return;

  // Milestone qo'lga kiritildi
  const BONUS = 5000.0;
  await prisma.$transaction([
    prisma.user.update({
      where: { id: user.id },
      data: {
        walletBalance: { increment: BONUS },
        isReferralRewardClaimed: true,
        transactions: {
          create: {
            title: 'Taklif bonusi',
            subtitle: '2 ta safar bajarilganligi uchun sovg\'a',
            amount: BONUS,
            isCredit: true,
            type: 'REFERRAL_BONUS',
          },
        },
      },
    }),
    prisma.user.update({
      where: { id: user.referredById },
      data: {
        walletBalance: { increment: BONUS },
        transactions: {
          create: {
            title: 'Taklif bonusi',
            subtitle: 'Do\'stingiz 2 ta safar qildi',
            amount: BONUS,
            isCredit: true,
            type: 'REFERRAL_BONUS',
          },
        },
      },
    }),
  ]);
  console.log(`🎁 Referral (safar) bonus berildi: userId=${user.id}, referrerId=${user.referredById}`);
}

// Helper: Safar vazifalarini yangilash
async function updateRideQuests(clientId: string) {
  try {
    const activeQuests = await prisma.rideQuest.findMany({ where: { isActive: true } });
    for (const quest of activeQuests) {
      const userQuest = await prisma.userRideQuest.findUnique({
        where: { userId_questId: { userId: clientId, questId: quest.id } }
      });

      if (userQuest) {
        if (userQuest.isCompleted) continue; // already completed

        const newCount = userQuest.currentCount + 1;
        const isCompleted = newCount >= quest.targetCount;

        if (isCompleted) {
          await prisma.$transaction([
            prisma.userRideQuest.update({
              where: { id: userQuest.id },
              data: { currentCount: newCount, isCompleted: true, isClaimed: true }
            }),
            prisma.user.update({
              where: { id: clientId },
              data: {
                walletBalance: { increment: quest.rewardPrice },
                transactions: {
                  create: {
                    title: `Vazifa mukofoti: ${quest.title}`,
                    subtitle: `Safar vazifasini muvaffaqiyatli yakunladingiz`,
                    amount: quest.rewardPrice,
                    isCredit: true,
                    type: "QUEST_REWARD"
                  }
                }
              }
            })
          ]);
          console.log(`🎉 User ${clientId} completed RideQuest: ${quest.title}. Awarded ${quest.rewardPrice} UZS.`);
        } else {
          await prisma.userRideQuest.update({
            where: { id: userQuest.id },
            data: { currentCount: newCount }
          });
        }
      } else {
        const isCompleted = quest.targetCount <= 1;
        if (isCompleted) {
          await prisma.$transaction([
            prisma.userRideQuest.create({
              data: { userId: clientId, questId: quest.id, currentCount: 1, isCompleted: true, isClaimed: true }
            }),
            prisma.user.update({
              where: { id: clientId },
              data: {
                walletBalance: { increment: quest.rewardPrice },
                transactions: {
                  create: {
                    title: `Vazifa mukofoti: ${quest.title}`,
                    subtitle: `Safar vazifasini muvaffaqiyatli yakunladingiz`,
                    amount: quest.rewardPrice,
                    isCredit: true,
                    type: "QUEST_REWARD"
                  }
                }
              }
            })
          ]);
        } else {
          await prisma.userRideQuest.create({
            data: { userId: clientId, questId: quest.id, currentCount: 1 }
          });
        }
      }
    }
  } catch (err) {
    console.error('Error updating ride quests:', err);
  }
}

// GET /api/driver/status — Haydovchi holati
router.get('/status', authenticateToken, async (req: AuthRequest, res: Response) => {
  const profile = await prisma.driverProfile.findUnique({
    where: { userId: req.user!.id },
  });

  return res.json({ success: true, profile });
});

// POST /api/driver/online — Online bo'lish
router.post('/online', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { lat, lng } = req.body;
  if (!lat || !lng) return res.status(400).json({ success: false, message: 'Joylashuv kerak' });

  const profile = await prisma.driverProfile.findUnique({
    where: { userId: req.user!.id }
  });
  if (!profile) {
    return res.status(400).json({ success: false, message: 'Haydovchi profili topilmadi' });
  }
  if (!profile.isVerified) {
    return res.status(403).json({ success: false, message: 'Hujjatlaringiz tasdiqlanmagan. Iltimos, faollashtirishni kuting.' });
  }

  await prisma.driverProfile.update({
    where: { userId: req.user!.id },
    data: { isOnline: true, currentLat: Number(lat), currentLng: Number(lng) },
  });

  return res.json({ success: true, message: 'Online' });
});

// POST /api/driver/offline — Offline
router.post('/offline', authenticateToken, async (req: AuthRequest, res: Response) => {
  await prisma.driverProfile.update({
    where: { userId: req.user!.id },
    data: { isOnline: false },
  });
  return res.json({ success: true, message: 'Offline' });
});

// POST /api/driver/accept/:orderId — Buyurtmani qabul qilish (atomik)
router.post('/accept/:orderId', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const driverProfile = await prisma.driverProfile.findUnique({
      where: { userId: req.user!.id },
      include: { user: true }
    });
    if (!driverProfile) {
      return res.status(400).json({ success: false, message: 'Haydovchi profili topilmadi' });
    }
    if (!driverProfile.isVerified) {
      return res.status(400).json({ success: false, message: 'Hujjatlaringiz tasdiqlanmagan.' });
    }
    if (driverProfile.user.walletBalance < 5000) {
      return res.status(400).json({ success: false, message: 'Balansingiz yetarli emas (kamida 5,000 so\'m).' });
    }

    // Atomik transaction — race condition oldini olish
    const updated = await prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({ where: { id: req.params.orderId } });
      if (!order || order.status !== 'SEARCHING') {
        throw new Error('ORDER_NOT_AVAILABLE');
      }
      return tx.order.update({
        where: { id: req.params.orderId },
        data: { driverId: req.user!.id, status: 'DRIVER_ARRIVING' },
        include: { driver: { select: { id: true, fullName: true, phoneNumber: true, driverProfile: true } } }
      });
    });

    const io = (global as any).io;
    if (io && updated.driver) {
      io.to(`client_${updated.clientId}`).emit('order_status_update', {
        orderId: updated.id,
        status: 'DRIVER_ARRIVING',
        driver: {
          id: updated.driver!.id,
          fullName: updated.driver!.fullName,
          phoneNumber: updated.driver!.phoneNumber,
          carModel: updated.driver!.driverProfile?.carModel,
          carNumber: updated.driver!.driverProfile?.carNumber,
          carColor: updated.driver!.driverProfile?.carColor,
          rating: updated.driver!.driverProfile?.rating,
        },
      });
    }

    return res.json({ success: true, order: updated });
  } catch (err: any) {
    if (err.message === 'ORDER_NOT_AVAILABLE') {
      return res.status(409).json({ success: false, message: 'Buyurtma boshqa haydovchi tomonidan qabul qilingan.' });
    }
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PATCH /api/driver/location — Joylashuv yangilash
router.patch('/location', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { lat, lng, orderId } = req.body;
  if (!lat || !lng) return res.status(400).json({ success: false, message: 'Joylashuv kerak' });

  await prisma.driverProfile.update({
    where: { userId: req.user!.id },
    data: { currentLat: Number(lat), currentLng: Number(lng) },
  });

  const io = (global as any).io;
  if (io && orderId) {
    const order = await prisma.order.findUnique({ where: { id: orderId } });
    if (order && order.driverId === req.user!.id) {
      io.to(`client_${order.clientId}`).emit('driver_location_update', {
        lat: Number(lat), lng: Number(lng), orderId,
      });
    }
  }

  return res.json({ success: true });
});

// POST /api/driver/arrived/:orderId — Yetib keldi
router.post('/arrived/:orderId', authenticateToken, async (req: AuthRequest, res: Response) => {
  const existing = await prisma.order.findUnique({ where: { id: req.params.orderId } });
  if (!existing || existing.driverId !== req.user!.id) {
    return res.status(403).json({ success: false, message: 'Bu buyurtma sizga tegishli emas' });
  }

  const order = await prisma.order.update({
    where: { id: req.params.orderId },
    data: { status: 'DRIVER_ARRIVED' },
  });

  const io = (global as any).io;
  if (io) {
    io.to(`client_${order.clientId}`).emit('order_status_update', {
      orderId: order.id,
      status: 'DRIVER_ARRIVED',
    });
  }

  return res.json({ success: true });
});

// POST /api/driver/start/:orderId — Sayohat boshlash
router.post('/start/:orderId', authenticateToken, async (req: AuthRequest, res: Response) => {
  const existing = await prisma.order.findUnique({ where: { id: req.params.orderId } });
  if (!existing || existing.driverId !== req.user!.id) {
    return res.status(403).json({ success: false, message: 'Bu buyurtma sizga tegishli emas' });
  }

  const order = await prisma.order.update({
    where: { id: req.params.orderId },
    data: { status: 'IN_TRIP' },
  });

  const io = (global as any).io;
  if (io) {
    io.to(`client_${order.clientId}`).emit('order_status_update', {
      orderId: order.id,
      status: 'IN_TRIP',
    });
  }

  return res.json({ success: true });
});

// POST /api/driver/complete/:orderId — Yakunlash (komissiya va mijoz balansi)
router.post('/complete/:orderId', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const order = await prisma.order.findUnique({ where: { id: req.params.orderId } });
    if (!order) {
      return res.status(404).json({ success: false, message: 'Buyurtma topilmadi' });
    }
    if (order.driverId !== req.user!.id) {
      return res.status(403).json({ success: false, message: 'Ruxsat yo\'q' });
    }

    // Atomik: buyurtmani yakunlash + haydovchi komissiyasi + mijoz balansi
    await prisma.$transaction(async (tx) => {
      // Buyurtmani COMPLETED qilamiz
      await tx.order.update({
        where: { id: req.params.orderId },
        data: { status: 'COMPLETED' },
      });

      // Haydovchi statistikasi yangilash
      await tx.driverProfile.update({
        where: { userId: req.user!.id },
        data: { totalTrips: { increment: 1 } },
      });

      const commission = order.price * 0.1;

      if (order.paymentMethod === 'WALLET') {
        // 1. Mijoz balansidan butun safar narxi yechiladi
        await tx.user.update({
          where: { id: order.clientId },
          data: {
            walletBalance: { decrement: order.price },
            transactions: {
              create: {
                title: "Safar to'lovi (Hamyon)",
                subtitle: `Yo'nalish: ${order.fromAddress.split(',')[0]} -> ${order.toAddress.split(',')[0]}`,
                amount: order.price,
                isCredit: false,
                type: "TRIP_SPENDING"
              }
            }
          }
        });

        // 2. Haydovchi balansiga (safar narxi - komissiya) qo'shiladi
        const driverNetEarnings = order.price - commission;
        await tx.user.update({
          where: { id: req.user!.id },
          data: {
            walletBalance: { increment: driverNetEarnings },
            transactions: {
              create: [
                {
                  title: "Safar daromadi (Hamyon)",
                  subtitle: `Yo'nalish: ${order.fromAddress.split(',')[0]} -> ${order.toAddress.split(',')[0]}`,
                  amount: order.price,
                  isCredit: true,
                  type: "TRIP_EARNING"
                },
                {
                  title: "Tizim xizmati (10%)",
                  subtitle: `Buyurtma: ${order.id.substring(0, 8)}`,
                  amount: commission,
                  isCredit: false,
                  type: "COMMISSION"
                }
              ]
            }
          }
        });
        console.log(`💰 Hamyon orqali to'lov (completeTrip): ${order.price} so'm mijozdan olindi va ${driverNetEarnings} so'm haydovchiga o'tkazildi.`);
      } else {
        // CASH to'lov
        // 1. Mijoz balansi o'zgarmaydi.
        // 2. Haydovchidan 10% komissiya yechiladi
        await tx.user.update({
          where: { id: req.user!.id },
          data: {
            walletBalance: { decrement: commission },
            transactions: {
              create: [
                {
                  title: "Safar daromadi (Naqd)",
                  subtitle: `Yo'nalish: ${order.fromAddress.split(',')[0]} -> ${order.toAddress.split(',')[0]}`,
                  amount: order.price,
                  isCredit: true,
                  type: "TRIP_EARNING"
                },
                {
                  title: "Tizim xizmati (10% komissiya)",
                  subtitle: `Buyurtma: ${order.id.substring(0, 8)}`,
                  amount: commission,
                  isCredit: false,
                  type: "COMMISSION"
                }
              ]
            }
          }
        });
        console.log(`💵 Naqd pul orqali to'lov (completeTrip): ${order.price} so'm naqd. Haydovchidan ${commission} so'm komissiya yechib olindi.`);
      }
    });

    const io = (global as any).io;
    if (io) {
      io.to(`client_${order.clientId}`).emit('order_status_update', {
        orderId: order.id,
        status: 'COMPLETED',
        price: order.price,
      });
    }

    // Referral milestone check
    checkReferralByTrips(order.clientId).catch(console.error);
    updateRideQuests(order.clientId).catch(console.error);

    return res.json({ success: true });
  } catch (err: any) {
    console.error('Complete order error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/driver/orders — Haydovchi buyurtmalari tarixi (batafsil)
router.get('/orders', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const orders = await prisma.order.findMany({
      where: { driverId: req.user!.id },
      include: {
        client: { select: { fullName: true, phoneNumber: true } }
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    const formatted = orders.map(o => ({
      id: o.id,
      fromAddress: o.fromAddress,
      toAddress: o.toAddress,
      price: o.price,
      status: o.status,
      distanceKm: o.distanceKm,
      durationMin: o.durationMin,
      tariff: o.tariff,
      createdAt: o.createdAt,
      clientName: o.client?.fullName || 'Mijoz',
    }));

    return res.json({ success: true, orders: formatted });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/driver/stats — Haydovchi statistikasi
router.get('/stats', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    let profile = await prisma.driverProfile.findUnique({
      where: { userId: req.user!.id },
      include: { user: true }
    });

    if (!profile) {
      profile = await prisma.driverProfile.create({
        data: {
          userId: req.user!.id,
          carModel: 'Chevrolet Nexia 3',
          carColor: 'Oq',
          carNumber: `01 A ${Math.floor(100 + Math.random() * 900)} AA`,
          isVerified: true,
          isOnline: false,
        },
        include: { user: true }
      });
      await prisma.user.update({
        where: { id: req.user!.id },
        data: { role: 'DRIVER' },
      });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const weekAgo = new Date(today);
    weekAgo.setDate(weekAgo.getDate() - 7);

    const [todayOrders, weekOrders, totalCompleted] = await Promise.all([
      prisma.order.findMany({
        where: { driverId: req.user!.id, status: 'COMPLETED', createdAt: { gte: today } },
        select: { price: true }
      }),
      prisma.order.findMany({
        where: { driverId: req.user!.id, status: 'COMPLETED', createdAt: { gte: weekAgo } },
        select: { price: true }
      }),
      prisma.order.count({ where: { driverId: req.user!.id, status: 'COMPLETED' } }),
    ]);

    const todayEarnings = todayOrders.reduce((sum, o) => sum + o.price * 0.9, 0); // 10% komissiya ayriladi
    const weekEarnings = weekOrders.reduce((sum, o) => sum + o.price * 0.9, 0);

    return res.json({
      success: true,
      stats: {
        todayTrips: todayOrders.length,
        todayEarnings: Math.round(todayEarnings),
        weekTrips: weekOrders.length,
        weekEarnings: Math.round(weekEarnings),
        totalTrips: totalCompleted,
        rating: profile.rating,
        walletBalance: profile.user.walletBalance,
        isOnline: profile.isOnline,
        isVerified: profile.isVerified,
      }
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PATCH /api/driver/toggle-online — Online/Offline almashtirish
router.patch('/toggle-online', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    let profile = await prisma.driverProfile.findUnique({ where: { userId: req.user!.id } });
    
    if (!profile) {
      profile = await prisma.driverProfile.create({
        data: {
          userId: req.user!.id,
          carModel: 'Chevrolet Nexia 3',
          carColor: 'Oq',
          carNumber: `01 A ${Math.floor(100 + Math.random() * 900)} AA`,
          isVerified: true,
          isOnline: false,
        }
      });
      await prisma.user.update({
        where: { id: req.user!.id },
        data: { role: 'DRIVER' },
      });
    }

    const newStatus = !profile.isOnline;
    await prisma.driverProfile.update({
      where: { userId: req.user!.id },
      data: { isOnline: newStatus },
    });

    return res.json({ success: true, isOnline: newStatus });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/driver/wallet/transactions — Hamyon tranzaksiyalari tarixi
router.get('/wallet/transactions', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const transactions = await prisma.transaction.findMany({
      where: { userId: req.user!.id },
      orderBy: { createdAt: 'desc' }
    });
    return res.json({ success: true, transactions });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/driver/heatmap — Oxirgi 30 daqiqadagi talab xaritasi (issiq hududlar)
router.get('/heatmap', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
    const recentOrders = await prisma.order.findMany({
      where: {
        createdAt: { gte: thirtyMinutesAgo },
        status: { in: ['SEARCHING', 'DRIVER_ARRIVING', 'DRIVER_ARRIVED'] }
      },
      select: {
        fromLat: true,
        fromLng: true,
        price: true,
      }
    });

    const hotspots = recentOrders.map(o => ({
      lat: o.fromLat,
      lng: o.fromLng,
      intensity: o.price > 15000 ? 1.0 : 0.6,
    }));

    return res.json({ success: true, hotspots });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

export default router;
