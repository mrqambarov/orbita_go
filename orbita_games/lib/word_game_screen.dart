import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'auth_provider.dart';
import 'widgets/score_manager.dart';
import 'widgets/particle_overlay.dart';
import 'widgets/bouncy_button.dart';

class WordLevel {
  final int number;
  final String letters; // Scrambled letter options
  final List<String> targetWords; // Words to find

  const WordLevel({
    required this.number,
    required this.letters,
    required this.targetWords,
  });
}

class WordGameScreen extends ConsumerStatefulWidget {
  const WordGameScreen({super.key});

  @override
  ConsumerState<WordGameScreen> createState() => _WordGameScreenState();
}

class _WordGameScreenState extends ConsumerState<WordGameScreen> {
  final GlobalKey<ParticleOverlayState> _particleKey = GlobalKey();
  
  // Levels categorized by difficulty (Planet-based progression)
  final List<WordLevel> _levels = const [
    // --- PLANET 1: START (3 letters) ---
    WordLevel(number: 1, letters: 'ONA', targetWords: ['ONA', 'ON']),
    WordLevel(number: 2, letters: 'OTA', targetWords: ['OTA', 'OT']),
    WordLevel(number: 3, letters: 'BOL', targetWords: ['BOL', 'OL']),
    WordLevel(number: 4, letters: 'SUT', targetWords: ['SUT', 'TU']),
    WordLevel(number: 5, letters: 'AKA', targetWords: ['AKA', 'AK']),
    
    // --- PLANET 2: RISING (4 letters, more words) ---
    WordLevel(number: 6, letters: 'TOSH', targetWords: ['TOSH', 'OSH', 'SHO']),
    WordLevel(number: 7, letters: 'OLMA', targetWords: ['OLMA', 'OLAM', 'MOL', 'LOA']),
    WordLevel(number: 8, letters: 'BAXT', targetWords: ['BAXT', 'BAT', 'XAT']),
    WordLevel(number: 9, letters: 'ILIM', targetWords: ['BILIM', 'ILM', 'MIL', 'BIL']),
    WordLevel(number: 10, letters: 'OZOD', targetWords: ['OZOD', 'OZ', 'DOZ', 'ZOO']),

    // --- PLANET 3: JOURNEY (5 letters, complexity+) ---
    WordLevel(number: 11, letters: 'VATAN', targetWords: ['VATAN', 'TAN', 'ANA', 'ANT', 'NAV']),
    WordLevel(number: 12, letters: 'KITOB', targetWords: ['KITOB', 'BOT', 'TOK', 'OTI', 'KIB']),
    WordLevel(number: 13, letters: 'QUYOSH', targetWords: ['QUYOSH', 'OSH', 'QUY', 'SHOY', 'YOSH']),
    WordLevel(number: 14, letters: 'DARYO', targetWords: ['DARYO', 'DOR', 'YO', 'ROY', 'ODR']),
    WordLevel(number: 15, letters: 'MEHRI', targetWords: ['MEHR', 'ERI', 'RIM', 'EMO', 'HER']),

    // --- PLANET 4: WISDOM (6+ letters, high word count) ---
    WordLevel(number: 16, letters: 'AQLLI', targetWords: ['AQLLI', 'AQL', 'LIL', 'LAQ', 'ALI']),
    WordLevel(number: 17, letters: 'INSON', targetWords: ['INSON', 'SON', 'NOS', 'ONI', 'SIN']),
    WordLevel(number: 18, letters: 'GULZOR', targetWords: ['GULZOR', 'GUL', 'ZOR', 'ROZ', 'LOR', 'UZ']),
    WordLevel(number: 19, letters: 'YORDAM', targetWords: ['YORDAM', 'DOR', 'DAM', 'ROM', 'MOD', 'YOR']),
    WordLevel(number: 20, letters: 'HURMAT', targetWords: ['HURMAT', 'TUR', 'RUM', 'HAT', 'TAM', 'MAT']),

    // --- PLANET 5: MASTER (7+ letters, challenging) ---
    WordLevel(number: 21, letters: 'ORBITA', targetWords: ['ORBITA', 'ARI', 'BOT', 'BIR', 'BOR', 'TOY', 'BAR', 'TRI']),
    WordLevel(number: 22, letters: 'KOSONSOY', targetWords: ['KOSONSOY', 'OSON', 'SOY', 'KOS', 'ON', 'SON', 'SOK', 'NOS']),
    WordLevel(number: 23, letters: 'NAMANGAN', targetWords: ['NAMANGAN', 'MANA', 'GANA', 'ANA', 'NAN', 'MAGA', 'ANG']),
    WordLevel(number: 24, letters: 'SAMARQAND', targetWords: ['SAMARQAND', 'SAMAR', 'QAND', 'ARQ', 'SAM', 'DAR', 'SAR', 'QAM']),
    WordLevel(number: 25, letters: 'BUXORO', targetWords: ['BUXORO', 'BOR', 'XOR', 'ROX', 'ORU', 'XUB']),
    
    // --- INFINITY PACK ---
    WordLevel(number: 26, letters: 'TOSHKENT', targetWords: ['TOSHKENT', 'TOSH', 'KENT', 'TEN', 'OSH', 'KOT', 'NET', 'SHOK']),
    WordLevel(number: 27, letters: 'UCHKUDUK', targetWords: ['UCHKUDUK', 'UCH', 'KUDUK', 'KUDU', 'KUCH', 'DUK', 'UKU']),
    WordLevel(number: 28, letters: 'ZAMONVIY', targetWords: ['ZAMON', 'NOM', 'OZ', 'VON', 'MAZ', 'NOZ']),
    WordLevel(number: 29, letters: 'MEHRIBON', targetWords: ['MEHR', 'BON', 'ERI', 'RIM', 'NOM', 'BOR', 'MIN']),
    WordLevel(number: 30, letters: 'ISHONCHLI', targetWords: ['ISHONCH', 'ISH', 'ON', 'CHIN', 'NOS', 'SIN', 'HIL', 'LOCH']),
  ];

  int _currentLevelIdx = 0;
  List<String> _foundWords = [];
  String _currentInput = '';
  int _coinsEarned = 0;
  int _coinBank = 0;
  List<String> _shuffledLetters = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLevelIdx = (prefs.getInt('word_level') ?? 0) % _levels.length;
      _coinBank = prefs.getInt('coin_bank') ?? 0;
      _foundWords = [];
      _currentInput = '';
      _shuffleCurrentLetters();
    });
  }

  void _shuffleCurrentLetters() {
    final letters = _levels[_currentLevelIdx].letters.split('');
    letters.shuffle();
    setState(() {
      _shuffledLetters = letters;
    });
  }

  void _onLetterTap(String letter) {
    if (_currentInput.length >= 10) return;
    setState(() {
      _currentInput += letter;
    });
    HapticFeedback.lightImpact();
  }

  void _clearInput() {
    setState(() {
      _currentInput = '';
    });
    HapticFeedback.selectionClick();
  }

  void _checkWord() {
    final word = _currentInput.toUpperCase();
    if (word.isEmpty) return;

    final level = _levels[_currentLevelIdx];
    if (level.targetWords.contains(word)) {
      if (_foundWords.contains(word)) {
        _showSnackBar('Ushbu so\'zni allaqachon topgansiz!');
      } else {
        setState(() {
          _foundWords.add(word);
          _currentInput = '';
          _coinsEarned += 20;
        });
        _particleKey.currentState?.showBurst(const Offset(200, 300), color: GamesTheme.primary);
        HapticFeedback.lightImpact();
        _showSnackBar('To\'g\'ri so\'z! +20 tanga', isSuccess: true);
        _saveCoins(20);

        if (_foundWords.length == level.targetWords.length) {
          _onLevelComplete();
        }
      }
    } else {
      _showSnackBar('Noto\'g\'ri so\'z. Qaytadan urining.');
      HapticFeedback.vibrate();
      setState(() => _currentInput = '');
    }
  }

  Future<void> _saveCoins(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt('coin_bank') ?? 0;
    final newTotal = currentCoins + count;
    await prefs.setInt('coin_bank', newTotal);
    setState(() => _coinBank = newTotal);
  }

  void _useHint() async {
    if (_coinBank < 50) {
      _showSnackBar('Yordam uchun 50 tanga kerak!');
      return;
    }
    final level = _levels[_currentLevelIdx];
    final remainingWords = level.targetWords.where((w) => !_foundWords.contains(w)).toList();
    if (remainingWords.isEmpty) return;

    final randomWord = remainingWords[Random().nextInt(remainingWords.length)];
    setState(() {
      _foundWords.add(randomWord);
      _coinBank -= 50;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coin_bank', _coinBank);
    HapticFeedback.mediumImpact();
    if (_foundWords.length == level.targetWords.length) _onLevelComplete();
  }

  void _onLevelComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: GamesTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('DARAJA YUTULDI!', textAlign: TextAlign.center, style: TextStyle(color: GamesTheme.success, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, color: GamesTheme.accent, size: 64),
            const SizedBox(height: 16),
            const Text('Tabriklaymiz! Barcha so\'zlarni topdingiz.', textAlign: TextAlign.center, style: TextStyle(color: GamesTheme.textSecondary)),
            const SizedBox(height: 12),
            Text('+100 Tanga Bonus!', style: GoogleFonts.outfit(color: GamesTheme.accent, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GamesTheme.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                Navigator.pop(context);
                final nextLvl = _currentLevelIdx + 1;
                await ScoreManager().saveResult(
                  gameType: 'WORD_QUEST',
                  score: nextLvl * 100,
                  level: nextLvl,
                  coins: 100,
                  api: ref.read(apiServiceProvider),
                  ref: ref,
                );
                setState(() {
                  _currentLevelIdx = nextLvl % _levels.length;
                  _foundWords = [];
                  _currentInput = '';
                  _shuffleCurrentLetters();
                });
              },
              child: const Text('KEYINGI DARAJAGA'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isSuccess ? GamesTheme.success : Colors.redAccent, duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final level = _levels[_currentLevelIdx];

    return ParticleOverlay(
      overlayKey: _particleKey,
      child: Scaffold(
        backgroundColor: GamesTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => Navigator.pop(context, true)),
          title: Text('SO\'Z TOP PRO', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [GamesTheme.background, Color(0xFF0F0E2A)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DARAJA: ${level.number}', style: GoogleFonts.outfit(color: GamesTheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [const Icon(Icons.stars_rounded, color: GamesTheme.accent, size: 16), const SizedBox(width: 6), Text('$_coinBank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Wrap(
                    spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                    children: level.targetWords.map((word) {
                      final isFound = _foundWords.contains(word);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: isFound ? GamesTheme.primary.withOpacity(0.2) : GamesTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: isFound ? GamesTheme.primary : const Color(0xFF24244D), width: 1.5)),
                        child: Text(isFound ? word : word.replaceAll(RegExp(r'.'), '_ '), style: TextStyle(color: isFound ? Colors.white : GamesTheme.textSecondary, fontWeight: FontWeight.w900, letterSpacing: isFound ? 1.0 : 4.0, fontSize: 16)),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: const Color(0xFF141436), borderRadius: BorderRadius.circular(20), border: Border.all(color: GamesTheme.primary.withOpacity(0.3))),
                child: Center(child: Text(_currentInput.isEmpty ? 'SO\'ZNI TURING...' : _currentInput, style: GoogleFonts.outfit(color: _currentInput.isEmpty ? GamesTheme.textSecondary : Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2.0))),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Wrap(
                  spacing: 15, runSpacing: 15, alignment: WrapAlignment.center,
                  children: _shuffledLetters.map((letter) => BouncyButton(
                    onTap: () => _onLetterTap(letter),
                    child: Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(gradient: const RadialGradient(colors: [Color(0xFF1D1D4A), GamesTheme.card]), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2E2E5D), width: 2)),
                      alignment: Alignment.center,
                      child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40),
                child: Row(
                  children: [
                    BouncyButton(
                      onTap: _useHint,
                      child: Container(width: 60, height: 60, decoration: BoxDecoration(color: const Color(0xFF1E1E45), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2E2E5D))), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lightbulb_outline_rounded, color: GamesTheme.accent), Text('50', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))])),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: BouncyButton(onTap: _clearInput, child: Container(height: 60, decoration: BoxDecoration(border: Border.all(color: GamesTheme.secondary.withOpacity(0.5)), borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: const Text('TOZALASH', style: TextStyle(color: GamesTheme.secondary, fontWeight: FontWeight.bold))))),
                    const SizedBox(width: 12),
                    Expanded(child: BouncyButton(onTap: _checkWord, child: Container(height: 60, decoration: BoxDecoration(color: GamesTheme.primary, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: GamesTheme.primary.withOpacity(0.3), blurRadius: 10)]), alignment: Alignment.center, child: const Text('TEKSHIRISH', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
