import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/saving_goal_model.dart';
import '../models/transaction_model.dart';
import '../services/export_backup_service.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';

/// ============================================================================
/// DESIGN TOKENS — palet NoUploadPDF
/// Paper hangat (#F7F6F3 / #111113), permukaan datar (#FFFFFF / #1A1A1E),
/// border hairline 1px, satu hijau privacy (#007D50 / #5FD49E).
/// ============================================================================
class _Ui {
  final bool dark;
  const _Ui(this.dark);

  Color get canvas =>
      dark ? const Color(0xFF111113) : const Color(0xFFF7F6F3);
  Color get sheet =>
      dark ? const Color(0xFF1A1A1E) : const Color(0xFFFFFFFF);
  Color get tint =>
      dark ? const Color(0xFF161619) : const Color(0xFFFBFAF8);
  Color get chip =>
      dark ? const Color(0xFF2A2A30) : const Color(0xFFF1EFEA);

  Color get border =>
      dark ? const Color(0xFF2A2A30) : const Color(0xFFE4E2DC);
  Color get borderStrong =>
      dark ? const Color(0xFF3B3B42) : const Color(0xFFD6D3CB);
  Color get divider =>
      dark ? const Color(0xFF24242A) : const Color(0xFFEEECE7);

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
  bool _isDark = SettingsController.isDark;
  bool _useSystemTheme = false;
  bool _reminderEnabled = SettingsController.reminderEnabled;
  String _reminderTime = SettingsController.reminderTime;
  bool _isProcessing = false;

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
      setState(() {
        _useSystemTheme = true;
        _isDark = platformDark;
      });
      return;
    }

    final dark = option == _ThemeOption.dark;
    await SettingsController.toggleDarkMode(dark);
    setState(() {
      _useSystemTheme = false;
      _isDark = dark;
    });
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
    final ui = _Ui(_isDark);

    return Scaffold(
      backgroundColor: ui.canvas,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<Box<TransactionModel>>(
          valueListenable: HiveService.box.listenable(),
          builder: (context, txBox, _) {
            return ValueListenableBuilder<Box<SavingGoalModel>>(
              valueListenable: HiveService.goalsBox.listenable(),
              builder: (context, goalBox, _) {
                final txCount = txBox.length;
                final goalCount = goalBox.length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
                  children: [
                    // HEADER (gaya bersih seperti referensi)
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
                                  border:
                                      Border.all(color: ui.border, width: 1),
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

                    // SECTION 1: TAMPILAN (3 kartu preview System / Light / Dark)
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

                    // SECTION 2: PENGINGAT & KEBIASAAN (gaya grouped rows seperti Capture)
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
                          // Baris 1: Toggle Pengingat Harian
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

                          // Baris 2: Jam Pengingat (trailing value + chevron seperti "Quick >")
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
                                    _reminderEnabled
                                        ? _reminderTime
                                        : 'Nonaktif',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _reminderEnabled
                                          ? ui.gain
                                          : ui.muted,
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

                    // SECTION 3: DATA & LAPORAN (gaya grouped rows seperti App settings)
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
                          // Row 1: Status Penyimpanan Lokal (Privacy Green badge)
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

                          // Row 2: Export Laporan PDF
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

                          // Row 3: Backup Data (.json)
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

                          // Row 4: Restore Data
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
        return _MiniPhoneMockup(
          frameBg: const Color(0xFFF7F6F3),
          cardBg: const Color(0xFFFFFFFF),
          barColor: const Color(0xFFE4E2DC),
          islandColor: const Color(0xFF17171A),
        );
      case _ThemeOption.dark:
        return _MiniPhoneMockup(
          frameBg: const Color(0xFF1E1E22),
          cardBg: const Color(0xFF141417),
          barColor: const Color(0xFF2A2A30),
          islandColor: const Color(0xFF0B0B0D),
        );
      case _ThemeOption.system:
        return LayoutBuilder(
          builder: (context, constraints) {
            final halfWidth = constraints.maxWidth / 2;
            return Stack(
              children: [
                // Sisi kiri: Light
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
                // Sisi kanan: Dark
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
            // Dynamic island kecil
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