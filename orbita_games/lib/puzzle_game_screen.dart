import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'auth_provider.dart';
import 'widgets/score_manager.dart';

class MemoryCard {
  final int id;
  final IconData icon;
  final Color color;
  bool isFaceUp = false;
  bool isMatched = false;

  MemoryCard({required this.id, required this.icon, required this.color});
}

class PuzzleGameScreen extends ConsumerStatefulWidget {
  const PuzzleGameScreen({super.key});

  @override
  ConsumerState<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends ConsumerState<PuzzleGameScreen> {
  final List<IconData> _cardIcons = [
    Icons.rocket_launch_rounded,
    Icons.blur_on_rounded,
    Icons.star_rounded,
    Icons.public_rounded,
    Icons.nights_stay_rounded,
    Icons.wb_sunny_rounded,
    Icons.flare_rounded,
    Icons.explore_rounded,
    Icons.satellite_alt_rounded,
    Icons.wb_twilight_rounded,
    Icons.auto_awesome_rounded,
    Icons.waves_rounded,
    Icons.ac_unit_rounded,
    Icons.vpn_lock_rounded,
    Icons.language_rounded,
    Icons.science_rounded,
    Icons.bolt_rounded,
    Icons.eco_rounded,
  ];

  final List<Color> _cardColors = [
    GamesTheme.primary,
    GamesTheme.secondary,
    GamesTheme.accent,
    Colors.lightBlueAccent,
    Colors.deepOrangeAccent,
    Colors.greenAccent,
    Colors.redAccent,
    Colors.indigoAccent,
    Colors.amberAccent,
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.cyanAccent,
    Colors.limeAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.blueAccent,
    Colors.yellowAccent,
    Colors.brown,
  ];

  List<MemoryCard> _cards = [];
  List<int> _selectedIndices = [];
  
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _hasWon = false;
  int _difficulty = 4; // 4x4, 6x6 etc

  int _score = 0;
  int _coinsEarned = 0;
  int _timeLeft = 45; 
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startNewGame() {
    _timer?.cancel();
    _score = 0;
    _coinsEarned = 0;
    _timeLeft = _difficulty == 4 ? 45 : 90;
    _isPlaying = true;
    _isGameOver = false;
    _hasWon = false;
    _selectedIndices = [];
    
    // Duplicate icons to form pairs
    List<MemoryCard> list = [];
    int cardId = 0;
    int pairCount = (_difficulty * _difficulty) ~/ 2;

    for (int i = 0; i < pairCount; i++) {
      list.add(MemoryCard(id: cardId++, icon: _cardIcons[i % _cardIcons.length], color: _cardColors[i % _cardColors.length]));
      list.add(MemoryCard(id: cardId++, icon: _cardIcons[i % _cardIcons.length], color: _cardColors[i % _cardColors.length]));
    }
    
    // Shuffle
    list.shuffle();
    
    setState(() {
      _cards = list;
    });

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeLeft <= 1) {
        timer.cancel();
        _triggerGameOver(false);
      } else {
        setState(() {
          _timeLeft--;
        });
      }
    });
  }

  void _onCardTap(int index) {
    if (!_isPlaying || _isGameOver || _cards[index].isFaceUp || _cards[index].isMatched || _selectedIndices.length >= 2) {
      return;
    }

    setState(() {
      _cards[index].isFaceUp = true;
      _selectedIndices.add(index);
    });
    
    HapticFeedback.lightImpact();

    if (_selectedIndices.length == 2) {
      _checkMatch();
    }
  }

  void _checkMatch() {
    final idx1 = _selectedIndices[0];
    final idx2 = _selectedIndices[1];
    
    if (_cards[idx1].icon == _cards[idx2].icon) {
      // Matched!
      setState(() {
        _cards[idx1].isMatched = true;
        _cards[idx2].isMatched = true;
        _selectedIndices = [];
        _score += 100;
        _coinsEarned += 15; // 15 coins per match
      });
      HapticFeedback.lightImpact();
      _saveCoins(15);

      // Check win
      if (_cards.every((c) => c.isMatched)) {
        _timer?.cancel();
        _triggerGameOver(true);
      }
    } else {
      // Flip back over after delay
      Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _cards[idx1].isFaceUp = false;
          _cards[idx2].isFaceUp = false;
          _selectedIndices = [];
        });
      });
    }
  }

  Future<void> _saveCoins(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt('coin_bank') ?? 0;
    await prefs.setInt('coin_bank', currentCoins + count);
  }

  void _triggerGameOver(bool win) async {
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _hasWon = win;
    });

    if (win) {
      int bonus = _difficulty == 4 ? 50 : 150;
      _coinsEarned += bonus;
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.vibrate();
    }

    await ScoreManager().saveResult(
      gameType: 'MEMORY',
      score: _score,
      coins: _coinsEarned,
      api: ref.read(apiServiceProvider),
      ref: ref,
    );
  }

  void _changeDifficulty(int d) {
    setState(() {
      _difficulty = d;
    });
    _startNewGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamesTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: Text('Koinot Xotirasi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [GamesTheme.background, Color(0xFF0F0E2A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Timer and HUD Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _timeLeft <= 10 ? Colors.redAccent.withOpacity(0.1) : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _timeLeft <= 10 ? Colors.redAccent : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_rounded, color: _timeLeft <= 10 ? Colors.redAccent : GamesTheme.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '$_timeLeft S',
                          style: TextStyle(
                            color: _timeLeft <= 10 ? Colors.redAccent : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: GamesTheme.accent, size: 18),
                        const SizedBox(width: 6),
                        Text('+$_coinsEarned', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Memory Card Grid
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _difficulty,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _cards.length,
                      itemBuilder: (context, index) {
                        final card = _cards[index];
                        final isRevealed = card.isFaceUp || card.isMatched;

                        return GestureDetector(
                          onTap: () => _onCardTap(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: isRevealed ? GamesTheme.card : const Color(0xFF1B1B4A),
                              borderRadius: BorderRadius.circular(_difficulty == 4 ? 16 : 10),
                              border: Border.all(
                                color: card.isMatched
                                    ? GamesTheme.success
                                    : isRevealed
                                        ? card.color
                                        : const Color(0xFF28285C),
                                width: 2.0,
                              ),
                            ),
                            child: Center(
                              child: isRevealed
                                  ? Icon(card.icon, color: card.color, size: _difficulty == 4 ? 28 : 20)
                                  : Icon(Icons.help_outline_rounded, color: GamesTheme.primary.withOpacity(0.4), size: _difficulty == 4 ? 24 : 18),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Game Over Overlay / Score Banner
              if (_isGameOver) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: GamesTheme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _hasWon ? GamesTheme.success.withOpacity(0.4) : Colors.redAccent.withOpacity(0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _hasWon ? Icons.emoji_events_rounded : Icons.timer_off_rounded,
                        color: _hasWon ? GamesTheme.accent : Colors.redAccent,
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _hasWon ? 'G\'ALABA!' : 'VAQT TUGADI!',
                        style: GoogleFonts.outfit(
                          color: _hasWon ? GamesTheme.success : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _hasWon
                            ? 'Barcha juftliklarni topdingiz! +50 g\'alaba bonusi.'
                            : 'Barcha juftliklarni topishga ulgurmadingiz.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _difficulty == 4 ? GamesTheme.primary : GamesTheme.textSecondary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _changeDifficulty(4),
                              child: Text('ODDIY (4x4)', style: TextStyle(color: _difficulty == 4 ? GamesTheme.primary : GamesTheme.textSecondary, fontSize: 10)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _difficulty == 6 ? GamesTheme.primary : GamesTheme.textSecondary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _changeDifficulty(6),
                              child: Text('QIYIN (6x6)', style: TextStyle(color: _difficulty == 6 ? GamesTheme.primary : GamesTheme.textSecondary, fontSize: 10)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GamesTheme.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _startNewGame,
                          child: const Text('QAYTA BOSHLASH', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
