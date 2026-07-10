import 'package:just_audio/just_audio.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _isMusicEnabled = true;

  Future<void> playMusic(String assetPath) async {
    if (!_isMusicEnabled) return;
    try {
      await _bgPlayer.setAsset(assetPath);
      _bgPlayer.setLoopMode(LoopMode.one);
      _bgPlayer.play();
    } catch (e) {
      print('Audio Error: $e');
    }
  }

  Future<void> playSFX(String assetPath) async {
    try {
      await _sfxPlayer.setAsset(assetPath);
      _sfxPlayer.play();
    } catch (e) {
      print('SFX Error: $e');
    }
  }

  void stopMusic() => _bgPlayer.stop();
  void toggleMusic() {
    _isMusicEnabled = !_isMusicEnabled;
    if (_isMusicEnabled) _bgPlayer.play(); else _bgPlayer.pause();
  }
}
