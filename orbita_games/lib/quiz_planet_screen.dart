import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'auth_provider.dart';
import 'widgets/score_manager.dart';

class QuizQuestion {
  final String text;
  final List<String> options;
  final int correctIndex;
  final String fact;

  const QuizQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.fact,
  });
}

class QuizPlanetScreen extends ConsumerStatefulWidget {
  const QuizPlanetScreen({super.key});

  @override
  ConsumerState<QuizPlanetScreen> createState() => _QuizPlanetScreenState();
}

class _QuizPlanetScreenState extends ConsumerState<QuizPlanetScreen> {
  final List<QuizQuestion> _allQuestions = const [
    QuizQuestion(
      text: 'O\'zbekiston qachon mustaqillikka erishgan?',
      options: ['1990-yil', '1991-yil', '1992-yil', '1989-yil'],
      correctIndex: 1,
      fact: '1991-yil 31-avgustda mustaqillik e\'lon qilingan.',
    ),
    QuizQuestion(
      text: 'Quyosh tizimidagi eng katta sayyora qaysi?',
      options: ['Mars', 'Saturn', 'Yupiter', 'Venera'],
      correctIndex: 2,
      fact: 'Yupiter shunchalik kattaki, uning ichiga barcha boshqa sayyoralar sig\'ib ketishi mumkin.',
    ),
    QuizQuestion(
      text: 'Suvning kimyoviy formulasi qanday?',
      options: ['CO2', 'H2O', 'O2', 'NaCl'],
      correctIndex: 1,
      fact: 'Suv vodorod va kislorod atomlaridan iborat.',
    ),
    QuizQuestion(
      text: 'Dunyo bo\'yicha eng uzun daryo qaysi?',
      options: ['Amudaryo', 'Amazonka', 'Nil', 'Missisipi'],
      correctIndex: 2,
      fact: 'Nil daryosining uzunligi 6650 kmni tashkil etadi.',
    ),
    QuizQuestion(
      text: 'Inson tanasidagi eng katta a\'zo qaysi?',
      options: ['Jigar', 'Yurak', 'O\'pka', 'Teri'],
      correctIndex: 3,
      fact: 'Voyaga yetgan inson terisining og\'irligi taxminan 4-5 kgni tashkil qiladi.',
    ),
    QuizQuestion(
      text: 'Kosonsoy qaysi viloyatda joylashgan?',
      options: ['Farg\'ona', 'Namangan', 'Andijon', 'Toshkent'],
      correctIndex: 1,
      fact: 'Kosonsoy - Namangan viloyatining eng chiroyli tumanlaridan biri.',
    ),
  ];

  late List<QuizQuestion> _gameQuestions;
  int _currentIdx = 0;
  int _score = 0;
  int _coinsEarned = 0;
  bool _isAnswered = false;
  int? _selectedIdx;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    setState(() {
      _gameQuestions = List.from(_allQuestions)..shuffle();
      _gameQuestions = _gameQuestions.take(5).toList();
      _currentIdx = 0;
      _score = 0;
      _coinsEarned = 0;
      _isAnswered = false;
      _selectedIdx = null;
      _isGameOver = false;
    });
  }

  void _onOptionTap(int index) {
    if (_isAnswered) return;

    setState(() {
      _selectedIdx = index;
      _isAnswered = true;
      if (index == _gameQuestions[_currentIdx].correctIndex) {
        _score += 20;
        _coinsEarned += 10;
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.vibrate();
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentIdx < _gameQuestions.length - 1) {
        setState(() {
          _currentIdx++;
          _isAnswered = false;
          _selectedIdx = null;
        });
      } else {
        _triggerGameOver();
      }
    });
  }

  Future<void> _triggerGameOver() async {
    setState(() {
      _isGameOver = true;
    });

    await ScoreManager().saveResult(
      gameType: 'QUIZ_PLANET',
      score: _score,
      coins: _coinsEarned,
      api: ref.read(apiServiceProvider),
      ref: ref,
    );
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
        title: Text('Quiz Planet', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [GamesTheme.background, Color(0xFF0F0E2A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isGameOver ? _buildGameOverUI() : _buildQuizUI(),
      ),
    );
  }

  Widget _buildQuizUI() {
    final q = _gameQuestions[_currentIdx];
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SAVOL ${_currentIdx + 1}/${_gameQuestions.length}',
                style: GoogleFonts.outfit(color: GamesTheme.primary, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: GamesTheme.accent, size: 16),
                    const SizedBox(width: 4),
                    Text('+$_coinsEarned', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (_currentIdx + 1) / _gameQuestions.length,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: const AlwaysStoppedAnimation(GamesTheme.primary),
          ),
          
          const Spacer(),
          
          // Question Card
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: GamesTheme.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1E1E45)),
            ),
            child: Text(
              q.text,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Options
          ...List.generate(q.options.length, (i) {
            Color btnColor = const Color(0xFF1E1E45);
            Color borderColor = const Color(0xFF2E2E5D);
            IconData? icon;

            if (_isAnswered) {
              if (i == q.correctIndex) {
                btnColor = GamesTheme.success.withOpacity(0.2);
                borderColor = GamesTheme.success;
                icon = Icons.check_circle_rounded;
              } else if (i == _selectedIdx) {
                btnColor = Colors.redAccent.withOpacity(0.2);
                borderColor = Colors.redAccent;
                icon = Icons.cancel_rounded;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _onOptionTap(i),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: btnColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + i),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          q.options[i],
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (icon != null) Icon(icon, color: borderColor, size: 24),
                    ],
                  ),
                ),
              ),
            );
          }),
          
          const Spacer(),
          
          // Fact bar
          if (_isAnswered)
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: GamesTheme.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        q.fact,
                        style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGameOverUI() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: GamesTheme.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: GamesTheme.success.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, color: GamesTheme.accent, size: 64),
            const SizedBox(height: 20),
            Text('VIKTORINA YAKUNLANDI', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ResultStat(label: 'BALL', value: '$_score'),
                _ResultStat(label: 'TANGALAR', value: '+$_coinsEarned', color: GamesTheme.accent),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GamesTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _startNewGame,
                child: const Text('QAYTA BOSHLASH', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultStat({required this.label, required this.value, this.color = Colors.white});

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
