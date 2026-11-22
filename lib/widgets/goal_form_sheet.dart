import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/saving_goal_model.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';

final _thousands = NumberFormat('#,##0', 'id_ID');

class GoalFormSheet extends StatefulWidget {
  final SavingGoalModel? initial;

  const GoalFormSheet({super.key, this.initial});

  static Future<void> show(BuildContext context, {SavingGoalModel? initial}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoalFormSheet(initial: initial),
    );
  }

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _targetCtrl;

  String? _imagePath;
  DateTime? _deadline;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _targetCtrl = TextEditingController(
      text: init != null ? _thousands.format(init.targetAmount.round()) : '',
    );
    _imagePath = init?.imagePath;
    _deadline = init?.deadline;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  double get _parsedTarget {
    final digits = _targetCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(digits) ?? 0;
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) setState(() => _imagePath = picked.path);
    } catch (_) {
      if (mounted) _toast('Gagal memilih gambar');
    }
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final target = _parsedTarget;
    if (title.isEmpty) return _toast('Nama target wajib diisi');
    if (target <= 0) return _toast('Nominal target harus lebih dari 0');

    setState(() => _saving = true);
    final existing = widget.initial;
    final goal = existing != null
        ? existing.copyWith(
            title: title,
            targetAmount: target,
            imagePath: _imagePath,
            clearImage: _imagePath == null,
            deadline: _deadline,
            clearDeadline: _deadline == null,
          )
        : SavingGoalModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title,
            targetAmount: target,
            createdAt: DateTime.now(),
            imagePath: _imagePath,
            deadline: _deadline,
          );

    if (existing != null) {
      await HiveService.updateGoal(goal);
    } else {
      await HiveService.addGoal(goal);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await _confirm(
      'Hapus target?',
      widget.initial!.currentAmount > 0
          ? 'Saldo target akan dikembalikan ke saldo utama.'
          : 'Target ini akan dihapus permanen.',
    );
    if (ok != true) return;
    await HiveService.deleteGoal(widget.initial!);
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool?> _confirm(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        content: Text(body,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: AppColors.textSecondary)),
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
                _isEdit ? 'Edit Target' : 'Target Baru',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildImagePicker(),
              const SizedBox(height: 16),
              _buildTitleField(),
              const SizedBox(height: 10),
              _buildTargetField(),
              const SizedBox(height: 10),
              _buildDeadlineField(),
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
                    _isEdit ? 'Perbarui Target' : 'Simpan Target',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _saving ? null : _delete,
                  child: Text('Hapus Target',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.expense)),
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

  Widget _buildImagePicker() {
    final hasImage =
        _imagePath != null && File(_imagePath!).existsSync();

    return GestureDetector(
      onTap: hasImage ? null : _pickImage,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage ? AppColors.border : const Color(0xFFC5D4CC),
            width: hasImage ? 1 : 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(_imagePath!),
                      fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _miniBtn(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Ganti',
                          onTap: _pickImage,
                        ),
                        const SizedBox(width: 6),
                        _miniBtn(
                          icon: Icons.close_rounded,
                          label: 'Hapus',
                          onTap: () =>
                              setState(() => _imagePath = null),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.softMint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined,
                        size: 20, color: AppColors.accent),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tambah foto barang impian',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Opsional — dari galeri',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _miniBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.85),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return _field(
      controller: _titleCtrl,
      hint: 'Nama target — mis. Beli Laptop Kuliah',
      keyboard: TextInputType.text,
    );
  }

  Widget _buildTargetField() {
    return _field(
      controller: _targetCtrl,
      hint: 'Nominal target (Rp)',
      keyboard: TextInputType.number,
      digitsOnly: true,
      mono: true,
    );
  }

  Widget _buildDeadlineField() {
    final label = _deadline == null
        ? 'Tenggat (opsional)'
        : DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_deadline!);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickDeadline,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _deadline == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (_deadline != null)
              GestureDetector(
                onTap: () => setState(() => _deadline = null),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textSecondary),
              )
            else
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboard,
    bool digitsOnly = false,
    bool mono = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: digitsOnly
          ? [
              FilteringTextInputFormatter.digitsOnly,
              _ThousandsInputFormatter(),
            ]
          : null,
      style: mono
          ? GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            )
          : GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
      decoration: InputDecoration(
        hintText: hint,
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