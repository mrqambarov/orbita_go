import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'theme.dart';
import 'auth_provider.dart';
import 'widgets/score_manager.dart';
import 'widgets/particle_overlay.dart';
import 'widgets/bouncy_button.dart';

class MathDashScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? duelData;
  final IO.Socket? socket;

  const MathDashScreen({super.key, this.duelData, this.socket});

  @override
  ConsumerState<MathDashScreen> createState() => _MathDashScreenState();
}

class _MathDashScreenState extends ConsumerState<MathDashScreen> {
  late Random _random;
  final GlobalKey<ParticleOverlayState> _particleKey = GlobalKey();
  
  int _score = 0;
  int _opponentScore = 0;
  int _coinsEarned = 0;
  int _lives = 3;
  double _timerValue = 1.0;
  Timer? _gameTimer;
  
  String _question = '';
  int _correctAnswer = 0;
  List<int> _options = [];
  
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isDuel = false;
  bool _opponentFinished = false;

  @override
  void initState() {
    super.initState();
    _isDuel = widget.duelData != null;
    _random = Random(_isDuel ? (widget.duelData!['seed'] ?? 0) : null);
    
    if (_isDuel) {
      widget.socket!.on('opponent_progress', (data) {
        if (mounted) setState(() => _opponentScore = data['score']);
      });
      widget.socket!.on('opponent_finished', (data) {
        if (mounted) setState(() {
          _opponentFinished = true;
          _opponentScore = data['score'];
        });
      });
      _startGame();
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _score = 0;
      _coinsEarned = 0;
      _lives = 3;
      _isPlaying = true;
      _isGameOver = false;
      _timerValue = 1.0;
    });
    _generateQuestion();
    _startTimer();
  }

  void _startTimer() {
    _gameTimer?.cancel();
    const tick = Duration(milliseconds: 50);
    _gameTimer = Timer.periodic(tick, (timer) {
      if (!mounted) return;
      
      double decrease = 0.005 + (_score / 5000);
      setState(() {
        _timerValue -= decrease;
      });

      if (_timerValue <= 0) {
        _handleWrongAnswer(timeout: true);
      }
    });
  }

  void _generateQuestion() {
    int a, b;
    String op;
    
    if (_score < 50) {
      a = _random.nextInt(10) + 1;
      b = _random.nextInt(10) + 1;
      op = _random.nextBool() ? '+' : '-';
    } else if (_score < 150) {
      a = _random.nextInt(20) + 5;
      b = _random.nextInt(20) + 5;
      op = _random.nextBool() ? '+' : '-';
    } else {
      a = _random.nextInt(12) + 2;
      b = _random.nextInt(10) + 2;
      op = _random.nextBool() ? '*' : (_random.nextBool() ? '+' : '-');
    }

    if (op == '-') {
      if (a < b) {
        int temp = a;
        a = b;
        b = temp;
      }
      _correctAnswer = a - b;
    } else if (op == '*') {
      _correctAnswer = a * b;
    } else {
      _correctAnswer = a + b;
    }

    _question = '$a $op $b = ?';

    Set<int> opts = {_correctAnswer};
    while (opts.length < 4) {
      int off = _random.nextInt(10) - 5;
      int fake = _correctAnswer + off;
      if (fake >= 0 && fake != _correctAnswer) {
        opts.add(fake);
      } else {
        opts.add(_correctAnswer + opts.length + 1);
      }
    }
    
    _options = opts.toList();
    _options.shuffle();
    _timerValue = 1.0;
  }

  void _onOptionTap(int selected) {
    if (!_isPlaying || _isGameOver) return;

    if (selected == _correctAnswer) {
      setState(() {
        _score += 10;
        _coinsEarned += 2;
      });
      _particleKey.currentState?.showBurst(const Offset(200, 400), color: GamesTheme.success);
      HapticFeedback.lightImpact();
      _generateQuestion();
      
      if (_isDuel) {
        widget.socket!.emit('duel_progress', {
          'duelId': widget.duelData!['duelId'],
          'opponentId': widget.duelData!['opponentId'],
          'score': _score
        });
      }
    } else {
      _handleWrongAnswer();
    }
  }

  void _handleWrongAnswer({bool timeout = false}) {
    HapticFeedback.vibrate();
    setState(() {
      _lives--;
      if (_lives <= 0) {
        _triggerGameOver();
      } else {
        _generateQuestion();
      }
    });
  }

  Future<void> _triggerGameOver() async {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });

    if (_isDuel) {
      widget.socket!.emit('duel_finish', {
        'duelId': widget.duelData!['duelId'],
        'opponentId': widget.duelData!['opponentId'],
        'score': _score
      });
    }

    await ScoreManager().saveResult(
      gameType: 'MATH_DASH',
      score: _score,
      coins: _coinsEarned,
      api: ref.read(apiServiceProvider),
      ref: ref,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ParticleOverlay(
      overlayKey: _particleKey,
      child: Scaffold(
        backgroundColor: GamesTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
          ),
          title: Text('Math Dash', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [GamesTheme.background, Color(0xFF0F0E2A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: _isPlaying ? _buildGameUI() : _buildStartOrGameOverUI(),
        ),
      ),
    );
  }

  Widget _buildGameUI() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BALL', style: TextStyle(color: GamesTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('$_score', style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
              if (_isDuel)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('RAQIB', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('$_opponentScore', style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              Row(
                children: List.generate(3, (index) {
                  return Icon(
                    index < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: index < _lives ? Colors.redAccent : GamesTheme.textSecondary,
                    size: 28,
                  );
                }),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _timerValue,
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(
                _timerValue > 0.6 ? GamesTheme.success : (_timerValue > 0.3 ? GamesTheme.accent : Colors.redAccent),
              ),
            ),
          ),
        ),
        const Spacer(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(vertical: 40),
          width: double.infinity,
          decoration: BoxDecoration(
            color: GamesTheme.card,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: GamesTheme.primary.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(color: GamesTheme.primary.withOpacity(0.05), blurRadius: 20),
            ],
          ),
          child: Center(
            child: Text(
              _question,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final opt = _options[index];
              return BouncyButton(
                onTap: () => _onOptionTap(opt),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E45),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2E2E5D)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$opt',
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStartOrGameOverUI() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: GamesTheme.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _isGameOver ? Colors.redAccent.withOpacity(0.3) : GamesTheme.primary.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isGameOver ? Icons.timer_off_rounded : Icons.calculate_rounded,
              color: _isGameOver ? Colors.redAccent : GamesTheme.primary,
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              _isGameOver ? (_isDuel ? (_score > _opponentScore ? 'G\'ALABA!' : (_score == _opponentScore ? 'DURANG' : 'MAG\'LUBIYAT')) : 'O\'YIN TUGADI') : 'Math Dash',
              style: GoogleFonts.outfit(
                color: _isGameOver ? (_isDuel ? (_score >= _opponentScore ? GamesTheme.success : Colors.redAccent) : Colors.redAccent) : Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isGameOver 
                ? 'Miyangizni dam oldiring va qayta urinib ko\'ring!'
                : 'Tezkor misollar! Qancha ko\'p to\'g\'ri javob bersangiz, shuncha tezlashadi.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            if (_isGameOver) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatBox(label: 'BALL', value: '$_score'),
                  _StatBox(label: 'TANGALAR', value: '+$_coinsEarned', color: GamesTheme.accent),
                ],
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GamesTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _startGame,
                child: Text(
                  _isGameOver ? 'QAYTA BOSHLASH' : 'BOSHLASH',
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({required this.label, required this.value, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.outfit(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
