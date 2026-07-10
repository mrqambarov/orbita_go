import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';
import 'theme.dart';
import 'widgets/premium_card.dart';
import 'widgets/bouncy_button.dart';
import 'widgets/audio_manager.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _hapticEnabled = true;
  final String _appVersion = '2.2.5 (PRO)';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _musicEnabled = prefs.getBool('music_enabled') ?? true;
      _sfxEnabled = prefs.getBool('sfx_enabled') ?? true;
      _hapticEnabled = prefs.getBool('haptic_enabled') ?? true;
    });
  }

  Future<void> _toggleMusic(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_enabled', value);
    setState(() => _musicEnabled = value);
    AudioManager().toggleMusic();
  }

  Future<void> _toggleSFX(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sfx_enabled', value);
    setState(() => _sfxEnabled = value);
  }

  Future<void> _toggleHaptic(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_enabled', value);
    setState(() => _hapticEnabled = value);
    if (value) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user ?? {};
    final String fullName = user['fullName'] ?? 'Foydalanuvchi';
    final String orbitaId = user['orbitaId'] ?? 'ORB-000000';

    return Scaffold(
      backgroundColor: GamesTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('SOZLAMALAR', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: 'PROFIL'),
            const SizedBox(height: 16),
            PremiumCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: GamesTheme.primary.withOpacity(0.1),
                    child: const Icon(Icons.person_rounded, color: GamesTheme.primary, size: 35),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(orbitaId, style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified_user_rounded, color: GamesTheme.success, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _SectionHeader(title: 'OVOZ VA EFFEKTLAR'),
            const SizedBox(height: 16),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingToggle(title: 'Fon musiqasi', icon: Icons.music_note_rounded, value: _musicEnabled, onChanged: _toggleMusic),
                  const Divider(color: Colors.white10, height: 1),
                  _SettingToggle(title: 'Ovoz effektlari (SFX)', icon: Icons.volume_up_rounded, value: _sfxEnabled, onChanged: _toggleSFX),
                  const Divider(color: Colors.white10, height: 1),
                  _SettingToggle(title: 'Vibratsiya (Haptic)', icon: Icons.vibration_rounded, value: _hapticEnabled, onChanged: _toggleHaptic),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _SectionHeader(title: 'BIZNI QO\'LLAB-QUVVATLANG'),
            const SizedBox(height: 16),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SupportItem(icon: Icons.star_outline_rounded, title: 'Ilovani baholang', color: Colors.amber, onTap: () {}),
                  const Divider(color: Colors.white10, height: 1),
                  _SupportItem(icon: Icons.send_rounded, title: 'Telegram kanalimiz', color: const Color(0xFF24A1DE), onTap: () {}),
                  const Divider(color: Colors.white10, height: 1),
                  _SupportItem(icon: Icons.camera_alt_rounded, title: 'Instagram sahifamiz', color: Colors.pinkAccent, onTap: () {}),
                  const Divider(color: Colors.white10, height: 1),
                  _SupportItem(icon: Icons.card_membership_rounded, title: 'Orbita Premium a\'zolik', color: GamesTheme.accent, onTap: () {}),
                ],
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: BouncyButton(
                onTap: () => ref.read(authProvider.notifier).logout(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Text('TIZIMDAN CHIQISH', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: Text('Versiya $_appVersion', style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 10))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 2.0));
  }
}

class _SupportItem extends StatelessWidget {
  final IconData icon; final String title; final Color color; final VoidCallback onTap;
  const _SupportItem({required this.icon, required this.title, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white12, size: 14),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  final String title; final IconData icon; final bool value; final Function(bool) onChanged;
  const _SettingToggle({required this.title, required this.icon, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: GamesTheme.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
          Switch(
            value: value, onChanged: onChanged,
            activeColor: GamesTheme.primary,
            activeTrackColor: GamesTheme.primary.withOpacity(0.2),
            inactiveThumbColor: Colors.white24,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }
}
