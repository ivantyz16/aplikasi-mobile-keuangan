import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/saving_goal_model.dart';
import '../models/transaction_model.dart';
import '../services/export_backup_service.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// ============================================================================
/// DESIGN TOKENS — palet NoUploadPDF
/// ============================================================================
class _Ui {
  final bool dark;
  const _Ui(this.dark);

  Color get canvas =>
      dark ? const Color(0xFF111113) : const Color(0xFFF7F6F3);
  Color get sheet =>
      dark ? const Color(0xFF1A1A1E) : const Color(0xFFFFFFFF);
  Color get divider =>
      dark ? const Color(0xFF24242A) : const Color(0xFFEEECE7);
  Color get border =>
      dark ? const Color(0xFF2A2A30) : const Color(0xFFE4E2DC);

  Color get ink =>
      dark ? const Color(0xFFEDEDEA) : const Color(0xFF17171A);
  Color get muted =>
      dark ? const Color(0xFF9E9D97) : const Color(0xFF6B6A64);
  Color get subtle =>
      dark ? const Color(0xFF8B8A84) : const Color(0xFF8A8880);

  Color get gain =>
      dark ? const Color(0xFF5FD49E) : const Color(0xFF007D50);
  Color get gainTint =>
      dark ? const Color(0xFF0F3B29) : const Color(0xFFDEF5E8);
  Color get loss =>
      dark ? const Color(0xFFFF6B7A) : const Color(0xFFB91C1C);
}

enum _ThemeOption { system, light, dark }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = false;
  bool _useSystemTheme = false;
  bool _reminderEnabled = false;
  String _reminderTime = '20:00';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
  }

  void _loadInitialSettings() {
    try {
      _isDark = SettingsController.isDark;
      _reminderEnabled = SettingsController.reminderEnabled;
      _reminderTime = SettingsController.reminderTime;
    } catch (e) {
      debugPrint('Settings load fallback: $e');
    }
  }

  _ThemeOption get _selectedTheme {
    if (_useSystemTheme) return _ThemeOption.system;
    return _isDark ? _ThemeOption.dark : _ThemeOption.light;
  }

  Future<void> _selectTheme(_ThemeOption option) async {
    if (option == _ThemeOption.system) {
      final platformDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
      await SettingsController.toggleDarkMode(platformDark);
      if (!mounted) return;
      setState(() {
        _useSystemTheme = true;
        _isDark = platformDark;
      });
      return;
    }

    final dark = option == _ThemeOption.dark;
    await SettingsController.toggleDarkMode(dark);
    if (!mounted) return;
    setState(() {
      _useSystemTheme = false;
      _isDark = dark;
    });
  }

  Future<void> _syncNotificationSchedule({
    required bool enabled,
    required String time,
  }) async {
    if (kIsWeb) return;
    try {
      if (enabled) {
        final parts = time.split(':');
        final hour = int.tryParse(parts[0]) ?? 20;
        final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        await NotificationService.scheduleDailyReminder(
          hour: hour,
          minute: minute,
        );
      } else {
        await NotificationService.cancelDailyReminder();
      }
    } catch (e) {
      debugPrint('Notification schedule error: $e');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final ui = _Ui(_isDark);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        content: Text(
          message,
          style: GoogleFonts.instrumentSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? ui.loss : ui.gain,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _pickReminderTime() async {
    final parts = _reminderTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await SettingsController.saveReminder(
        enabled: true,
        time: formatted,
      );
      await _syncNotificationSchedule(enabled: true, time: formatted);

      if (!mounted) return;
      setState(() {
        _reminderEnabled = true;
        _reminderTime = formatted;
      });
      _showSnack('Pengingat menabung diatur pukul $formatted');
    }
  }

  Future<void> _handleExportPdf() async {
    setState(() => _isProcessing = true);
    try {
      await ExportBackupService.exportFinancialPdf();
    } catch (e) {
      _showSnack('Gagal membuat PDF: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleBackup() async {
    setState(() => _isProcessing = true);
    try {
      await ExportBackupService.downloadBackupFile();
      _showSnack('File backup berhasil dibuat');
    } catch (e) {
      final jsonStr = ExportBackupService.createBackupJsonString();
      await Clipboard.setData(ClipboardData(text: jsonStr));
      _showSnack('Data backup disalin ke clipboard');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRestore() async {
    final ui = _Ui(_isDark);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ui.sheet,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ui.border, width: 1),
        ),
        title: Text(
          'Pulihkan Data Backup?',
          style: GoogleFonts.instrumentSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: ui.ink,
          ),
        ),
        content: Text(
          'Data transaksi dan target saat ini akan diganti dengan isi file backup (.json) yang kamu pilih.',
          style: GoogleFonts.instrumentSans(
            fontSize: 13,
            color: ui.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.instrumentSans(
                fontWeight: FontWeight.w600,
                color: ui.muted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Pilih File',
              style: GoogleFonts.instrumentSans(
                fontWeight: FontWeight.w600,
                color: ui.gain,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final restoredCount = await ExportBackupService.restoreFromJsonFile();
      if (restoredCount >= 0) {
        _showSnack('$restoredCount transaksi berhasil dipulihkan');
      }
    } catch (e) {
      _showSnack('Gagal restore: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool currentDark = Theme.of(context).brightness == Brightness.dark;
    if (_isDark != currentDark) {
      _isDark = currentDark;
    }
    final ui = _Ui(_isDark);

    return Scaffold(
      backgroundColor: ui.canvas,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<Box<TransactionModel>>(
          valueListenable: HiveService.box.listenable(),
          builder: (context, txBox, _) {
            final txCount = txBox.length;
            final goalCount = HiveService.goalsBox.isOpen
                ? HiveService.goalsBox.length
                : 0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
              children: [
                // HEADER
                Row(
                  children: [
                    if (Navigator.canPop(context)) ...[
                      Material(
                        color: ui.sheet,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ui.border, width: 1),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 15,
                              color: ui.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        'Pengaturan',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: ui.ink,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // SECTION 1: TAMPILAN
                Text(
                  'Tampilan',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ui.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ui.sheet,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ui.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AppearanceOptionCard(
                          label: 'Sistem',
                          mode: _ThemeOption.system,
                          selected: _selectedTheme == _ThemeOption.system,
                          ui: ui,
                          onTap: () => _selectTheme(_ThemeOption.system),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AppearanceOptionCard(
                          label: 'Terang',
                          mode: _ThemeOption.light,
                          selected: _selectedTheme == _ThemeOption.light,
                          ui: ui,
                          onTap: () => _selectTheme(_ThemeOption.light),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AppearanceOptionCard(
                          label: 'Gelap',
                          mode: _ThemeOption.dark,
                          selected: _selectedTheme == _ThemeOption.dark,
                          ui: ui,
                          onTap: () => _selectTheme(_ThemeOption.dark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),

                // SECTION 2: PENGINGAT
                Text(
                  'Pengingat',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ui.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: ui.sheet,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ui.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 20,
                              color: ui.ink,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Pengingat menabung',
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: ui.ink,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: _reminderEnabled,
                              activeThumbColor: Colors.white,
                              activeTrackColor: ui.gain,
                              onChanged: (val) async {
                                await SettingsController.saveReminder(
                                  enabled: val,
                                  time: _reminderTime,
                                );
                                await _syncNotificationSchedule(
                                  enabled: val,
                                  time: _reminderTime,
                                );
                                if (!mounted) return;
                                setState(() => _reminderEnabled = val);
                                if (val) {
                                  _showSnack(
                                      'Pengingat menabung aktif pukul $_reminderTime');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: ui.divider),
                      InkWell(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                        onTap: _pickReminderTime,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 20,
                                color: ui.ink,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Waktu pengingat',
                                  style: GoogleFonts.instrumentSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                    color: ui.ink,
                                  ),
                                ),
                              ),
                              Text(
                                _reminderEnabled ? _reminderTime : 'Nonaktif',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      _reminderEnabled ? ui.gain : ui.muted,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: ui.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),

                // SECTION 3: DATA & LAPORAN
                Text(
                  'Data & Laporan',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ui.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: ui.sheet,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ui.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 15),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 20,
                              color: ui.gain,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Penyimpanan lokal',
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: ui.ink,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ui.gainTint,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$txCount tx • $goalCount target',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: ui.gain,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: ui.divider),
                      InkWell(
                        onTap: _isProcessing ? null : _handleExportPdf,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15),
                          child: Row(
                            children: [
                              Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 20,
                                color: ui.ink,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Export laporan PDF',
                                  style: GoogleFonts.instrumentSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                    color: ui.ink,
                                  ),
                                ),
                              ),
                              Text(
                                'PDF',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.5,
                                  color: ui.muted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: ui.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: ui.divider),
                      InkWell(
                        onTap: _isProcessing ? null : _handleBackup,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 20,
                                color: ui.ink,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Backup data',
                                  style: GoogleFonts.instrumentSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                    color: ui.ink,
                                  ),
                                ),
                              ),
                              Text(
                                '.json',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.5,
                                  color: ui.muted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: ui.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: ui.divider),
                      InkWell(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                        onTap: _isProcessing ? null : _handleRestore,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15),
                          child: Row(
                            children: [
                              Icon(
                                Icons.restore_rounded,
                                size: 20,
                                color: ui.ink,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Pulihkan data',
                                  style: GoogleFonts.instrumentSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                    color: ui.ink,
                                  ),
                                ),
                              ),
                              Text(
                                'Import',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.5,
                                  color: ui.muted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: ui.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Semua data diproses secara lokal di perangkat ini.',
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12,
                      color: ui.subtle,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ============================================================================
/// APPEARANCE OPTION CARD (Thumbnail ponsel System / Light / Dark)
/// ============================================================================
class _AppearanceOptionCard extends StatelessWidget {
  final String label;
  final _ThemeOption mode;
  final bool selected;
  final _Ui ui;
  final VoidCallback onTap;

  const _AppearanceOptionCard({
    required this.label,
    required this.mode,
    required this.selected,
    required this.ui,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? ui.gain : ui.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  _buildPreview(),
                  if (selected)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: ui.gain,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.instrumentSans(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? ui.ink : ui.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    switch (mode) {
      case _ThemeOption.light:
        return const _MiniPhoneMockup(
          frameBg: Color(0xFFF7F6F3),
          cardBg: Color(0xFFFFFFFF),
          barColor: Color(0xFFE4E2DC),
          islandColor: Color(0xFF17171A),
        );
      case _ThemeOption.dark:
        return const _MiniPhoneMockup(
          frameBg: Color(0xFF1E1E22),
          cardBg: Color(0xFF141417),
          barColor: Color(0xFF2A2A30),
          islandColor: Color(0xFF0B0B0D),
        );
      case _ThemeOption.system:
        return LayoutBuilder(
          builder: (context, constraints) {
            final halfWidth = constraints.maxWidth / 2;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: halfWidth,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxWidth: constraints.maxWidth,
                      minWidth: constraints.maxWidth,
                      child: const _MiniPhoneMockup(
                        frameBg: Color(0xFFF7F6F3),
                        cardBg: Color(0xFFFFFFFF),
                        barColor: Color(0xFFE4E2DC),
                        islandColor: Color(0xFF17171A),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: halfWidth,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerRight,
                      maxWidth: constraints.maxWidth,
                      minWidth: constraints.maxWidth,
                      child: const _MiniPhoneMockup(
                        frameBg: Color(0xFF1E1E22),
                        cardBg: Color(0xFF141417),
                        barColor: Color(0xFF2A2A30),
                        islandColor: Color(0xFF0B0B0D),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
    }
  }
}

class _MiniPhoneMockup extends StatelessWidget {
  final Color frameBg;
  final Color cardBg;
  final Color barColor;
  final Color islandColor;

  const _MiniPhoneMockup({
    required this.frameBg,
    required this.cardBg,
    required this.barColor,
    required this.islandColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: frameBg,
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          children: [
            Container(
              width: 16,
              height: 4,
              decoration: BoxDecoration(
                color: islandColor,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 4,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.55),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}