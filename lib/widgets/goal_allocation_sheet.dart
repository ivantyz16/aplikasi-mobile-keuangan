import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/saving_goal_model.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';

final _rupiah =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _thousands = NumberFormat('#,##0', 'id_ID');

class GoalAllocationSheet extends StatefulWidget {
  final SavingGoalModel goal;

  const GoalAllocationSheet({super.key, required this.goal});

  static Future<void> show(BuildContext context, SavingGoalModel goal) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoalAllocationSheet(goal: goal),
    );
  }

  @override
  State<GoalAllocationSheet> createState() => _GoalAllocationSheetState();
}

class _GoalAllocationSheetState extends State<GoalAllocationSheet> {
  final _amountCtrl = TextEditingController();
  bool _isWithdraw = false;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _parsed {
    final digits = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(digits) ?? 0;
  }

  void _fill(double value) {
    if (value <= 0) return;
    final formatted = _thousands.format(value.round());
    _amountCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _confirm(SavingGoalModel goal) async {
    final amount = _parsed;
    if (amount <= 0) return _toast('Nominal harus lebih dari 0');

    if (_isWithdraw && amount > goal.currentAmount) {
      return _toast('Melebihi saldo target (${_rupiah.format(goal.currentAmount)})');
    }
    if (!_isWithdraw && goal.isCompleted) {
      return _toast('Target sudah tercapai');
    }

    setState(() => _saving = true);
    if (_isWithdraw) {
      await HiveService.withdrawFromGoal(goal, amount);
    } else {
      // Batasi agar tidak melebihi target jika user input > remaining.
      final finalAmount = amount.clamp(0.0, goal.remaining);
      await HiveService.allocateToGoal(goal, finalAmount);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteGoal(SavingGoalModel goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus target?',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        content: Text(
          goal.currentAmount > 0
              ? 'Saldo ${_rupiah.format(goal.currentAmount)} akan dikembalikan ke saldo utama.'
              : 'Target ini akan dihapus permanen.',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: AppColors.expense)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HiveService.deleteGoal(goal);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 12, color: Colors.white)),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<SavingGoalModel>>(
      valueListenable: HiveService.goalsBox.listenable(),
      builder: (context, box, _) {
        final goal = box.get(widget.goal.id) ?? widget.goal;
        return _buildContent(goal);
      },
    );
  }

  Widget _buildContent(SavingGoalModel goal) {
    final media = MediaQuery.of(context);
    final pct = (goal.progress * 100).toStringAsFixed(0);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header dengan tombol hapus
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _deleteGoal(goal),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppColors.expense),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.softMint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _rupiah.format(goal.currentAmount),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        Text(
                          ' / ${_rupiah.format(goal.targetAmount)}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: goal.isCompleted
                                ? AppColors.accent
                                : AppColors.primary,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            goal.isCompleted ? 'Tercapai' : '$pct%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: goal.progress,
                        minHeight: 6,
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation(
                            goal.isCompleted
                                ? AppColors.accent
                                : AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Mode switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: _modeTab('Tambah Tabungan', !_isWithdraw,
                            () => setState(() => _isWithdraw = false))),
                    Expanded(
                        child: _modeTab('Tarik Dana', _isWithdraw,
                            () => setState(() => _isWithdraw = true))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nominal
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text('Rp',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _ThousandsInputFormatter(),
                        ],
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: GoogleFonts.jetBrainsMono(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.border),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Quick chips
              _buildQuickChips(goal),
              const SizedBox(height: 20),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _confirm(goal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isWithdraw ? AppColors.expense : AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _isWithdraw ? 'Tarik Dana' : 'Tambah Tabungan',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? (label == 'Tarik Dana' ? AppColors.expense : AppColors.primary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChips(SavingGoalModel goal) {
    final chips = <(String, double)>[
      ('+10rb', 10000),
      ('+20rb', 20000),
      ('+50rb', 50000),
      ('+100rb', 100000),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chips)
          GestureDetector(
            onTap: () => _fill(c.$2),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Text(
                c.$1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        if (!_isWithdraw && !goal.isCompleted && goal.remaining > 0)
          GestureDetector(
            onTap: () => _fill(goal.remaining),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.softMint,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.accent, width: 1),
              ),
              child: Text(
                'Lunasi Sisa',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final formatted = _thousands.format(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}