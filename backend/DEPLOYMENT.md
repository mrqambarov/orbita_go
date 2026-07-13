# 🚀 Orbita Go — Backend Server Deployment & Database Migration Guide

Ushbu qo'llanma **Orbita Go** backend tizimini hamda **PostgreSQL** ma'lumotlar bazasini ishlab chiqarish (Production) serveriga oson va xavfsiz ko'chirish, sozlash va 24/7 ishga tushirish qadamlarini tushuntiradi.

---

## 1. 🗄 Ma'lumotlar Bazasini Sozlash (PostgreSQL)

Orbita Go Prisma ORM orqali ishlaydi, shuning uchun istalgan PostgreSQL xizmatidan (Supabase, Neon, AWS RDS yoki shaxsiy Ubuntu VPS) foydalanish mumkin.

### A. Bulutli Bazadan foydalanish (Tavsiya etiladi - Supabase yoki Neon.tech)
1. [Supabase](https://supabase.com) yoki [Neon](https://neon.tech) saytida ro'yxatdan o'ting va yangi loyiha (Database) yarating.
2. Connection String (Ulanish havolasi)ni oling. U quyidagicha ko'rinishda bo'ladi:
   ```env
   DATABASE_URL="postgresql://postgres.youruser:yourpassword@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?pgbouncer=true"
   ```
   *(Eslatma: Tranzaktsiyalar ko'p bo'lishi uchun Supabase da `pooler` portidan (6543) va `pgbouncer=true` dan foydalanish tavsiya etiladi)*

### B. Shaxsiy VPS-ga PostgreSQL o'rnatish
Agar bazani ham shaxsiy VPS serverga o'rnatmoqchi bo'lsangiz (Ubuntu):
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib -y
# Postgres konsoliga kirish
sudo -i -u postgres psql
# Yangi ma'lumotlar bazasi va foydalanuvchi yaratish
CREATE DATABASE orbita_go;
CREATE USER orbita_user WITH PASSWORD 'strong_password_here';
GRANT ALL PRIVILEGES ON DATABASE orbita_go TO orbita_user;
\q
```
Ulanish havolasi (`DATABASE_URL`):
```env
DATABASE_URL="postgresql://orbita_user:strong_password_here@localhost:5432/orbita_go?schema=public"
```

---

## 2. 📁 Serverda Muhit Faylini (.env) Sozlash

Serverda loyiha papkasiga kirib, `.env` faylini yarating va quyidagi professional sozlamalarni o'rnating:

```env
PORT=3000
NODE_ENV=production

# ─── XAVFSIZLIK ───
# Kuchli random kalit yarating (Masalan terminalda: openssl rand -hex 32)
JWT_SECRET="af25c6b...your_strong_secret...6a12b"
# Admin panel JWT tokenlarini imzolash uchun kalit (openssl rand -hex 32)
ADMIN_SECRET="c91e4a...another_strong_random_secret...8f03d"

# ─── DATABASE ───
DATABASE_URL="postgresql://orbita_user:strong_password_here@localhost:5432/orbita_go?schema=public"

# ─── TELEGRAM INTEGRATSIYA ───
TELEGRAM_BOT_TOKEN="123456789:your_real_bot_token_here"
TELEGRAM_CHAT_ID="-1000000000"

# ─── EMAIL WEBHOOK ───
# cPanel/mail_pipe.php dan kelayotgan so'rovlarni tasdiqlash uchun tasodifiy token
EMAIL_WEBHOOK_SECRET="af25c6b...openssl_rand_hex_32_bilan_generatsiya_qiling...6a12b"
```

---

## 3. 🔄 Bazani Migratsiya Qilish (Database Push)

Loyiha bazasi jadvallarini yangi serverdagi bo'sh PostgreSQL-ga o'tkazish juda oson. Kod yozish yoki SQL import qilish shart emas.

Serverda loyihaning `backend/` papkasida turib, quyidagi buyruqni bering:
```bash
# 1. Bog'liqliklarni o'rnating
npm install

# 2. Prisma jadvallarini bazada yaratish (Auto schema generator)
npx prisma db push
```

*Tushuntirish:* `npx prisma db push` Prisma modelidagi barcha jadvallarni (User, Order, DriverProfile, va h.k.) PostgreSQL bazangizda avtomatik ravishda xatolarsiz yaratib beradi.

---

## 4. 🚀 Tizimni 24/7 Ishga Tushirish (PM2)

Node.js serverini orqa fonda doimiy ishlashi va server o'chib-yonganida avtomatik qayta ishga tushishi uchun **PM2** dasturidan foydalanamiz.

```bash
# PM2 dasturini global o'rnatish
sudo npm install pm2 -g

# Loyihani build qilish (TypeScript -> Production JavaScript)
npm run build

# PM2 yordamida backendni ishga tushirish
pm2 start dist/index.js --name "orbita-backend"

# Server o'chib yonganda avtomatik yonishi uchun
pm2 startup
pm2 save
```

### PM2 Boshqaruv Buyruqlari:
* `pm2 status` — Serverlar holatini ko'rish.
* `pm2 logs` — Real-time loglarni (xatoliklarni) kuzatish.
* `pm2 restart orbita-backend` — Serverni qayta ishga tushirish.

---

## 5. 🛡 Nginx orqali SSL (HTTPS) Sozlash

API xavfsiz (HTTPS) ishlashi va mobil ilovalardan ulanish uchun Nginx va Certbot o'rnatamiz (Domain: `api.orbitago.uz`).

### A. Nginx Sozlamasi:
`/etc/nginx/sites-available/default` fayliga quyidagi proxy blockni qo'shing:
```nginx
server {
    server_name api.orbitago.uz;

    location / {
        proxy_pass http://localhost:3000; # Bizning Express PORT
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```
Nginx-ni yangilang:
```bash
sudo nginx -t
sudo systemctl restart nginx
```

### B. SSL Sertifikati olish (Certbot):
```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d api.orbitago.uz
```
Bu buyruq bepul va avtomatik yangilanadigan SSL (HTTPS) sertifikatini o'rnatib beradi.

---

## 6. 🌐 Frontend (Veb-sayt) API Manzilini Sozlash

Veb-saytingiz haqiqiy HTTPS serverga so'rov yuborishi uchun `website/app.js` ning eng yuqori qismidagi `API_BASE` o'zgaruvchisi quyidagicha dinamik qilib qo'yildi:
```javascript
const API_BASE = (location.hostname === 'localhost' || location.hostname === '127.0.0.1')
    ? 'http://localhost:3000'
    : 'https://api.orbitago.uz'; // Sizning ishlab chiqarishdagi API manzilingiz
```
Bu loyihani VPS serverga ulashni juda oson va muammosiz qiladi!
