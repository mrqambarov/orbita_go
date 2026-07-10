import { Router, Request, Response } from 'express';
import prisma from '../lib/prisma';
import { authenticateToken, AuthRequest } from '../middleware/auth.middleware';
import axios from 'axios';
import fs from 'fs';
import path from 'path';

const router = Router();

// GET /api/order/geocode — Qidirish
router.get('/geocode', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { query } = req.query;
  if (!query) {
    return res.json({ success: true, results: [] });
  }

  try {
    const response = await axios.get('https://nominatim.openstreetmap.org/search', {
      params: {
        q: `${query}, Kosonsoy, Namangan`,
        format: 'json',
        limit: 8,
        addressdetails: 1,
      },
      headers: {
        'User-Agent': 'OrbitaGoApp/1.0.0 (contact@orbitago.uz)'
      }
    });

    const results = response.data.map((item: any) => {
      const parts = item.display_name.split(',');
      const title = parts[0] + (parts[1] ? ', ' + parts[1].trim() : '');
      return {
        name: title,
        address: item.display_name,
        lat: parseFloat(item.lat),
        lng: parseFloat(item.lon),
      };
    });

    return res.json({ success: true, results });
  } catch (err: any) {
    console.error('Geocoding search error:', err.message);
    return res.json({ success: false, message: 'Qidiruvda xatolik yuz berdi' });
  }
});

// GET /api/order/reverse-geocode — Koordinataga qarab manzil olish
router.get('/reverse-geocode', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { lat, lng } = req.query;
  if (!lat || !lng) {
    return res.status(400).json({ success: false, message: 'Koordinatalar etarli emas' });
  }

  try {
    const response = await axios.get('https://nominatim.openstreetmap.org/reverse', {
      params: {
        lat: Number(lat),
        lon: Number(lng),
        format: 'json',
        addressdetails: 1,
      },
      headers: {
        'User-Agent': 'OrbitaGoApp/1.0.0 (contact@orbitago.uz)'
      }
    });

    if (response.data && response.data.display_name) {
      const parts = response.data.display_name.split(',');
      const title = parts[0] + (parts[1] ? ', ' + parts[1].trim() : '');
      return res.json({ success: true, address: title, fullAddress: response.data.display_name });
    }

    return res.json({ success: false, message: 'Manzil topilmadi' });
  } catch (err: any) {
    console.error('Reverse geocoding error:', err.message);
    return res.json({ success: false, message: 'Manzilni aniqlashda xatolik' });
  }
});

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

// Trip simulation background job
async function simulateTrip(
  orderId: string,
  clientId: string,
  fromLat: number,
  fromLng: number,
  toLat: number,
  toLng: number
) {
  const io = (global as any).io;
  if (!io) return;

  setTimeout(async () => {
    try {
      const order = await prisma.order.findUnique({ where: { id: orderId } });
      if (!order || order.status !== 'SEARCHING') {
        console.log(`🤖 Simulyator: Buyurtma ${orderId} faol haydovchi tomonidan qabul qilinganligi sababli simulyatsiya bekor qilindi.`);
        return;
      }

      const driver = await prisma.user.findFirst({
        where: { role: 'DRIVER', orbitaId: 'ORB-888888' },
        include: { driverProfile: true },
      });
      if (!driver) return;

      await prisma.order.update({
        where: { id: orderId },
        data: { driverId: driver.id, status: 'DRIVER_ARRIVING' },
      });

      console.log(`🤖 Simulyator: Buyurtma ${orderId} uchun haydovchi biriktirildi.`);

      io.to(`client_${clientId}`).emit('order_status_update', {
        orderId,
        status: 'DRIVER_ARRIVING',
        driver: {
          id: driver.id,
          fullName: driver.fullName,
          phoneNumber: driver.phoneNumber,
          carModel: driver.driverProfile?.carModel || 'Chevrolet Nexia 3',
          carNumber: driver.driverProfile?.carNumber || '01 A 777 AA',
          carColor: driver.driverProfile?.carColor || 'Oq',
          rating: driver.driverProfile?.rating || 4.9,
        },
      });

      // Fetch driver-to-pickup route from OSRM
      const driverStartLat = fromLat + 0.005;
      const driverStartLng = fromLng + 0.005;
      let arrivalPoints: number[][] = [];

      try {
        const arrivalRes = await axios.get(`http://router.project-osrm.org/route/v1/driving/${driverStartLng},${driverStartLat};${fromLng},${fromLat}?overview=full&geometries=geojson`);
        if (arrivalRes.data?.routes?.[0]) {
          arrivalPoints = arrivalRes.data.routes[0].geometry.coordinates.map((c: any) => [c[1], c[0]]);
        }
      } catch (_) {}

      // Fallback if OSRM fails
      if (arrivalPoints.length === 0) {
        for (let i = 0; i <= 5; i++) {
          const progress = i / 5;
          arrivalPoints.push([
            driverStartLat + (fromLat - driverStartLat) * progress,
            driverStartLng + (fromLng - driverStartLng) * progress,
          ]);
        }
      }

      // Move driver along arrival points
      let arrivalStep = 0;
      const totalArrivalSteps = Math.min(arrivalPoints.length, 8);
      const stepIndices = Array.from({ length: totalArrivalSteps }, (_, i) => 
        Math.floor(i * (arrivalPoints.length - 1) / (totalArrivalSteps - 1))
      );

      const intervalId = setInterval(async () => {
        if (arrivalStep < totalArrivalSteps) {
          const pt = arrivalPoints[stepIndices[arrivalStep]];
          io.to(`client_${clientId}`).emit('driver_location_update', {
            lat: pt[0],
            lng: pt[1],
            orderId,
          });
          arrivalStep++;
        } else {
          clearInterval(intervalId);

          await prisma.order.update({
            where: { id: orderId },
            data: { status: 'DRIVER_ARRIVED' },
          });
          io.to(`client_${clientId}`).emit('order_status_update', {
            orderId,
            status: 'DRIVER_ARRIVED',
          });

          setTimeout(async () => {
            await prisma.order.update({
              where: { id: orderId },
              data: { status: 'IN_TRIP' },
            });
            io.to(`client_${clientId}`).emit('order_status_update', {
              orderId,
              status: 'IN_TRIP',
            });

            // Fetch trip route from OSRM
            let tripPoints: number[][] = [];
            try {
              const tripRes = await axios.get(`http://router.project-osrm.org/route/v1/driving/${fromLng},${fromLat};${toLng},${toLat}?overview=full&geometries=geojson`);
              if (tripRes.data?.routes?.[0]) {
                tripPoints = tripRes.data.routes[0].geometry.coordinates.map((c: any) => [c[1], c[0]]);
              }
            } catch (_) {}

            if (tripPoints.length === 0) {
              for (let i = 0; i <= 6; i++) {
                const progress = i / 6;
                tripPoints.push([
                  fromLat + (toLat - fromLat) * progress,
                  fromLng + (toLng - fromLng) * progress,
                ]);
              }
            }

            let tripStep = 0;
            const totalTripSteps = Math.min(tripPoints.length, 10);
            const tripIndices = Array.from({ length: totalTripSteps }, (_, i) => 
              Math.floor(i * (tripPoints.length - 1) / (totalTripSteps - 1))
            );

            const tripIntervalId = setInterval(async () => {
              if (tripStep < totalTripSteps) {
                const pt = tripPoints[tripIndices[tripStep]];
                io.to(`client_${clientId}`).emit('driver_location_update', {
                  lat: pt[0],
                  lng: pt[1],
                  orderId,
                });
                tripStep++;
              } else {
                clearInterval(tripIntervalId);

                await prisma.order.update({
                  where: { id: orderId },
                  data: { status: 'COMPLETED' },
                });
                io.to(`client_${clientId}`).emit('order_status_update', {
                  orderId,
                  status: 'COMPLETED',
                });
                console.log(`🤖 Simulyator: Buyurtma ${orderId} yakunlandi.`);
              }
            }, 3000);
          }, 3000);
        }
      }, 2000);
    } catch (err) {
      console.error('Simulation error:', err);
    }
  // Simulyatsiya faqat development muhitida ishlaydi
  }, process.env.NODE_ENV === 'development' ? 60000 : 99999999999);
}

async function simulateTripFast(
  orderId: string,
  clientId: string,
  fromLat: number,
  fromLng: number,
  toLat: number,
  toLng: number
) {
  const io = (global as any).io;
  if (!io) return;

  setTimeout(async () => {
    try {
      const order = await prisma.order.findUnique({ where: { id: orderId } });
      if (!order || order.status !== 'SEARCHING') return;

      let driver: any = await prisma.user.findFirst({
        where: { role: 'DRIVER', orbitaId: 'ORB-888888' },
        include: { driverProfile: true }
      });

      if (!driver) {
        driver = await prisma.user.create({
          data: {
            username: 'web_demo_driver',
            fullName: 'Alijon Tojiyev',
            phoneNumber: '+998901111111',
            password: 'dummy_hash',
            role: 'DRIVER',
            orbitaId: 'ORB-888888',
            driverProfile: {
              create: {
                carModel: 'Chevrolet Nexia 3',
                carNumber: '01 A 777 AA',
                carColor: 'Oq',
                rating: 4.9,
                isOnline: true,
                currentLat: fromLat + 0.005,
                currentLng: fromLng + 0.005
              }
            }
          },
          include: { driverProfile: true }
        });
      }

      await prisma.order.update({
        where: { id: orderId },
        data: { driverId: driver.id, status: 'DRIVER_ARRIVING' },
      });

      io.to(`client_${clientId}`).emit('order_status_update', {
        orderId,
        status: 'DRIVER_ARRIVING',
        driver: {
          id: driver.id,
          fullName: driver.fullName,
          phoneNumber: driver.phoneNumber,
          carModel: driver.driverProfile?.carModel || 'Chevrolet Nexia 3',
          carNumber: driver.driverProfile?.carNumber || '01 A 777 AA',
          carColor: driver.driverProfile?.carColor || 'Oq',
          rating: driver.driverProfile?.rating || 4.9,
        },
      });

      const driverStartLat = fromLat + 0.003;
      const driverStartLng = fromLng + 0.003;
      let arrivalPoints: number[][] = [];

      try {
        const arrivalRes = await axios.get(`http://router.project-osrm.org/route/v1/driving/${driverStartLng},${driverStartLat};${fromLng},${fromLat}?overview=full&geometries=geojson`);
        if (arrivalRes.data?.routes?.[0]) {
          arrivalPoints = arrivalRes.data.routes[0].geometry.coordinates.map((c: any) => [c[1], c[0]]);
        }
      } catch (_) {}

      if (arrivalPoints.length === 0) {
        for (let i = 0; i <= 5; i++) {
          const progress = i / 5;
          arrivalPoints.push([
            driverStartLat + (fromLat - driverStartLat) * progress,
            driverStartLng + (fromLng - driverStartLng) * progress,
          ]);
        }
      }

      let arrivalStep = 0;
      const totalArrivalSteps = Math.min(arrivalPoints.length, 6);
      const stepIndices = Array.from({ length: totalArrivalSteps }, (_, i) => 
        Math.floor(i * (arrivalPoints.length - 1) / (totalArrivalSteps - 1))
      );

      const intervalId = setInterval(async () => {
        if (arrivalStep < totalArrivalSteps) {
          const pt = arrivalPoints[stepIndices[arrivalStep]];
          io.to(`client_${clientId}`).emit('driver_location_update', {
            lat: pt[0],
            lng: pt[1],
            orderId,
          });
          arrivalStep++;
        } else {
          clearInterval(intervalId);

          await prisma.order.update({
            where: { id: orderId },
            data: { status: 'DRIVER_ARRIVED' },
          });
          io.to(`client_${clientId}`).emit('order_status_update', {
            orderId,
            status: 'DRIVER_ARRIVED',
          });

          setTimeout(async () => {
            await prisma.order.update({
              where: { id: orderId },
              data: { status: 'IN_TRIP' },
            });
            io.to(`client_${clientId}`).emit('order_status_update', {
              orderId,
              status: 'IN_TRIP',
            });

            let tripPoints: number[][] = [];
            try {
              const tripRes = await axios.get(`http://router.project-osrm.org/route/v1/driving/${fromLng},${fromLat};${toLng},${toLat}?overview=full&geometries=geojson`);
              if (tripRes.data?.routes?.[0]) {
                tripPoints = tripRes.data.routes[0].geometry.coordinates.map((c: any) => [c[1], c[0]]);
              }
            } catch (_) {}

            if (tripPoints.length === 0) {
              for (let i = 0; i <= 6; i++) {
                const progress = i / 6;
                tripPoints.push([
                  fromLat + (toLat - fromLat) * progress,
                  fromLng + (toLng - fromLng) * progress,
                ]);
              }
            }

            let tripStep = 0;
            const totalTripSteps = Math.min(tripPoints.length, 8);
            const tripIndices = Array.from({ length: totalTripSteps }, (_, i) => 
              Math.floor(i * (tripPoints.length - 1) / (totalTripSteps - 1))
            );

            const tripIntervalId = setInterval(async () => {
              if (tripStep < totalTripSteps) {
                const pt = tripPoints[tripIndices[tripStep]];
                io.to(`client_${clientId}`).emit('driver_location_update', {
                  lat: pt[0],
                  lng: pt[1],
                  orderId,
                });
                tripStep++;
              } else {
                clearInterval(tripIntervalId);

                await prisma.order.update({
                  where: { id: orderId },
                  data: { status: 'COMPLETED' },
                });
                io.to(`client_${clientId}`).emit('order_status_update', {
                  orderId,
                  status: 'COMPLETED',
                });
              }
            }, 1500);
          }, 2000);
        }
      }, 1500);
    } catch (err) {
      console.error('Simulation fast error:', err);
    }
  }, 2000);
}

// GET /api/order/active/:userId — Foydalanuvchining faol buyurtmasi
router.get('/active/:userId', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { userId } = req.params;

  // Faqat o'zining faol buyurtmasini ko'rsin
  if (req.user!.id !== userId) {
    return res.status(403).json({ success: false, message: 'Ruxsat yo\'q' });
  }

  try {
    const order = await prisma.order.findFirst({
      where: {
        clientId: userId,
        status: { in: ['SEARCHING', 'FOUND', 'DRIVER_ARRIVING', 'DRIVER_ARRIVED', 'IN_TRIP'] },
      },
      include: {
        driver: {
          select: {
            id: true,
            fullName: true,
            phoneNumber: true,
            driverProfile: {
              select: { carModel: true, carNumber: true, carColor: true, rating: true, currentLat: true, currentLng: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!order) {
      return res.json({ success: true, order: null });
    }

    return res.json({
      success: true,
      order: {
        id: order.id,
        userId: order.clientId,
        fromAddress: order.fromAddress,
        toAddress: order.toAddress,
        fromLocation: { lat: order.fromLat, lng: order.fromLng },
        toLocation: { lat: order.toLat, lng: order.toLng },
        price: order.price,
        status: order.status,
        tariff: order.tariff,
        distanceKm: order.distanceKm,
        durationMin: order.durationMin,
        createdAt: order.createdAt,
        driver: order.driver ? {
          id: order.driver.id,
          fullName: order.driver.fullName || '',
          phoneNumber: order.driver.phoneNumber,
          carModel: order.driver.driverProfile?.carModel || '',
          carNumber: order.driver.driverProfile?.carNumber || '',
          carColor: order.driver.driverProfile?.carColor || '',
          rating: order.driver.driverProfile?.rating || 5.0,
          currentLocation: order.driver.driverProfile?.currentLat ? {
            lat: order.driver.driverProfile.currentLat,
            lng: order.driver.driverProfile.currentLng,
          } : null,
        } : null,
      },
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/', authenticateToken, async (req: AuthRequest, res: Response) => {
  let {
    fromLat, fromLng,
    toLat, toLng,
    fromLocation, toLocation,
    fromAddress, toAddress,
    tariff = 'standard',
    price,
    distanceKm,
    paymentMethod = 'CASH',
  } = req.body;

  if (fromLocation) {
    fromLat = fromLocation.lat;
    fromLng = fromLocation.lng;
  }
  if (toLocation) {
    toLat = toLocation.lat;
    toLng = toLocation.lng;
  }

  if (!fromLat || !fromLng || !toLat || !toLng || !price) {
    return res.status(400).json({ success: false, message: "Ma'lumotlar yetarli emas" });
  }

  if (paymentMethod === 'WALLET') {
    try {
      const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
      if (!user || user.walletBalance < Number(price)) {
        return res.status(400).json({ success: false, message: 'Balansingiz yetarli emas. Iltimos, hamyonni to\'ldiring yoki qadamlaringizni konvertatsiya qiling.' });
      }
    } catch (err) {
      return res.status(500).json({ success: false, message: 'Foydalanuvchi ma\'lumotlarini tekshirishda xatolik' });
    }
  }

  const stopLatVal = req.body.stopLocation?.lat;
  const stopLngVal = req.body.stopLocation?.lng;
  const stopAddressVal = req.body.stopAddress;

  try {
    let roadDistanceKm = distanceKm ? Number(distanceKm) : null;
    let roadDurationMin = null;

    try {
      const pointsStr = stopLatVal && stopLngVal
        ? `${fromLng},${fromLat};${stopLngVal},${stopLatVal};${toLng},${toLat}`
        : `${fromLng},${fromLat};${toLng},${toLat}`;

      const osrmRes = await axios.get(`http://router.project-osrm.org/route/v1/driving/${pointsStr}?overview=full&geometries=geojson`);
      if (osrmRes.data?.routes?.[0]) {
        const route = osrmRes.data.routes[0];
        roadDistanceKm = parseFloat((route.distance / 1000).toFixed(2));
        roadDurationMin = Math.round(route.duration / 60);
      }
    } catch (_) {}

    const order = await prisma.order.create({
      data: {
        clientId: req.user!.id,
        fromLat: Number(fromLat),
        fromLng: Number(fromLng),
        fromAddress: fromAddress || 'Noma\'lum',
        toLat: Number(toLat),
        toLng: Number(toLng),
        toAddress: toAddress || 'Noma\'lum',
        stopLat: stopLatVal ? Number(stopLatVal) : null,
        stopLng: stopLngVal ? Number(stopLngVal) : null,
        stopAddress: stopAddressVal || null,
        tariff,
        price: Number(price),
        distanceKm: roadDistanceKm,
        durationMin: roadDurationMin,
        status: 'SEARCHING',
        paymentMethod,
      },
    });

    const io = (global as any).io;
    if (io) {
      io.emit('new_order', {
        orderId: order.id,
        fromLat: order.fromLat,
        fromLng: order.fromLng,
        fromAddress: order.fromAddress,
        toAddress: order.toAddress,
        tariff: order.tariff,
        price: order.price,
        distanceKm: order.distanceKm,
      });
    }

    // Simulyatsiya faqat development muhitida ishlaydi
    if (process.env.NODE_ENV === 'development') {
      simulateTrip(order.id, req.user!.id, Number(fromLat), Number(fromLng), Number(toLat), Number(toLng));
    }

    return res.status(201).json({ success: true, order });
  } catch (err) {
    console.error('Order yaratishda xatolik:', err);
    return res.status(500).json({ success: false, message: 'Buyurtma yaratilmadi' });
  }
});

// POST /api/order/simulate-public — Jamoat/Web simulyatori uchun maxsus buyurtma
router.post('/simulate-public', async (req: Request, res: Response) => {
  const {
    fromAddress, toAddress,
    fromLat, fromLng,
    toLat, toLng,
    tariff
  } = req.body;

  if (!fromLat || !fromLng || !toLat || !toLng) {
    return res.status(400).json({ success: false, message: 'Koordinatalar yetarli emas' });
  }

  try {
    let client = await prisma.user.findFirst({
      where: { role: 'CLIENT', username: 'web_demo_client' }
    });

    if (!client) {
      client = await prisma.user.create({
        data: {
          username: 'web_demo_client',
          fullName: 'Veb Simulyator',
          phoneNumber: '+998900000000',
          password: 'dummy_hash',
          role: 'CLIENT',
          orbitaId: 'ORB-111111'
        }
      });
    }

    // Dynamic pricing helper
    const getTaxiPricing = () => {
      try {
        const filePath = path.join(__dirname, '../settings.json');
        if (fs.existsSync(filePath)) {
          const data = fs.readFileSync(filePath, 'utf8');
          const settings = JSON.parse(data);
          if (settings.taxiPricing) return settings.taxiPricing;
        }
      } catch (err) {
        console.error('Failed to read settings for pricing, using defaults');
      }
      return {
        startBase: 5000,
        startKm: 1200,
        komfortBase: 8000,
        komfortKm: 1600,
        biznesBase: 12000,
        biznesKm: 2200
      };
    };

    const pricing = getTaxiPricing();
    const cleanTariff = (tariff || 'START').toUpperCase();
    
    let basePrice = 5000;
    let perKmPrice = 1200;
    
    if (cleanTariff === 'START') {
      basePrice = pricing.startBase || 5000;
      perKmPrice = pricing.startKm || 1200;
    } else if (cleanTariff === 'KOMFORT') {
      basePrice = pricing.komfortBase || 8000;
      perKmPrice = pricing.komfortKm || 1600;
    } else if (cleanTariff === 'BIZNES') {
      basePrice = pricing.biznesBase || 12000;
      perKmPrice = pricing.biznesKm || 2200;
    }

    const distance = 3.5; // simulated distance
    const price = basePrice + Math.round(distance * perKmPrice);

    const order = await prisma.order.create({
      data: {
        clientId: client.id,
        fromAddress: fromAddress || 'Qidirilgan manzil (Pickup)',
        toAddress: toAddress || 'Manzil (Destination)',
        fromLat: Number(fromLat),
        fromLng: Number(fromLng),
        toLat: Number(toLat),
        toLng: Number(toLng),
        status: 'SEARCHING',
        tariff: cleanTariff,
        price,
        distanceKm: distance,
        durationMin: 10,
        paymentMethod: 'CASH'
      }
    });

    simulateTripFast(order.id, client.id, Number(fromLat), Number(fromLng), Number(toLat), Number(toLng));

    return res.json({
      success: true,
      message: 'Simulyatsiya buyurtmasi yaratildi',
      orderId: order.id,
      clientId: client.id
    });
  } catch (err: any) {
    console.error('Simulate-public order error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/order/user/:userId — Foydalanuvchi buyurtmalari
router.get('/user/:userId', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { userId } = req.params;

  // Faqat o'zining buyurtmalarini ko'rsin
  if (req.user!.id !== userId) {
    return res.status(403).json({ success: false, message: 'Ruxsat yo\'q' });
  }

  const orders = await prisma.order.findMany({
    where: { clientId: userId },
    include: {
      driver: {
        select: {
          id: true,
          fullName: true,
          phoneNumber: true,
          driverProfile: {
            select: { carModel: true, carNumber: true, carColor: true, rating: true },
          },
        },
      },
    },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  const formatted = orders.map(o => ({
    id: o.id,
    userId: o.clientId,
    fromAddress: o.fromAddress,
    toAddress: o.toAddress,
    fromLocation: { lat: o.fromLat, lng: o.fromLng },
    toLocation: { lat: o.toLat, lng: o.toLng },
    price: o.price,
    status: o.status,
    tariff: o.tariff,
    distanceKm: o.distanceKm,
    createdAt: o.createdAt,
    driver: o.driver ? {
      id: o.driver.id,
      fullName: o.driver.fullName || '',
      phoneNumber: o.driver.phoneNumber,
      carModel: o.driver.driverProfile?.carModel || '',
      carNumber: o.driver.driverProfile?.carNumber || '',
      carColor: o.driver.driverProfile?.carColor || '',
      rating: o.driver.driverProfile?.rating || 5.0,
    } : null,
  }));

  return res.json({ success: true, orders: formatted });
});

// GET /api/order/available — Faol buyurtmalar (Haydovchilar uchun)
router.get('/available', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const orders = await prisma.order.findMany({
      where: { status: 'SEARCHING' },
      include: {
        client: {
          select: { fullName: true, phoneNumber: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    const formatted = orders.map(o => ({
      id: o.id,
      userId: o.clientId,
      clientName: o.client.fullName || 'Mijoz',
      clientPhone: o.client.phoneNumber,
      fromAddress: o.fromAddress,
      toAddress: o.toAddress,
      fromLocation: { lat: o.fromLat, lng: o.fromLng },
      toLocation: { lat: o.toLat, lng: o.toLng },
      price: o.price,
      status: o.status,
      tariff: o.tariff,
      distanceKm: o.distanceKm,
      createdAt: o.createdAt,
    }));

    return res.json({ success: true, orders: formatted });
  } catch (err: any) {
    console.error('Error fetching available orders:', err.message);
    return res.status(500).json({ success: false, message: 'Xatolik yuz berdi' });
  }
});

// GET /api/order/:id — Bitta buyurtma
router.get('/:id', authenticateToken, async (req: AuthRequest, res: Response) => {
  const order = await prisma.order.findUnique({
    where: { id: req.params.id },
    include: {
      driver: {
        select: {
          id: true,
          fullName: true,
          phoneNumber: true,
          driverProfile: {
            select: { carModel: true, carNumber: true, carColor: true, rating: true, currentLat: true, currentLng: true },
          },
        },
      },
    },
  });

  if (!order) {
    return res.status(404).json({ success: false, message: 'Buyurtma topilmadi' });
  }
  if (order.clientId !== req.user!.id && order.driverId !== req.user!.id) {
    return res.status(403).json({ success: false, message: 'Ruxsat yo\'q' });
  }

  let routeGeometry: number[][] = [];
  try {
    const pointsStr = order.stopLat && order.stopLng
      ? `${order.fromLng},${order.fromLat};${order.stopLng},${order.stopLat};${order.toLng},${order.toLat}`
      : `${order.fromLng},${order.fromLat};${order.toLng},${order.toLat}`;

    const osrmRes = await axios.get(`http://router.project-osrm.org/route/v1/driving/${pointsStr}?overview=full&geometries=geojson`);
    if (osrmRes.data?.routes?.[0]) {
      routeGeometry = osrmRes.data.routes[0].geometry.coordinates.map((c: any) => [c[1], c[0]]);
    }
  } catch (err: any) {
    console.error('Error fetching OSRM route for order:', err.message);
  }

  // Fallback if OSRM fails
  if (routeGeometry.length === 0) {
    routeGeometry = [
      [order.fromLat, order.fromLng],
      [order.toLat, order.toLng],
    ];
  }

  return res.json({
    success: true,
    order: {
      id: order.id,
      userId: order.clientId,
      fromAddress: order.fromAddress,
      toAddress: order.toAddress,
      fromLocation: { lat: order.fromLat, lng: order.fromLng },
      toLocation: { lat: order.toLat, lng: order.toLng },
      price: order.price,
      status: order.status,
      tariff: order.tariff,
      distanceKm: order.distanceKm,
      durationMin: order.durationMin,
      createdAt: order.createdAt,
      driver: order.driver ? {
        id: order.driver.id,
        fullName: order.driver.fullName || '',
        phoneNumber: order.driver.phoneNumber,
        carModel: order.driver.driverProfile?.carModel || '',
        carNumber: order.driver.driverProfile?.carNumber || '',
        carColor: order.driver.driverProfile?.carColor || '',
        rating: order.driver.driverProfile?.rating || 5.0,
        currentLocation: order.driver.driverProfile?.currentLat ? {
          lat: order.driver.driverProfile.currentLat,
          lng: order.driver.driverProfile.currentLng,
        } : null,
      } : null,
    },
    routeGeometry,
  });
});

// PATCH /api/order/:id/cancel — Bekor qilish
router.patch('/:id/cancel', authenticateToken, async (req: AuthRequest, res: Response) => {
  const order = await prisma.order.findUnique({ where: { id: req.params.id } });
  if (!order) return res.status(404).json({ success: false, message: 'Topilmadi' });
  if (order.clientId !== req.user!.id) return res.status(403).json({ success: false, message: 'Ruxsat yo\'q' });
  if (!['SEARCHING', 'FOUND'].includes(order.status)) {
    return res.status(400).json({ success: false, message: 'Bu bosqichda bekor qilib bo\'lmaydi' });
  }

  const updated = await prisma.order.update({
    where: { id: req.params.id },
    data: { status: 'CANCELLED' },
  });

  const io = (global as any).io;
  if (io) {
    io.emit('order_cancelled', { orderId: order.id });
  }

  return res.json({ success: true, order: updated });
});

// PATCH /api/order/:id/rate — Baholash
router.patch('/:id/rate', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { rating } = req.body;
  const order = await prisma.order.findUnique({ where: { id: req.params.id } });
  if (!order || order.status !== 'COMPLETED') {
    return res.status(400).json({ success: false, message: 'Faqat yakunlangan buyurtmani baholash mumkin' });
  }

  await prisma.order.update({
    where: { id: req.params.id },
    data: { clientRating: Number(rating) },
  });

  return res.json({ success: true });
});

// GET /api/order/:id/messages — Chat xabarlari
router.get('/:id/messages', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const messages = await prisma.message.findMany({
      where: { orderId: req.params.id },
      orderBy: { createdAt: 'asc' }
    });
    return res.json({ success: true, messages });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: 'Xabarlarni yuklashda xatolik' });
  }
});

// PATCH /api/order/:id/accept — Haydovchi buyurtmani qabul qilishi (atomic)
router.patch('/:id/accept', authenticateToken, async (req: AuthRequest, res: Response) => {
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

    // Atomik: race condition oldini olish
    const updated = await prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({ where: { id: req.params.id } });
      if (!order || order.status !== 'SEARCHING') {
        throw new Error('ORDER_NOT_AVAILABLE');
      }
      return tx.order.update({
        where: { id: req.params.id },
        data: { driverId: req.user!.id, status: 'DRIVER_ARRIVING' },
        include: { driver: { include: { driverProfile: true } } }
      });
    });

    const io = (global as any).io;
    if (io && updated.driver) {
      io.to(`client_${updated.clientId}`).emit('order_status_update', {
        orderId: updated.id,
        status: 'DRIVER_ARRIVING',
        driver: {
          id: updated.driver.id,
          fullName: updated.driver.fullName || 'Haydovchi',
          phoneNumber: updated.driver.phoneNumber,
          carModel: updated.driver.driverProfile?.carModel || 'Chevrolet Nexia 3',
          carNumber: updated.driver.driverProfile?.carNumber || '01 A 777 AA',
          carColor: updated.driver.driverProfile?.carColor || 'Oq',
          rating: updated.driver.driverProfile?.rating || 5.0,
        }
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

// PATCH /api/order/:id/status — Haydovchi buyurtma statusini o'zgartirishi
router.patch('/:id/status', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { status } = req.body;
  if (!['DRIVER_ARRIVED', 'IN_TRIP', 'COMPLETED'].includes(status)) {
    return res.status(400).json({ success: false, message: 'Noto\'g\'ri status' });
  }

  try {
    const order = await prisma.order.findUnique({ where: { id: req.params.id } });
    if (!order || order.driverId !== req.user!.id) {
      return res.status(403).json({ success: false, message: 'Ruxsat yo\'q' });
    }

    let updateData: any = { status };
    let finalPrice = order.price;

    if (status === 'DRIVER_ARRIVED') {
      updateData.arrivedAt = new Date();
    } else if (status === 'IN_TRIP') {
      if (order.arrivedAt) {
        const elapsedMs = new Date().getTime() - new Date(order.arrivedAt).getTime();
        const elapsedSec = Math.floor(elapsedMs / 1000);
        if (elapsedSec > 15) { // 15 seconds waiting limit
          const waitingTimeForFee = elapsedSec - 15;
          const waitFee = Math.floor(waitingTimeForFee / 10) * 1000; // 1000 so'm per 10s
          if (waitFee > 0) {
            finalPrice = order.price + waitFee;
            updateData.price = finalPrice;
            console.log(`⏱️ Pullik kutish: ${elapsedSec}s kutilganligi sababli yo'lkiraga ${waitFee} so'm qo'shildi.`);
          }
        }
      }
    } else if (status === 'COMPLETED') {
      // Deduct 10% commission
      const commission = finalPrice * 0.1;
      await prisma.$transaction(async (tx) => {
        if (order.paymentMethod === 'WALLET') {
          // 1. Mijoz balansidan butun safar narxi yechiladi
          await tx.user.update({
            where: { id: order.clientId },
            data: {
              walletBalance: { decrement: finalPrice },
              transactions: {
                create: {
                  title: "Safar to'lovi (Hamyon)",
                  subtitle: `Yo'nalish: ${order.fromAddress.split(',')[0]} -> ${order.toAddress.split(',')[0]}`,
                  amount: finalPrice,
                  isCredit: false,
                  type: "TRIP_SPENDING"
                }
              }
            }
          });

          // 2. Haydovchi balansiga (safar narxi - komissiya) qo'shiladi
          const driverNetEarnings = finalPrice - commission;
          await tx.user.update({
            where: { id: order.driverId! },
            data: {
              walletBalance: { increment: driverNetEarnings },
              transactions: {
                create: [
                  {
                    title: "Safar daromadi (Hamyon)",
                    subtitle: `Yo'nalish: ${order.fromAddress.split(',')[0]} -> ${order.toAddress.split(',')[0]}`,
                    amount: finalPrice,
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
          console.log(`💰 Hamyon orqali to'lov: ${finalPrice} so'm mijozdan olindi va ${driverNetEarnings} so'm (komissiya ayrilgan holda) haydovchiga o'tkazildi.`);
        } else {
          // CASH to'lov
          // 1. Mijoz balansi o'zgarmaydi.
          // 2. Haydovchidan 10% komissiya yechiladi
          await tx.user.update({
            where: { id: order.driverId! },
            data: {
              walletBalance: { decrement: commission },
              transactions: {
                create: [
                  {
                    title: "Safar daromadi (Naqd)",
                    subtitle: `Yo'nalish: ${order.fromAddress.split(',')[0]} -> ${order.toAddress.split(',')[0]}`,
                    amount: finalPrice,
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
          console.log(`💵 Naqd pul orqali to'lov: ${finalPrice} so'm naqd. Haydovchidan ${commission} so'm komissiya yechib olindi.`);
        }

        // Haydovchi profildagi safarlar sonini oshirish
        await tx.driverProfile.update({
          where: { userId: order.driverId! },
          data: {
            totalTrips: { increment: 1 }
          }
        });
      });
    }

    const updated = await prisma.order.update({
      where: { id: req.params.id },
      data: updateData
    });

    const io = (global as any).io;
    if (io) {
      const payload = {
        orderId: order.id,
        status,
        price: finalPrice
      };
      // Client ilovasiga
      io.to(`client_${order.clientId}`).emit('order_status_update', payload);
      // Driver ilovasiga ham (driver ekranida ham yangilansin)
      if (order.driverId) {
        io.to(`driver_${order.driverId}`).emit('order_status_update', payload);
      }
      console.log(`📡 Status emitted [${status}] → client_${order.clientId} + driver_${order.driverId}`);
    }

    // Referral milestone: 2 ta tayyor safar bo'lsa referral bonus tekshirilsin
    if (status === 'COMPLETED') {
      checkReferralByTrips(order.clientId).catch(console.error);
      updateRideQuests(order.clientId).catch(console.error);
    }

    return res.json({ success: true, order: updated });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/order/favorites — Sevimli manzillar ro'yxatini olish
router.get('/favorites', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const favorites = await prisma.favoriteAddress.findMany({
      where: { userId: req.user!.id },
      orderBy: { createdAt: 'desc' }
    });
    return res.json({ success: true, favorites });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/order/favorites — Yangi sevimli manzil qo'shish
router.post('/favorites', authenticateToken, async (req: AuthRequest, res: Response) => {
  const { label, address, lat, lng, iconType } = req.body;
  if (!label || !address || lat === undefined || lng === undefined) {
    return res.status(400).json({ success: false, message: 'Barcha ma\'lumotlar (label, address, lat, lng) to\'ldirilishi shart' });
  }

  try {
    const favorite = await prisma.favoriteAddress.create({
      data: {
        userId: req.user!.id,
        label,
        address,
        lat: Number(lat),
        lng: Number(lng),
        iconType: iconType || 'HOME'
      }
    });
    return res.json({ success: true, favorite });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/order/favorites/:id — Sevimli manzilni o'chirish
router.delete('/favorites/:id', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const favorite = await prisma.favoriteAddress.findUnique({
      where: { id: req.params.id }
    });

    if (!favorite) {
      return res.status(404).json({ success: false, message: 'Manzil topilmadi' });
    }

    if (favorite.userId !== req.user!.id) {
      return res.status(403).json({ success: false, message: 'Ruxsat berilmagan' });
    }

    await prisma.favoriteAddress.delete({
      where: { id: req.params.id }
    });

    return res.json({ success: true, message: 'Manzil o\'chirildi' });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/order/quests — Safar vazifalari va foydalanuvchi progressi
router.get('/quests', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const quests = await prisma.rideQuest.findMany({ where: { isActive: true } });
    const userQuests = await prisma.userRideQuest.findMany({
      where: { userId: req.user!.id }
    });

    const result = quests.map(q => {
      const uq = userQuests.find(u => u.questId === q.id);
      return {
        id: q.id,
        title: q.title,
        description: q.description,
        targetCount: q.targetCount,
        rewardPrice: q.rewardPrice,
        currentCount: uq ? uq.currentCount : 0,
        isCompleted: uq ? uq.isCompleted : false,
        isClaimed: uq ? uq.isClaimed : false,
      };
    });

    return res.json({ success: true, quests: result });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

export default router;

