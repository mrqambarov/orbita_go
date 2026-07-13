import prisma from './lib/prisma';

const items = [
  {
    tag: 'feature', tagLabel: 'Yangi Xususiyat', icon: 'footsteps-outline', iconColor: 'default',
    title: "Orbita Walk 2.0 — Yangi qadam musobaqa tizimi!",
    description: "Endi kunlik va haftalik qadam musobaqalarida do'stlaringiz bilan bellashing. Eng ko'p qadam bosgan 3 nafar foydalanuvchi har kuni real pul mukofot oladi.",
    isFeatured: true, publishedAt: new Date('2026-07-08'),
  },
  {
    tag: 'update', tagLabel: 'Yangilanish', icon: 'car-sport-outline', iconColor: 'yellow',
    title: "Taksi ilovasi yangilandi — v3.2 chiqdi",
    description: "Haydovchilar uchun yangi daromad hisoblagichi, mijozlar uchun esa tezkor buyurtma qayta berish va turnov bonuslari qo'shildi.",
    isFeatured: false, publishedAt: new Date('2026-07-05'),
  },
  {
    tag: 'promo', tagLabel: 'Aksiya', icon: 'pricetag-outline', iconColor: 'green',
    title: "Yoz aksiyasi: 30% chegirma taksi tariflariga!",
    description: "Iyul oyida barcha Start va Komfort tariflarida 30% chegirma. Orbita Go ilovasini hoziroq yuklab oling va chegirmadan foydalaning!",
    isFeatured: false, publishedAt: new Date('2026-07-01'),
  },
  {
    tag: 'event', tagLabel: 'Tadbir', icon: 'cafe-outline', iconColor: 'red',
    title: "Orbita Cafe — Qadamlarni qahva va desertlarga almashtiring!",
    description: "Yaqinda Kosonsoy va Namangan shaharlarida hamkor kafelarimiz ishga tushadi. Yig'ilgan ballaringizni tekin taomlarga almashtirishingiz mumkin.",
    isFeatured: false, publishedAt: new Date('2026-07-12'),
  },
  {
    tag: 'update', tagLabel: 'Yangilanish', icon: 'shield-checkmark-outline', iconColor: 'cyan',
    title: "Xavfsiz haydash kafolati va haydovchilar reytingi",
    description: "Biz mijozlarimiz xavfsizligini 1-o'ringa qo'yamiz. Har bir safar GPS orqali nazorat qilinadi va favqulodda vaziyat SOS tugmasi qo'shildi.",
    isFeatured: false, publishedAt: new Date('2026-07-10'),
  },
];

async function main() {
  const existing = await prisma.newsPost.count();
  if (existing > 0) {
    console.log(`NewsPost jadvalida ${existing} ta yozuv bor — seed o'tkazib yuborildi.`);
    return;
  }
  for (const item of items) {
    await prisma.newsPost.create({ data: item });
  }
  console.log(`${items.length} ta yangilik qo'shildi.`);
}

main().finally(() => prisma.$disconnect());
