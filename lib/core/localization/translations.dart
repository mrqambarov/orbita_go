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
    'history': 'Sayohat tarixi',
    'profile': 'Profil',
    'where_to': 'Qayerga?',
    'where_from': 'Qayerdan?',
    'call_taxi': 'Taksi chaqirish',
    'driver_mode': 'Haydovchi rejimi',
    'about_app': 'Ilova haqida',
    'help': 'Yordam',
    'payment_method': 'To\'lov usullari',
    'logout': 'Chiqish',
    'edit_profile': 'Profilni tahrirlash',
    'save': 'Saqlash',
    'cancel': 'Bekor qilish',
    'detecting_location': 'Joylashuv aniqlanmoqda...',
    'current_location': 'Joriy joylashuv',
    'language': 'Til',
    'no_trips': 'Sayohatlar topilmadi',
    'standard': 'Standard',
    'comfort': 'Comfort',
    'business': 'Business',
    'taxi_search': 'Taksi qidirilmoqda...',
    'driver_arriving': 'Haydovchi kelmoqda',
    'driver_arrived': 'Haydovchi yetib keldi',
    'in_trip': 'Sayohatda',
    'completed': 'Tugadi',
    'cancelled': 'Bekor qilindi',
    'chat': 'Chat',
    'write_message': 'Xabar yozing...',
    'available_orders': 'Kosonsoy buyurtmalari',
    'no_orders': 'Hozircha buyurtmalar yo\'q',
    'accept': 'Qabul qilish',
    'arrived': 'Men yetib keldim',
    'start_trip': 'Sayohatni boshlash',
    'end_trip': 'Sayohatni tugatish',
    'wallet_balance': 'Hamyon balansi',
    'fullname': 'Ism-familiya',
    'username': 'Username',
  },
  'ru': {
    'home': 'Главная',
    'history': 'История поездок',
    'profile': 'Профиль',
    'where_to': 'Куда?',
    'where_from': 'Откуда?',
    'call_taxi': 'Заказать такси',
    'driver_mode': 'Режим водителя',
    'about_app': 'О приложении',
    'help': 'Помощь',
    'payment_method': 'Способы оплаты',
    'logout': 'Выйти',
    'edit_profile': 'Редактировать профиль',
    'save': 'Сохранить',
    'cancel': 'Отмена',
    'detecting_location': 'Определение геопозиции...',
    'current_location': 'Текущее местоположение',
    'language': 'Язык',
    'no_trips': 'Поездок не найдено',
    'standard': 'Стандарт',
    'comfort': 'Комфорт',
    'business': 'Бизнес',
    'taxi_search': 'Поиск такси...',
    'driver_arriving': 'Водитель едет к вам',
    'driver_arrived': 'Водитель ожидает',
    'in_trip': 'В пути',
    'completed': 'Завершено',
    'cancelled': 'Отменено',
    'chat': 'Чат',
    'write_message': 'Напишите сообщение...',
    'available_orders': 'Заказы в Косонсое',
    'no_orders': 'Пока нет доступных заказов',
    'accept': 'Принять заказ',
    'arrived': 'Я на месте',
    'start_trip': 'Начать поездку',
    'end_trip': 'Завершить поездку',
    'wallet_balance': 'Баланс кошелька',
    'fullname': 'Имя и фамилия',
    'username': 'Имя пользователя',
  },
  'en': {
    'home': 'Home',
    'history': 'Trip History',
    'profile': 'Profile',
    'where_to': 'Where to?',
    'where_from': 'Where from?',
    'call_taxi': 'Call Taxi',
    'driver_mode': 'Driver Mode',
    'about_app': 'About App',
    'help': 'Help & Support',
    'payment_method': 'Payment Methods',
    'logout': 'Logout',
    'edit_profile': 'Edit Profile',
    'save': 'Save',
    'cancel': 'Cancel',
    'detecting_location': 'Detecting location...',
    'current_location': 'Current location',
    'language': 'Language',
    'no_trips': 'No trips found',
    'standard': 'Standard',
    'comfort': 'Comfort',
    'business': 'Business',
    'taxi_search': 'Searching taxi...',
    'driver_arriving': 'Driver is arriving',
    'driver_arrived': 'Driver arrived',
    'in_trip': 'In trip',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'chat': 'Chat',
    'write_message': 'Type a message...',
    'available_orders': 'Kosonsoy Orders',
    'no_orders': 'No available orders',
    'accept': 'Accept Request',
    'arrived': 'I have arrived',
    'start_trip': 'Start Trip',
    'end_trip': 'End Trip',
    'wallet_balance': 'Wallet Balance',
    'fullname': 'Full Name',
    'username': 'Username',
  },
};

final driverModeProvider = StateProvider<bool>((ref) => false);
