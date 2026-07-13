// Orbita Go Telegram Client-Side Gateway
window.sendTelegramNotification = async function(type, data) {
    const API_BASE = (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') ? 'http://localhost:3000' : 'https://api.orbitago.uz';

    // Bildirishnoma faqat backend orqali yuboriladi — bot tokeni hech qachon
    // brauzer kodida saqlanmaydi (oldingi versiyada shu yerda hardcode token bor edi).
    try {
        const response = await fetch(API_BASE + '/api/telegram/notify', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type, data })
        });
        const resData = await response.json();
        return { success: response.ok, mode: 'backend', data: resData };
    } catch (e) {
        console.warn("Telegram bildirishnomasi yuborilmadi: backend server ishlamayapti.", e);
        return { success: false, error: 'backend_unreachable' };
    }
};
