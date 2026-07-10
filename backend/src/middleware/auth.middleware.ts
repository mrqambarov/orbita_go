import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET;

// Production'da JWT_SECRET bo'sh bo'lsa server ishlamaydi
if (!JWT_SECRET) {
  throw new Error('❌ FATAL: JWT_SECRET environment variable ko\'yilmagan! Server ishga tushirilmadi.');
}

export interface AuthRequest extends Request {
  user?: { id: string; phoneNumber: string; role: string };
}

export function generateToken(user: { id: string; phoneNumber: string; role: string }): string {
  return jwt.sign(user, JWT_SECRET!, { expiresIn: '3d' });
}

export function authenticateToken(req: AuthRequest, res: Response, next: NextFunction) {
  const authHeader = req.headers['authorization'];
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, message: 'Token kerak' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET!) as any;
    req.user = { id: decoded.id, phoneNumber: decoded.phoneNumber, role: decoded.role };
    next();
  } catch (err: any) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token muddati tugagan', code: 'TOKEN_EXPIRED' });
    }
    return res.status(403).json({ success: false, message: 'Token yaroqsiz' });
  }
}
