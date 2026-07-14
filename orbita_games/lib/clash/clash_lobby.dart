import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../auth_provider.dart';
import '../theme.dart';
import '../widgets/galaxy_background.dart';
import 'clash_screen.dart';

/// Orbita Clash — online raqib qidirish (matchmaking).
class ClashLobbyScreen extends ConsumerStatefulWidget {
  const ClashLobbyScreen({super.key});
  @override
  ConsumerState<ClashLobbyScreen> createState() => _ClashLobbyScreenState();
}

class _ClashLobbyScreenState extends ConsumerState<ClashLobbyScreen> {
  IO.Socket? _socket;
  String _status = 'Raqib qidirilmoqda...';
  bool _navigated = false;
  Timer? _dots;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _dots = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount + 1) % 4);
    });
    _connect();
  }

  void _connect() {
    final userId = ref.read(authProvider).user?['id'];
    if (userId == null) {
      setState(() => _status = 'Avval tizimga kiring');
      return;
    }
    _socket = IO.io(
      'https://api.orbitago.uz',
      IO.OptionBuilder().setTransports(['websocket']).setQuery({'userId': userId}).build(),
    );
    _socket!.onConnect((_) {
      _socket!.emit('join_client_room', userId);
      _socket!.emit('join_user_room', userId);
      _socket!.emit('join_duel_queue', {'userId': userId, 'gameType': 'CLASH'});
    });
    _socket!.on('duel_start', (data) {
      if (_navigated || !mounted) return;
      _navigated = true;
      final oppId = data is Map ? data['opponentId'] : null;
      _socket!.off('duel_start');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ClashScreen(socket: _socket, opponentId: oppId)),
      );
    });
  }

  void _cancel() {
    final userId = ref.read(authProvider).user?['id'];
    _socket?.emit('leave_duel_queue', {'userId': userId, 'gameType': 'CLASH'});
    _socket?.disconnect();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _dots?.cancel();
    // Agar o'yinga o'tган bo'lsak, socket ClashScreen ixtiyorida qoladi
    if (!_navigated) _socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GalaxyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 24),
                Text('ORBITA CLASH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [Shadow(color: const Color(0xFF7C4DFF).withValues(alpha: 0.9), blurRadius: 16)],
                    )),
                const SizedBox(height: 30),
                const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: GamesTheme.primary)),
                const SizedBox(height: 24),
                Text('$_status${'.' * _dotCount}',
                    style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 8),
                const Text('Online raqib bilan real jang', style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 50),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _cancel,
                  child: const Text('BEKOR QILISH'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
