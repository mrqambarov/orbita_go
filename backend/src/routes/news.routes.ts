import { Router, Request, Response } from 'express';
import prisma from '../lib/prisma';

const router = Router();

/* ============================================================
   GET /api/news — Public: e'lon qilingan yangiliklar ro'yxati
   ============================================================ */
router.get('/', async (_req: Request, res: Response) => {
  try {
    const news = await prisma.newsPost.findMany({
      where: { isPublished: true },
      orderBy: [{ isFeatured: 'desc' }, { publishedAt: 'desc' }],
      take: 12,
    });
    res.json({ success: true, news });
  } catch (err: any) {
    res.status(500).json({ success: false, message: err.message });
  }
});

export default router;
