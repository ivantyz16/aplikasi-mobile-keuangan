import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/saving_goal_model.dart';
import '../services/hive_service.dart';
import '../widgets/goal_allocation_sheet.dart';
import '../widgets/goal_form_sheet.dart';

final _rupiah =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

final _thousands = NumberFormat.decimalPattern('id_ID');

class _Ui {
  final bool dark;
  const _Ui(this.dark);
  factory _Ui.of(BuildContext c) =>
      _Ui(Theme.of(c).brightness == Brightness.dark);

  Color get canvas => dark ? const Color(0xFF111113) : const Color(0xFFF7F6F3);
  Color get sheet => dark ? const Color(0xFF1A1A1E) : const Color(0xFFFFFFFF);
  Color get tint => dark ? const Color(0xFF161619) : const Color(0xFFFBFAF8);
  Color get chip => dark ? const Color(0xFF2A2A30) : const Color(0xFFF1EFEA);
  Color get border => dark ? const Color(0xFF2A2A30) : const Color(0xFFE4E2DC);
  Color get borderStrong =>
      dark ? const Color(0xFF3B3B42) : const Color(0xFFD6D3CB);
  Color get divider => dark ? const Color(0xFF24242A) : const Color(0xFFEEECE7);
  Color get ink => dark ? const Color(0xFFEDEDEA) : const Color(0xFF17171A);
  Color get muted => dark ? const Color(0xFF9E9D97) : const Color(0xFF6B6A64);
  Color get subtle => dark ? const Color(0xFF8B8A84) : const Color(0xFF8A8880);
  Color get card => dark ? const Color(0xFF19191C) : const Color(0xFF17171A);
  Color get gain => dark ? const Color(0xFF5FD49E) : const Color(0xFF007D50);
  Color get gainTint =>
      dark ? const Color(0xFF0F3B29) : const Color(0xFFDEF5E8);
  Color get loss => dark ? const Color(0xFFFF6B7A) : const Color(0xFFB91C1C);
  static const onCard = Color(0xFFF7F6F3);
  static const onCardMuted = Color(0xFF9E9D97);
  static const accentOnInk = Color(0xFF56D298);
  static const onAccent = Color(0xFF17171A);
}

IconData _iconForGoal(String title) {
  final t = title.toLowerCase();
  if (t.contains('motor') || t.contains('servis')) {
    return Icons.two_wheeler_rounded;
  }
  if (t.contains('laptop') || t.contains('komputer')) {
    return Icons.laptop_mac_rounded;
  }
  if (t.contains('hp') || t.contains('phone') || t.contains('ponsel')) {
    return Icons.smartphone_rounded;
  }
  if (t.contains('liburan') || t.contains('jalan') || t.contains('tiket')) {
    return Icons.flight_takeoff_rounded;
  }
  if (t.contains('darurat')) return Icons.health_and_safety_rounded;
  if (t.contains('buku') || t.contains('kuliah') || t.contains('sekolah')) {
    return Icons.menu_book_rounded;
  }
  if (t.contains('kamera')) return Icons.camera_alt_rounded;
  if (t.contains('game') || t.contains('konsol')) {
    return Icons.sports_esports_rounded;
  }
  return Icons.savings_rounded;
}

bool _hasValidLocalImage(String? path) {
  if (kIsWeb || path == null || path.isEmpty) return false;
  return File(path).existsSync();
}

/// ============================================================================
/// GOALS SCREEN
/// ============================================================================
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  void _openSimulation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SavingSimulationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);

    return Scaffold(
      backgroundColor: ui.canvas,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(
          onPressed: () => GoalFormSheet.show(context),
          backgroundColor: ui.ink,
          foregroundColor: ui.canvas,
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            'Target Baru',
            style: GoogleFonts.instrumentSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<Box<SavingGoalModel>>(
          valueListenable: HiveService.goalsBox.listenable(),
          builder: (context, box, _) {
            final goals = box.values.toList()
              ..sort((a, b) {
                if (a.isCompleted != b.isCompleted) {
                  return a.isCompleted ? 1 : -1;
                }
                return b.createdAt.compareTo(a.createdAt);
              });

            final totalAllocated =
                goals.fold<double>(0, (s, g) => s + g.currentAmount);
            final achieved = goals.where((g) => g.isCompleted).length;
            final active = goals.length - achieved;

            final incomplete = goals.where((g) => !g.isCompleted).toList();
            final featured = incomplete.isNotEmpty ? incomplete.first : null;
            final others = goals.where((g) => g.id != featured?.id).toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                if (goals.isEmpty)
                  SliverToBoxAdapter(child: _buildEmpty(context))
                else ...[
                  SliverToBoxAdapter(
                    child: _buildSummaryBanner(
                      context,
                      totalAllocated: totalAllocated,
                      activeCount: active,
                      achievedCount: achieved,
                    ),
                  ),
                  if (featured != null)
                    SliverToBoxAdapter(
                      child: _FeaturedGoalCard(goal: featured),
                    ),
                  if (others.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _OtherGoalsList(goals: others),
                    ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 155)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ui = _Ui.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ui.sheet,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ui.border, width: 1),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: ui.ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target Tabungan',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: ui.ink,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tersimpan lokal di perangkat',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: ui.subtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // TOMBOL SIMULASI TABUNGAN
          Material(
            color: ui.sheet,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openSimulation(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ui.borderStrong, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      size: 16,
                      color: ui.gain,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Simulasi',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ui.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(
    BuildContext context, {
    required double totalAllocated,
    required int activeCount,
    required int achievedCount,
  }) {
    final ui = _Ui.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ui.tint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ui.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total dana dialokasikan',
              style: GoogleFonts.instrumentSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: ui.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _rupiah.format(totalAllocated),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 25,
                fontWeight: FontWeight.w600,
                color: ui.ink,
                letterSpacing: -0.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _countBadge(
                  '$activeCount aktif',
                  bg: ui.chip,
                  fg: ui.ink,
                  border: ui.border,
                ),
                const SizedBox(width: 8),
                _countBadge(
                  '$achievedCount tercapai',
                  bg: ui.gainTint,
                  fg: ui.gain,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _countBadge(
    String label, {
    required Color bg,
    required Color fg,
    Color? border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: border != null ? Border.all(color: border, width: 1) : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final ui = _Ui.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        decoration: BoxDecoration(
          color: ui.tint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ui.border, width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ui.sheet,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ui.border, width: 1),
              ),
              child: Icon(Icons.savings_outlined, size: 22, color: ui.ink),
            ),
            const SizedBox(height: 14),
            Text(
              'Belum ada target',
              style: GoogleFonts.instrumentSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ui.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Buat target pertama untuk mulai menyisihkan dana, atau coba simulasi menabung di atas.',
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: ui.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HALAMAN SIMULASI TABUNGAN
// =============================================================================

enum _SavingFrequency { daily, monthly }

class SavingSimulationScreen extends StatefulWidget {
  const SavingSimulationScreen({super.key});

  @override
  State<SavingSimulationScreen> createState() => _SavingSimulationScreenState();
}

class _SavingSimulationScreenState extends State<SavingSimulationScreen> {
  final _targetController = TextEditingController();
  final _depositController = TextEditingController();

  SavingGoalModel? _selectedGoal;
  _SavingFrequency _frequency = _SavingFrequency.daily;
  bool _initialized = false;

  @override
  void dispose() {
    _targetController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  double _parseAmount(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return double.tryParse(digits) ?? 0;
  }

  String _formatDigits(double value) {
    if (value <= 0) return '';
    return _thousands.format(value.round());
  }

  void _selectGoal(SavingGoalModel? goal) {
    setState(() {
      _selectedGoal = goal;
      if (goal != null) {
        _targetController.text = _formatDigits(goal.targetAmount);
      }
    });
  }

  void _setQuickDeposit(double amount) {
    setState(() {
      _depositController.text = _formatDigits(amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);

    return Scaffold(
      backgroundColor: ui.canvas,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<Box<SavingGoalModel>>(
          valueListenable: HiveService.goalsBox.listenable(),
          builder: (context, box, _) {
            final activeGoals =
                box.values.where((g) => !g.isCompleted).toList();

            // Pilih otomatis target aktif pertama bila ada saat halaman dibuka
            if (!_initialized) {
              _initialized = true;
              if (activeGoals.isNotEmpty) {
                _selectedGoal = activeGoals.first;
                _targetController.text =
                    _formatDigits(activeGoals.first.targetAmount);
              } else {
                _targetController.text = _formatDigits(5000000);
              }
              _depositController.text = _formatDigits(50000);
            }

            final targetAmount = _parseAmount(_targetController.text);
            final depositAmount = _parseAmount(_depositController.text);
            final alreadySaved = _selectedGoal != null
                ? _selectedGoal!.currentAmount.clamp(0.0, targetAmount)
                : 0.0;
            final remainingAmount =
                (targetAmount - alreadySaved).clamp(0.0, double.infinity);

            final isDaily = _frequency == _SavingFrequency.daily;
            final int unitsNeeded = (remainingAmount > 0 && depositAmount > 0)
                ? (remainingAmount / depositAmount).ceil()
                : 0;

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final estimatedDate = unitsNeeded <= 0
                ? today
                : isDaily
                    ? today.add(Duration(days: unitsNeeded))
                    : DateTime(today.year, today.month + unitsNeeded, today.day);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 48),
              children: [
                // HEADER
                Row(
                  children: [
                    Material(
                      color: ui.sheet,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ui.border, width: 1),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: ui.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Simulasi Tabungan',
                            style: GoogleFonts.instrumentSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: ui.ink,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hitung estimasi waktu pencapaian',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: ui.subtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. PILIH TARGET TABUNGAN
                Text(
                  'Pilih target tabungan',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: ui.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _GoalChoiceChip(
                        label: 'Input Manual',
                        icon: Icons.edit_outlined,
                        selected: _selectedGoal == null,
                        ui: ui,
                        onTap: () => _selectGoal(null),
                      ),
                      for (final g in activeGoals) ...[
                        const SizedBox(width: 8),
                        _GoalChoiceChip(
                          label: g.title,
                          icon: _iconForGoal(g.title),
                          selected: _selectedGoal?.id == g.id,
                          ui: ui,
                          onTap: () => _selectGoal(g),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. FORM NOMINAL TARGET & SETORAN RUTIN
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ui.sheet,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ui.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Input Nominal Target
                      Text(
                        'Nominal target',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: ui.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _RupiahInputField(
                        controller: _targetController,
                        hint: '5.000.000',
                        ui: ui,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_selectedGoal != null && alreadySaved > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 14, color: ui.gain),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Sudah terkumpul ${_rupiah.format(alreadySaved)} • Sisa ${_rupiah.format(remainingAmount)}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: ui.gain,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(
                            height: 1, thickness: 1, color: ui.divider),
                      ),

                      // Pilih Frekuensi: Per Hari atau Per Bulan
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Jumlah tabungan',
                              style: GoogleFonts.instrumentSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: ui.muted,
                              ),
                            ),
                          ),
                          _FrequencyToggle(
                            frequency: _frequency,
                            ui: ui,
                            onChanged: (f) => setState(() => _frequency = f),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _RupiahInputField(
                        controller: _depositController,
                        hint: isDaily ? '50.000' : '1.000.000',
                        ui: ui,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),

                      // Tombol nominal cepat
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (isDaily
                                ? [10000.0, 25000.0, 50000.0, 100000.0]
                                : [250000.0, 500000.0, 1000000.0, 2500000.0])
                            .map((val) {
                          return GestureDetector(
                            onTap: () => _setQuickDeposit(val),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: ui.tint,
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: ui.border, width: 1),
                              ),
                              child: Text(
                                _rupiah.format(val),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: ui.ink,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 3. HASIL ESTIMASI WAKTU & TANGGAL TERCAPAI (Ink Surface)
                _SimulationResultCard(
                  targetAmount: targetAmount,
                  remainingAmount: remainingAmount,
                  depositAmount: depositAmount,
                  unitsNeeded: unitsNeeded,
                  isDaily: isDaily,
                  estimatedDate: estimatedDate,
                  ui: ui,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GoalChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final _Ui ui;
  final VoidCallback onTap;

  const _GoalChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.ui,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? ui.ink : ui.sheet,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? ui.ink : ui.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? ui.canvas : ui.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.instrumentSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? ui.canvas : ui.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrequencyToggle extends StatelessWidget {
  final _SavingFrequency frequency;
  final _Ui ui;
  final ValueChanged<_SavingFrequency> onChanged;

  const _FrequencyToggle({
    required this.frequency,
    required this.ui,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, _SavingFrequency value) {
      final active = frequency == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? ui.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: GoogleFonts.instrumentSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: active ? ui.canvas : ui.muted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ui.tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ui.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('Per Hari', _SavingFrequency.daily),
          seg('Per Bulan', _SavingFrequency.monthly),
        ],
      ),
    );
  }
}

class _RupiahInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final _Ui ui;
  final ValueChanged<String> onChanged;

  const _RupiahInputField({
    required this.controller,
    required this.hint,
    required this.ui,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: ui.tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ui.border, width: 1),
      ),
      child: Row(
        children: [
          Text(
            'Rp',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ui.muted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _ThousandsSeparatorFormatter(),
              ],
              onChanged: onChanged,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ui.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  color: ui.subtle,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final number = int.tryParse(digits) ?? 0;
    final formatted = _thousands.format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _SimulationResultCard extends StatelessWidget {
  final double targetAmount;
  final double remainingAmount;
  final double depositAmount;
  final int unitsNeeded;
  final bool isDaily;
  final DateTime estimatedDate;
  final _Ui ui;

  const _SimulationResultCard({
    required this.targetAmount,
    required this.remainingAmount,
    required this.depositAmount,
    required this.unitsNeeded,
    required this.isDaily,
    required this.estimatedDate,
    required this.ui,
  });

  String _formatDurationLabel() {
    if (targetAmount <= 0) return '-';
    if (remainingAmount <= 0) return 'Target sudah tercapai';
    if (depositAmount <= 0) return 'Masukkan nominal setoran';

    if (isDaily) {
      if (unitsNeeded < 30) {
        return '$unitsNeeded hari';
      }
      final months = unitsNeeded ~/ 30;
      final days = unitsNeeded % 30;
      return days == 0
          ? '$unitsNeeded hari ($months bulan)'
          : '$unitsNeeded hari ($months bln $days hr)';
    } else {
      if (unitsNeeded < 12) {
        return '$unitsNeeded bulan';
      }
      final years = unitsNeeded ~/ 12;
      final months = unitsNeeded % 12;
      return months == 0
          ? '$unitsNeeded bulan ($years tahun)'
          : '$unitsNeeded bulan ($years thn $months bln)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = targetAmount > 0 && depositAmount > 0;
    final dateFormatted = isReady
        ? DateFormat('d MMMM yyyy', 'id_ID').format(estimatedDate)
        : '-';
    final dayNameFormatted = isReady
        ? DateFormat('EEEE', 'id_ID').format(estimatedDate)
        : 'Menunggu input';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _Ui.onCard.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'HASIL SIMULASI',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _Ui.accentOnInk,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                isDaily ? 'Setoran harian' : 'Setoran bulanan',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: _Ui.onCardMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Estimasi waktu pencapaian
          Text(
            'Estimasi waktu pencapaian',
            style: GoogleFonts.instrumentSans(
              fontSize: 12.5,
              color: _Ui.onCardMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDurationLabel(),
            style: GoogleFonts.instrumentSans(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _Ui.onCard,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Tanggal perkiraan tercapai
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _Ui.onCard.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _Ui.onCard.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _Ui.accentOnInk,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    size: 18,
                    color: _Ui.onAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perkiraan target tercapai',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 11.5,
                          color: _Ui.onCardMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormatted,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: _Ui.accentOnInk,
                        ),
                      ),
                      Text(
                        dayNameFormatted,
                        style: GoogleFonts.instrumentSans(
                          fontSize: 11,
                          color: _Ui.onCardMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isReady && remainingAmount > 0) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dana yang perlu dikumpulkan',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 12,
                    color: _Ui.onCardMuted,
                  ),
                ),
                Text(
                  _rupiah.format(remainingAmount),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _Ui.onCard,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Featured Goal Card (Target Utama - Ink Surface)
// =============================================================================

class _FeaturedGoalCard extends StatelessWidget {
  final SavingGoalModel goal;
  const _FeaturedGoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final hasImage = _hasValidLocalImage(goal.imagePath);
    final pct = (goal.progress * 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: GestureDetector(
        onTap: () => GoalAllocationSheet.show(context, goal),
        child: Container(
          height: 204,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: ui.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ui.border, width: 1),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.file(File(goal.imagePath!), fit: BoxFit.cover)
              else
                const _HairlineGridPattern(),
              if (hasImage)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xFF17171A).withValues(alpha: 0.72),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _Ui.onCard.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Prioritas aktif',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: _Ui.onCard,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _Ui.onCard.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _Ui.onCard.withValues(alpha: 0.14),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _iconForGoal(goal.title),
                            size: 17,
                            color: _Ui.onCard,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.instrumentSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _Ui.onCard,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _Ui.accentOnInk,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$pct%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _Ui.onAccent,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _rupiah.format(goal.currentAmount),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _Ui.onCard,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          ' / ${_rupiah.format(goal.targetAmount)}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: _Ui.onCardMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: goal.progress,
                        minHeight: 6,
                        backgroundColor: _Ui.onCard.withValues(alpha: 0.16),
                        valueColor:
                            const AlwaysStoppedAnimation(_Ui.accentOnInk),
                      ),
                    ),
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

class _HairlineGridPattern extends StatelessWidget {
  const _HairlineGridPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HairlineGridPainter());
  }
}

class _HairlineGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _Ui.onCard.withValues(alpha: 0.045)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// Other Goals List
// =============================================================================

class _OtherGoalsList extends StatelessWidget {
  final List<SavingGoalModel> goals;
  const _OtherGoalsList({required this.goals});

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              'Target lainnya (${goals.length})',
              style: GoogleFonts.instrumentSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: ui.muted,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: ui.sheet,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ui.border, width: 1),
            ),
            child: Column(
              children: [
                for (int i = 0; i < goals.length; i++) ...[
                  _GoalListRow(goal: goals[i]),
                  if (i < goals.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 78, right: 16),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: ui.divider,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalListRow extends StatelessWidget {
  final SavingGoalModel goal;
  const _GoalListRow({required this.goal});

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final hasImage = _hasValidLocalImage(goal.imagePath);
    final pct = (goal.progress * 100).toStringAsFixed(0);

    return InkWell(
      onTap: () => GoalAllocationSheet.show(context, goal),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(goal.imagePath!),
                          fit: BoxFit.cover),
                    )
                  : _MiniProgress(pct: pct, completed: goal.isCompleted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.instrumentSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ui.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (goal.isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: ui.gainTint,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Tercapai',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ui.gain,
                        ),
                      ),
                    )
                  else
                    Text(
                      'Kurang ${_rupiah.format(goal.remaining)}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: ui.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: goal.progress,
                      minHeight: 4,
                      backgroundColor: ui.border,
                      valueColor: AlwaysStoppedAnimation(
                        goal.isCompleted ? ui.gain : ui.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, size: 18, color: ui.subtle),
          ],
        ),
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final String pct;
  final bool completed;
  const _MiniProgress({required this.pct, required this.completed});

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final value = double.tryParse(pct)?.clamp(0, 100) ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: ui.tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ui.border, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: value / 100,
              strokeWidth: 2.5,
              backgroundColor: ui.border,
              valueColor: AlwaysStoppedAnimation(
                completed ? ui.gain : ui.ink,
              ),
            ),
          ),
          Text(
            completed ? '100%' : '$pct%',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: completed ? ui.gain : ui.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}