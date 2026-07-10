// Orbita Go Telegram Client-Side Gateway & Fallback
window.sendTelegramNotification = async function(type, data) {
    const API_BASE = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' ? 'http://localhost:3000' : '';
    
    // 1. Try to send via backend server first (secure)
    try {
        const response = await fetch(API_BASE + '/api/telegram/notify', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type, data })
        });
        if (response.ok) {
            const resData = await response.json();
            return { success: true, mode: 'backend', data: resData };
        }
    } catch (e) {
        console.warn("Backend server is not reachable. Falling back to direct client-side Telegram API...");
    }

    // 2. Fallback to direct client-side call using public Telegram API
    const token = "8720940640:AAFDCpDHgY9p8Nmyk8dLiVqm7_NV90xV_RU";
    const chatId = "-5265526977";
    
    let text = '';
    const nowStr = new Date().toLocaleString('uz-UZ');

    if (type === 'order') {
        text = `🚖 <b>─── ORBITA GO TAKSI ───</b> 🚖\n` +
               `✨ <i>Yangi safar buyurtmasi (Simulyator - Client Fallback)</i>\n\n` +
               `📍 <b>Qayerdan:</b>\n` +
               `┗ <code>${data.pickup}</code>\n\n` +
               `🏁 <b>Qayerga:</b>\n` +
               `┗ <code>${data.dest}</code>\n\n` +
               `📏 <b>Masofa:</b> <code>${data.distance}</code>\n` +
               `⏱ <b>Safar vaqti:</b> <code>${data.duration}</code>\n` +
               `🏷 <b>Tarif:</b> <code>${data.tariff}</code>\n` +
               `💵 <b>Jami to'lov:</b> <code>${data.price}</code>\n\n` +
               `👤 <b>Haydovchi:</b> <code>${data.driverName || 'Noma\'lum'}</code>\n` +
               `🚗 <b>Avtomobil:</b> <code>${data.driverCar || 'Noma\'lum'}</code>\n\n` +
               `🟢 <b>Navbatchi operatorlar:</b> <code>FAOL (Sardor M., Madina A.)</code>\n` +
               `📅 <b>Sana/Vaqt:</b> <i>${nowStr}</i>\n` +
               `───────────────────`;
    } else if (type === 'partner') {
        text = `🤝 <b>─── HAMKORLIK ARIZASI ───</b> 🤝\n` +
               `✨ <i>Yangi arizachi ma'lumotlari (Client Fallback)</i>\n\n` +
               `👤 <b>Ism:</b> <code>${data.name}</code>\n` +
               `📞 <b>Telefon:</b> <code>${data.phone}</code>\n` +
               `🏢 <b>Kompaniya/Faoliyat:</b> <code>${data.business}</code>\n\n` +
               `🟢 <b>Navbatchi operatorlar:</b> <code>FAOL (Sardor M., Madina A.)</code>\n` +
               `📅 <b>Sana/Vaqt:</b> <i>${nowStr}</i>\n` +
               `───────────────────`;
    } else if (type === 'subscribe') {
        text = `📧 <b>─── YANGI OBUNACHI ───</b> 📧\n` +
               `✨ <i>Newsletter xabarnomasi (Client Fallback)</i>\n\n` +
               `📪 <b>Email:</b> <code>${data.email}</code>\n` +
               `📌 <b>Obuna bo'limi:</b> <code>${data.section.toUpperCase()}</code>\n\n` +
               `🟢 <b>Navbatchi operatorlar:</b> <code>FAOL (Sardor M., Madina A.)</code>\n` +
               `📅 <b>Sana/Vaqt:</b> <i>${nowStr}</i>\n` +
               `───────────────────`;
    } else if (type === 'donate') {
        text = `❤️ <b>─── DONAT BOSILISHI ───</b> ❤️\n` +
               `✨ <i>Xayriya qilish istagi (Client Fallback)</i>\n\n` +
               `💰 <b>Tanlangan tizim:</b> <code>${data.method}</code>\n` +
               `💳 <b>Karta egasi:</b> <code>A.Qambarov</code>\n` +
               `💬 <b>Izoh:</b> <code>${data.comment || 'Izohsiz'}</code>\n\n` +
               `🟢 <b>Navbatchi operatorlar:</b> <code>FAOL (Sardor M., Madina A.)</code>\n` +
               `📅 <b>Sana/Vaqt:</b> <i>${nowStr}</i>\n` +
               `───────────────────`;
    }

    try {
        const directRes = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                chat_id: chatId,
                text: text,
                parse_mode: 'HTML'
            })
        });
        const directJson = await directRes.json();
        return { success: true, mode: 'client', data: directJson };
    } catch (err) {
        console.error("Direct Telegram send failed:", err);
        return { success: false, error: err.message };
    }
};
