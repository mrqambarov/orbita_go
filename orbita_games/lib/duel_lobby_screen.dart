import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'auth_provider.dart';
import 'theme.dart';
import 'math_dash_screen.dart'; // We'll adapt it to support duel

class DuelLobbyScreen extends ConsumerStatefulWidget {
  const DuelLobbyScreen({super.key});

  @override
  ConsumerState<DuelLobbyScreen> createState() => _DuelLobbyScreenState();
}

class _DuelLobbyScreenState extends ConsumerState<DuelLobbyScreen> {
  IO.Socket? _socket;
  bool _isSearching = false;
  String? _statusText;

  String? _searchingGameType;
  
  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
    final userId = ref.read(authProvider).user?['id'];
    _socket = IO.io('https://api.orbitago.uz', IO.OptionBuilder()
      .setTransports(['websocket'])
      .setQuery({'userId': userId})
      .build());

    _socket!.onConnect((_) {
      print('Socket connected');
    });

    _socket!.on('duel_start', (data) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _statusText = 'Raqib topildi!';
      });
      
      // Navigate to game with duel data
      // For now, let's just use Math Dash as a test
      Navigator.push(context, MaterialPageRoute(builder: (_) => MathDashScreen(duelData: data, socket: _socket)));
    });
  }

  @override
  void dispose() {
    if (_isSearching && _searchingGameType != null) {
      final userId = ref.read(authProvider).user?['id'];
      _socket?.emit('leave_duel_queue', {'userId': userId, 'gameType': _searchingGameType});
    }
    _socket?.disconnect();
    super.dispose();
  }

  void _joinQueue(String gameType) {
    final userId = ref.read(authProvider).user?['id'];
    _searchingGameType = gameType;
    _socket?.emit('join_duel_queue', {'userId': userId, 'gameType': gameType});
    setState(() {
      _isSearching = true;
      _statusText = 'Raqib qidirilmoqda...';
    });
  }

  void _leaveQueue() {
    if (_searchingGameType != null) {
      final userId = ref.read(authProvider).user?['id'];
      _socket?.emit('leave_duel_queue', {'userId': userId, 'gameType': _searchingGameType});
    }
    setState(() {
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamesTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('DUEL REJIMI', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: _isSearching 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: GamesTheme.primary),
                const SizedBox(height: 20),
                Text(_statusText ?? '', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _leaveQueue,
                  child: const Text('BEKOR QILISH'),
                )
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DuelCard(
                  title: 'Math Dash Duel',
                  icon: Icons.calculate_rounded,
                  color: Colors.deepOrangeAccent,
                  onTap: () => _joinQueue('MATH_DASH'),
                ),
                const SizedBox(height: 16),
                _DuelCard(
                  title: 'Quiz Duel (Tez kunda)',
                  icon: Icons.lightbulb_rounded,
                  color: Colors.amberAccent,
                  onTap: null,
                ),
              ],
            ),
      ),
    );
  }
}

class _DuelCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _DuelCard({required this.title, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: GamesTheme.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(width: 20),
            Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: onTap == null ? Colors.grey : Colors.white)),
          ],
        ),
      ),
    );
  }
}
