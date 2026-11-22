import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';

final _thousandsPattern = NumberFormat('#,##0', 'id_ID');

class TransactionFormSheet extends StatefulWidget {
  /// `null` = mode Tambah. Non-null = mode Edit (data terisi otomatis).
  final TransactionModel? initial;

  const TransactionFormSheet({super.key, this.initial});

  static Future<void> show(BuildContext context, {TransactionModel? initial}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionFormSheet(initial: initial),
    );
  }

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _titleCtrl;

  late bool _isIncome;
  late String _category;
  late DateTime _selectedDate;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _isIncome = init?.isIncome ?? false;

    // Validasi awal: pastikan _category ada di daftar yang sesuai tipe.
    final pool = categoriesFor(_isIncome).map((c) => c.name).toList();
    _category = (init != null && pool.contains(init.category))
        ? init.category
        : pool.first;

    _selectedDate = init?.date ?? DateTime.now();

    _amountCtrl = TextEditingController(
      text: init != null
          ? _thousandsPattern.format(init.amount.round())
          : '',
    );
    _titleCtrl = TextEditingController(text: init?.title ?? '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  double get _parsedAmount {
    final digits = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(digits) ?? 0;
  }

  void _setType(bool isIncome) {
    if (_isIncome == isIncome) return;
    setState(() {
      _isIncome = isIncome;
      // Reset kategori ke default tipe baru.
      _category = categoriesFor(isIncome).first.name;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    final amount = _parsedAmount;
    if (amount <= 0) {
      _toast('Nominal harus lebih dari 0');
      return;
    }
    setState(() => _saving = true);

    final title = _titleCtrl.text.trim().isEmpty
        ? _category
        : _titleCtrl.text.trim();

    final tx = TransactionModel(
      id: widget.initial?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      isIncome: _isIncome,
      category: _category,
      date: _selectedDate,
    );

    await HiveService.add(tx);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteInEditMode() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus transaksi?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          widget.initial!.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Hapus',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AppColors.expense,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await HiveService.delete(widget.initial!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
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
              const SizedBox(height: 16),

              Text(
                _isEdit ? 'Edit Transaksi' : 'Catat Transaksi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 16),

              _buildTypeSwitcher(),
              const SizedBox(height: 20),

              _buildAmountHero(),
              const SizedBox(height: 20),

              Text(
                'Kategori',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _buildCategoryChips(),
              const SizedBox(height: 20),

              _buildTitleField(),
              const SizedBox(height: 10),
              _buildDateField(),
              const SizedBox(height: 22),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _isEdit ? 'Perbarui Transaksi' : 'Simpan Transaksi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _saving ? null : _deleteInEditMode,
                  child: Text(
                    'Hapus Transaksi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.expense,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildTypeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _typeTab('Pengeluaran', !_isIncome, () => _setType(false)),
          ),
          Expanded(
            child: _typeTab('Pemasukan', _isIncome, () => _setType(true)),
          ),
        ],
      ),
    );
  }

  Widget _typeTab(String label, bool active, VoidCallback onTap) {
    // Warna aktif mengikuti tipe: expense → terracotta soft tint, income → dark forest.
    Color activeBg;
    Color activeBorder;
    Color activeText;

    if (label == 'Pemasukan') {
      activeBg = AppColors.primary;
      activeBorder = AppColors.primary;
      activeText = Colors.white;
    } else {
      activeBg = const Color(0xFFFBEAE6); // soft tint terracotta
      activeBorder = AppColors.expense;
      activeText = AppColors.expense;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: active
              ? Border.all(color: activeBorder, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? activeText : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountHero() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Rp',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
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
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.border,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final cats = categoriesFor(_isIncome);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cats.map((c) {
        final active = _category == c.name;

        // Warna aktif: income → dark forest + putih; expense → soft mint + border emerald.
        final Color bg;
        final Color? border;
        final Color fg;

        if (active) {
          if (_isIncome) {
            bg = AppColors.primary;
            border = null;
            fg = Colors.white;
          } else {
            bg = AppColors.softMint;
            border = AppColors.accent;
            fg = AppColors.textPrimary;
          }
        } else {
          bg = AppColors.surface;
          border = AppColors.border;
          fg = AppColors.textPrimary;
        }

        return GestureDetector(
          onTap: () => setState(() => _category = c.name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: border ?? Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(c.icon, size: 14, color: fg),
                const SizedBox(width: 6),
                Text(
                  c.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleCtrl,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Judul (opsional) — mis. Nasi goreng kantin',
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    final label = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_selectedDate);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Format ribuan otomatis saat mengetik (contoh: 15000 → 15.000).
class _ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final number = int.tryParse(digits);
    if (number == null) return oldValue;
    final formatted = _thousandsPattern.format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}