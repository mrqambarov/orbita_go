import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Current language code provider ('uz' | 'ru' | 'en')
class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('uz');

  void setLanguage(String code) {
    if (['uz', 'ru', 'en'].contains(code)) {
      state = code;
    }
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

// Translation helper extension
extension TranslateExtension on BuildContext {
  String tr(String key) {
    final locale = ProviderScope.containerOf(this).read(languageProvider);
    final localeDict = translations[locale] ?? translations['uz']!;
    return localeDict[key] ?? key;
  }
}

const Map<String, Map<String, String>> translations = {
  'uz': {
    'home': 'Bosh sahifa',
    'walk': 'Yurish',
    'history': 'Tarix',
    'profile': 'Profil',
    'today_steps': 'Bugungi qadamlar',
    'step_goal': 'Qadam maqsad',
    'distance': 'Masofa',
    'calories': 'Kaloriya',
    'duration': 'Vaqt',
    'convert_title': 'Qadamlarni pulga almashtirish',
    'convert_button': 'Hamyonga o\'tkazish',
    'start_walk': 'Yurishni boshlash',
    'stop_walk': 'Sayohatni yakunlash',
    'simulate_steps': 'Qadam simulyatsiyasi',
    'orbita_id': 'Orbita ID',
    'password': 'Parol',
    'login': 'Kirish',
    'logout': 'Chiqish',
    'loading': 'Yuklanmoqda...',
    'active_session': 'Yurish sessiyasi faol',
    'session_saved': 'Sayohat muvaffaqiyatli saqlandi!',
    'redeem_success': 'Mablag\' hamyoningizga muvaffaqiyatli o\'tkazildi!',
    'redeem_failed': 'O\'tkazishda xatolik yuz berdi',
    'wallet_balance': 'Hamyon balansi',
    'fullname': 'Ism-familiya',
    'username': 'Username',
    'language': 'Til',
    'no_walks': 'Yurishlar tarixi bo\'sh',
    'stats_title': 'Sizning qadamlaringiz',
    'about_app': 'Ilova haqida',
    'help': 'Yordam',
    'wallet_history': 'Tranzaksiyalar',
  },
  'ru': {
    'home': 'Главная',
    'walk': 'Ходьба',
    'history': 'История',
    'profile': 'Профиль',
    'today_steps': 'Шаги за сегодня',
    'step_goal': 'Цель шагов',
    'distance': 'Дистанция',
    'calories': 'Калории',
    'duration': 'Время',
    'convert_title': 'Обмен шагов на деньги',
    'convert_button': 'Перевести на кошелек',
    'start_walk': 'Начать ходьбу',
    'stop_walk': 'Завершить прогулку',
    'simulate_steps': 'Симуляция шагов',
    'orbita_id': 'Orbita ID',
    'password': 'Пароль',
    'login': 'Войти',
    'logout': 'Выйти',
    'loading': 'Загрузка...',
    'active_session': 'Активная прогулка',
    'session_saved': 'Прогулка успешно сохранена!',
    'redeem_success': 'Средства успешно переведены на кошелек!',
    'redeem_failed': 'Ошибка перевода средств',
    'wallet_balance': 'Баланс кошелька',
    'fullname': 'Имя и фамилия',
    'username': 'Имя пользователя',
    'language': 'Язык',
    'no_walks': 'История шагов пуста',
    'stats_title': 'Ваша активность',
    'about_app': 'О приложении',
    'help': 'Помощь',
    'wallet_history': 'Транзакции',
  },
  'en': {
    'home': 'Home',
    'walk': 'Walk',
    'history': 'History',
    'profile': 'Profile',
    'today_steps': 'Steps Today',
    'step_goal': 'Step Goal',
    'distance': 'Distance',
    'calories': 'Calories',
    'duration': 'Duration',
    'convert_title': 'Convert Steps to Cash',
    'convert_button': 'Transfer to Wallet',
    'start_walk': 'Start Walk',
    'stop_walk': 'Finish Walk',
    'simulate_steps': 'Simulate Steps',
    'orbita_id': 'Orbita ID',
    'password': 'Password',
    'login': 'Log In',
    'logout': 'Log Out',
    'loading': 'Loading...',
    'active_session': 'Walking Session Active',
    'session_saved': 'Walk saved successfully!',
    'redeem_success': 'Cash successfully credited to your wallet!',
    'redeem_failed': 'Failed to credit cash',
    'wallet_balance': 'Wallet Balance',
    'fullname': 'Full Name',
    'username': 'Username',
    'language': 'Language',
    'no_walks': 'No walk history yet',
    'stats_title': 'Your Activity',
    'about_app': 'About App',
    'help': 'Help & Support',
    'wallet_history': 'Transactions',
  }
};
