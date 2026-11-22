import 'dart:ui' show FontFeature;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/saving_goal_model.dart';
import '../models/transaction_model.dart';
import '../services/hive_service.dart';
import '../utils/categories.dart';
import '../utils/statistics_helper.dart';

final NumberFormat _rupiahStat =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

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
  Color get divider => dark ? const Color(0xFF24242A) : const Color(0xFFEEECE7);
  Color get ink => dark ? const Color(0xFFEDEDEA) : const Color(0xFF17171A);
  Color get muted => dark ? const Color(0xFF9E9D97) : const Color(0xFF6B6A64);
  Color get subtle => dark ? const Color(0xFF8B8A84) : const Color(0xFF8A8880);
  Color get card => dark ? const Color(0xFF19191C) : const Color(0xFF17171A);
  Color get gain => dark ? const Color(0xFF5FD49E) : const Color(0xFF007D50);
  Color get gainTint =>
      dark ? const Color(0xFF0F3B29) : const Color(0xFFDEF5E8);
  Color get loss => dark ? const Color(0xFFFF6B7A) : const Color(0xFFB91C1C);
  Color get lossTint =>
      dark ? const Color(0xFF3A161B) : const Color(0xFFFEE2E2);
  Color get warn => dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
  Color get warnTint =>
      dark ? const Color(0xFF36280E) : const Color(0xFFFEF3C7);
  static const onCard = Color(0xFFF7F6F3);
  static const onCardMuted = Color(0xFF9E9D97);
  static const accentOnInk = Color(0xFF56D298);
  static const onAccent = Color(0xFF17171A);
}

class _BudgetStatus {
  final String category;
  final double limit;
  final double spent;

  const _BudgetStatus({
    required this.category,
    required this.limit,
    required this.spent,
  });

  double get ratio => limit > 0 ? (spent / limit) : 0.0;
  double get progress => ratio.clamp(0.0, 1.0);
  double get remaining => limit - spent;
  bool get isExceeded => spent > limit;
  bool get isNearLimit => !isExceeded && ratio >= 0.8;
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const String _budgetBoxName = 'monthly_budgets';

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isIncomeReport = false;
  bool _isYearly = false;
  String _trendMode = 'savings';
  int _touchedTrendIndex = 6;

  Box<double>? _budgetBox;

  @override
  void initState() {
    super.initState();
    _initBudgetBox();
  }

  Future<void> _initBudgetBox() async {
    final box = Hive.isBoxOpen(_budgetBoxName)
        ? Hive.box<double>(_budgetBoxName)
        : await Hive.openBox<double>(_budgetBoxName);
    if (mounted) {
      setState(() => _budgetBox = box);
    }
  }

  String _formatMonthShort(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatMonthOnly(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return months[date.month - 1];
  }

  List<String> _expenseCategoryOptions(Box<double> box) {
    final set = <String>{
      ...allCategoryNames.where((name) {
        final lower = name.toLowerCase();
        return !lower.contains('gaji') &&
            !lower.contains('bonus') &&
            !lower.contains('investasi') &&
            !lower.contains('hadiah');
      }),
      ...box.keys.map((k) => k.toString()),
    };
    if (set.isEmpty) {
      set.addAll(['Makanan', 'Transportasi', 'Hiburan', 'Tagihan', 'Belanja']);
    }
    return set.toList();
  }

  // ---------------------------------------------------------------------------
  // Modal Tambah / Edit Batas Anggaran Bulanan
  // ---------------------------------------------------------------------------

  Future<void> _showBudgetSheet({
    String? initialCategory,
    double? initialLimit,
  }) async {
    final box = _budgetBox;
    if (box == null) return;

    final options = _expenseCategoryOptions(box);
    String selectedCategory = initialCategory ?? options.first;
    final amountCtrl = TextEditingController(
      text: initialLimit != null ? initialLimit.toStringAsFixed(0) : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final ui = _Ui.of(ctx);
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 24),
              decoration: BoxDecoration(
                color: ui.sheet,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(top: BorderSide(color: ui.border, width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ui.border,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          initialCategory != null
                              ? 'Ubah Batas Anggaran'
                              : 'Atur Batas Anggaran',
                          style: GoogleFonts.instrumentSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: ui.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      if (initialCategory != null)
                        GestureDetector(
                          onTap: () async {
                            await box.delete(initialCategory);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: ui.lossTint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Hapus',
                              style: GoogleFonts.instrumentSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ui.loss,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Peringatan aktif saat pemakaian mencapai 80% dari batas bulanan.',
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12.5,
                      color: ui.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Kategori pengeluaran',
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: ui.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((cat) {
                      final active = cat == selectedCategory;
                      return GestureDetector(
                        onTap: initialCategory != null
                            ? null
                            : () {
                                setSheetState(() {
                                  selectedCategory = cat;
                                  final existing = box.get(cat);
                                  if (existing != null &&
                                      amountCtrl.text.isEmpty) {
                                    amountCtrl.text =
                                        existing.toStringAsFixed(0);
                                  }
                                });
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: active ? ui.ink : ui.tint,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active ? ui.ink : ui.border,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                iconForCategory(cat),
                                size: 14,
                                color: active ? ui.canvas : ui.ink,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat,
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 12.5,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: active ? ui.canvas : ui.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Batas maksimal per bulan (Rp)',
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: ui.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ui.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      prefixStyle: GoogleFonts.jetBrainsMono(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: ui.muted,
                      ),
                      hintText: '300000',
                      hintStyle: GoogleFonts.jetBrainsMono(
                        fontSize: 15,
                        color: ui.subtle,
                      ),
                      filled: true,
                      fillColor: ui.tint,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: ui.border, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: ui.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: ui.ink, width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Preset nominal cepat
                  Row(
                    children: [50000, 100000, 300000, 500000].map((preset) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: preset == 500000 ? 0 : 6),
                          child: GestureDetector(
                            onTap: () {
                              amountCtrl.text = preset.toString();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: ui.chip,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${preset ~/ 1000}rb',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: ui.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      final parsed = double.tryParse(amountCtrl.text.trim());
                      if (parsed == null || parsed <= 0) return;
                      await box.put(selectedCategory, parsed);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: ui.ink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Simpan Anggaran',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ui.canvas,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final budgetBox = _budgetBox;

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
                if (budgetBox == null) {
                  return _buildContent(
                    context,
                    txBox.values.toList(),
                    goalBox.values.toList(),
                    const {},
                  );
                }
                return ValueListenableBuilder<Box<double>>(
                  valueListenable: budgetBox.listenable(),
                  builder: (context, bBox, _) {
                    final budgets = <String, double>{};
                    for (final key in bBox.keys) {
                      final val = bBox.get(key);
                      if (val != null && val > 0) {
                        budgets[key.toString()] = val;
                      }
                    }
                    return _buildContent(
                      context,
                      txBox.values.toList(),
                      goalBox.values.toList(),
                      budgets,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<TransactionModel> transactions,
    List<SavingGoalModel> goals,
    Map<String, double> budgets,
  ) {
    final ui = _Ui.of(context);

    double totalBalance = 0;
    double monthIncome = 0;
    double monthExpense = 0;
    final spentByCategory = <String, double>{};

    for (final tx in transactions) {
      totalBalance += tx.isIncome ? tx.amount : -tx.amount;
      if (tx.date.year == _selectedMonth.year &&
          tx.date.month == _selectedMonth.month) {
        if (tx.isIncome) {
          monthIncome += tx.amount;
        } else {
          monthExpense += tx.amount;
          spentByCategory[tx.category] =
              (spentByCategory[tx.category] ?? 0) + tx.amount;
        }
      }
    }

    final budgetStatuses = budgets.entries.map((e) {
      return _BudgetStatus(
        category: e.key,
        limit: e.value,
        spent: spentByCategory[e.key] ?? 0.0,
      );
    }).toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));

    final double savingRatio = monthIncome > 0
        ? (((monthIncome - monthExpense) / monthIncome) * 100).clamp(0.0, 100.0)
        : 0.0;

    final int completedGoals = goals.where((g) => g.isCompleted).length;

    final categoryStats = StatisticsHelper.getCategoryBreakdown(
      transactions: transactions,
      selectedMonth: _selectedMonth,
      isYearly: _isYearly,
      isIncome: _isIncomeReport,
    );

    final cashflowDist = StatisticsHelper.getCashflowDistribution(
      transactions: transactions,
      goals: goals,
      selectedMonth: _selectedMonth,
      isYearly: _isYearly,
    );

    final trendPoints = StatisticsHelper.get7MonthsTrend(
      transactions: transactions,
      anchorMonth: _selectedMonth,
      mode: _trendMode,
    );

    final activePoint =
        trendPoints[_touchedTrendIndex.clamp(0, trendPoints.length - 1)];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 155),
      children: [
        _buildTopBar(context),
        const SizedBox(height: 18),
        _buildHeroCard(
          totalBalance: totalBalance,
          savingRatio: savingRatio,
          completedGoals: completedGoals,
          totalGoals: goals.length,
          netMonth: monthIncome - monthExpense,
        ),
        const SizedBox(height: 20),

        // FITUR BARU: ANGGARAN BULANAN & PERINGATAN
        _buildMonthlyBudgetSection(context, budgetStatuses),
        const SizedBox(height: 24),

        Divider(height: 1, thickness: 1, color: ui.divider),
        const SizedBox(height: 20),
        _buildControlBar(context),
        const SizedBox(height: 20),
        _buildDualCharts(context, categoryStats, cashflowDist),
        const SizedBox(height: 24),
        Divider(height: 1, thickness: 1, color: ui.divider),
        const SizedBox(height: 20),
        _buildTrendSection(context, trendPoints, activePoint),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Top Bar
  // ---------------------------------------------------------------------------

  Widget _buildTopBar(BuildContext context) {
    final ui = _Ui.of(context);

    return Row(
      children: [
        if (Navigator.canPop(context)) ...[
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
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
          child: Text(
            'Statistik',
            style: GoogleFonts.instrumentSans(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: ui.ink,
              letterSpacing: -0.6,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: ui.sheet,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ui.border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() {
                  _selectedMonth =
                      DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                }),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: ui.ink,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  _formatMonthShort(_selectedMonth),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: ui.ink,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() {
                  _selectedMonth =
                      DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                }),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: ui.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Hero Card (Ink Surface)
  // ---------------------------------------------------------------------------

  Widget _buildHeroCard({
    required double totalBalance,
    required double savingRatio,
    required int completedGoals,
    required int totalGoals,
    required double netMonth,
  }) {
    final ui = _Ui.of(context);
    final netSign = netMonth >= 0 ? '+' : '-';
    final netFormatted = '$netSign${_rupiahStat.format(netMonth.abs())}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rasio tabungan',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: _Ui.onCardMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _Ui.accentOnInk,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${savingRatio.toStringAsFixed(0)}% tersimpan',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _Ui.onAccent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Saldo bersih',
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: _Ui.onCardMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _rupiahStat.format(totalBalance),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: _Ui.onCard,
                      letterSpacing: -0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target tercapai: $completedGoals / $totalGoals',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: _Ui.onCardMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'Selisih: $netFormatted',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: netMonth >= 0
                      ? _Ui.accentOnInk
                      : const Color(0xFFFF6B7A),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section Anggaran Bulanan & Peringatan
  // ---------------------------------------------------------------------------

  Widget _buildMonthlyBudgetSection(
    BuildContext context,
    List<_BudgetStatus> statuses,
  ) {
    final ui = _Ui.of(context);
    final exceededList = statuses.where((s) => s.isExceeded).toList();
    final nearList = statuses.where((s) => s.isNearLimit).toList();
    final hasAlert = exceededList.isNotEmpty || nearList.isNotEmpty;

    final totalBudget = statuses.fold<double>(0, (s, e) => s + e.limit);
    final totalSpentInBudget = statuses.fold<double>(0, (s, e) => s + e.spent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Anggaran Bulanan',
                    style: GoogleFonts.instrumentSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ui.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Batas pengeluaran ${_formatMonthOnly(_selectedMonth)}',
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12,
                      color: ui.muted,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showBudgetSheet(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: ui.ink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 15, color: ui.canvas),
                    const SizedBox(width: 4),
                    Text(
                      'Atur Batas',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ui.canvas,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Banner Peringatan Otomatis jika >= 80% atau melebihi batas
        if (hasAlert) ...[
          _buildBudgetAlertBanner(ui, exceededList, nearList),
          const SizedBox(height: 12),
        ],

        if (statuses.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ui.tint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ui.border, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ui.sheet,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ui.border, width: 1),
                  ),
                  child: Icon(Icons.tune_rounded, size: 18, color: ui.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Belum ada batas anggaran',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: ui.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tetapkan batas seperti Makanan Rp 300.000 agar pengeluaran tetap terkendali.',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 12,
                          color: ui.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: ui.sheet,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ui.border, width: 1),
            ),
            child: Column(
              children: [
                // Ringkasan Total Terpakai vs Total Anggaran
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total terpakai',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: ui.muted,
                        ),
                      ),
                      Text(
                        '${_rupiahStat.format(totalSpentInBudget)} / ${_rupiahStat.format(totalBudget)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: totalSpentInBudget > totalBudget
                              ? ui.loss
                              : ui.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: ui.divider),
                for (int i = 0; i < statuses.length; i++) ...[
                  _buildBudgetRow(ui, statuses[i]),
                  if (i < statuses.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 58, right: 14),
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
    );
  }

  Widget _buildBudgetAlertBanner(
    _Ui ui,
    List<_BudgetStatus> exceeded,
    List<_BudgetStatus> near,
  ) {
    final isCritical = exceeded.isNotEmpty;
    final bg = isCritical ? ui.lossTint : ui.warnTint;
    final fg = isCritical ? ui.loss : ui.warn;

    final names = isCritical
        ? exceeded.map((e) => e.category).join(', ')
        : near.map((e) => e.category).join(', ');

    final message = isCritical
        ? 'Anggaran $names telah melebihi batas bulanan.'
        : 'Anggaran $names sudah terpakai lebih dari 80%.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            isCritical
                ? Icons.error_outline_rounded
                : Icons.warning_amber_rounded,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.instrumentSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetRow(_Ui ui, _BudgetStatus item) {
    final pct = (item.ratio * 100).round();
    final Color barColor = item.isExceeded
        ? ui.loss
        : (item.isNearLimit ? ui.warn : ui.gain);
    final Color badgeBg = item.isExceeded
        ? ui.lossTint
        : (item.isNearLimit ? ui.warnTint : ui.gainTint);

    final String statusLabel = item.isExceeded
        ? 'Lewat ${_rupiahStat.format(item.remaining.abs())}'
        : (item.isNearLimit
            ? 'Hampir habis ($pct%)'
            : 'Sisa ${_rupiahStat.format(item.remaining)}');

    return InkWell(
      onTap: () => _showBudgetSheet(
        initialCategory: item.category,
        initialLimit: item.limit,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: ui.tint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ui.border, width: 1),
              ),
              child: Icon(
                iconForCategory(item.category),
                size: 16,
                color: ui.ink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.category,
                          style: GoogleFonts.instrumentSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: ui.ink,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: barColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 5,
                      backgroundColor: ui.border,
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Terpakai ${_rupiahStat.format(item.spent)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: ui.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'Batas ${_rupiahStat.format(item.limit)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ui.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Control Bar & Dual Charts
  // ---------------------------------------------------------------------------

  Widget _buildControlBar(BuildContext context) {
    final ui = _Ui.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isIncomeReport = !_isIncomeReport),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: ui.sheet,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: ui.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isIncomeReport ? ui.gain : ui.loss,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isIncomeReport ? 'Pemasukan' : 'Pengeluaran',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ui.ink,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: ui.muted,
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: ui.chip,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: ui.border, width: 1),
          ),
          child: Row(
            children: [
              _periodToggle(ui, 'Bulanan', !_isYearly, () {
                setState(() => _isYearly = false);
              }),
              _periodToggle(ui, 'Tahunan', _isYearly, () {
                setState(() => _isYearly = true);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodToggle(
    _Ui ui,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? ui.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: GoogleFonts.instrumentSans(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? ui.canvas : ui.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildDualCharts(
    BuildContext context,
    List<CategoryStat> categoryStats,
    Map<String, double> cashflowDist,
  ) {
    final ui = _Ui.of(context);
    final topPercent =
        categoryStats.isNotEmpty ? categoryStats.first.percentage.round() : 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kiri (52%): Donut Chart Kategori
        Expanded(
          flex: 52,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 138,
                child: categoryStats.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada data',
                          style: GoogleFonts.instrumentSans(
                            fontSize: 12,
                            color: ui.muted,
                          ),
                        ),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 42,
                              startDegreeOffset: -90,
                              sections: [
                                for (final stat in categoryStats)
                                  PieChartSectionData(
                                    value: stat.percentage,
                                    color: stat.color,
                                    radius: 16,
                                    showTitle: false,
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '$topPercent%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: ui.ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              if (categoryStats.isEmpty)
                Text(
                  'Belum ada transaksi pada periode ini.',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 11.5,
                    color: ui.muted,
                  ),
                )
              else
                for (final stat in categoryStats.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: stat.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stat.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.instrumentSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: ui.muted,
                            ),
                          ),
                        ),
                        Text(
                          '${stat.percentage.round()}%',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: ui.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(width: 18),

        // Kanan (48%): Pie Chart Arus Kas
        Expanded(
          flex: 48,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isYearly
                    ? 'Tahun ${_selectedMonth.year}'
                    : _formatMonthOnly(_selectedMonth),
                style: GoogleFonts.instrumentSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ui.ink,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: (cashflowDist['income'] == 0 &&
                        cashflowDist['expense'] == 0 &&
                        cashflowDist['savings'] == 0)
                    ? Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ui.chip,
                            border: Border.all(color: ui.border, width: 1),
                          ),
                        ),
                      )
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 0,
                          startDegreeOffset: -110,
                          sections: [
                            PieChartSectionData(
                              value: cashflowDist['income'] ?? 0,
                              color: ui.gain,
                              radius: 50,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: cashflowDist['expense'] ?? 0,
                              color: ui.loss,
                              radius: 46,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: cashflowDist['savings'] ?? 0,
                              color: ui.ink,
                              radius: 42,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              _legendRow(
                ui,
                ui.gain,
                'Pemasukan',
                (cashflowDist['income'] ?? 0).round(),
              ),
              _legendRow(
                ui,
                ui.loss,
                'Pengeluaran',
                (cashflowDist['expense'] ?? 0).round(),
              ),
              _legendRow(
                ui,
                ui.ink,
                'Tabungan',
                (cashflowDist['savings'] ?? 0).round(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow(
    _Ui ui,
    Color color,
    String label,
    int percent,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.instrumentSans(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: ui.muted,
              ),
            ),
          ),
          Text(
            '$percent%',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: ui.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trend Section (Flat Gain Fill, No Gradient, No Grid)
  // ---------------------------------------------------------------------------

  Widget _buildTrendSection(
    BuildContext context,
    List<MonthlyTrendPoint> points,
    MonthlyTrendPoint activePoint,
  ) {
    final ui = _Ui.of(context);

    String modeTitle = 'Perkembangan Tabungan';
    Color lineColor = ui.gain;

    if (_trendMode == 'income') {
      modeTitle = 'Tren Pemasukan';
      lineColor = ui.gain;
    } else if (_trendMode == 'expense') {
      modeTitle = 'Tren Pengeluaran';
      lineColor = ui.loss;
    }

    final maxVal =
        points.fold<double>(0, (prev, el) => el.value > prev ? el.value : prev);
    final double chartMaxY = maxVal == 0 ? 100000 : maxVal * 1.25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_trendMode == 'savings') {
                    _trendMode = 'income';
                  } else if (_trendMode == 'income') {
                    _trendMode = 'expense';
                  } else {
                    _trendMode = 'savings';
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: ui.sheet,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: ui.border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lineColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      modeTitle,
                      style: GoogleFonts.instrumentSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ui.ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.swap_vert_rounded,
                      size: 16,
                      color: ui.muted,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ui.chip,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: ui.border, width: 1),
              ),
              child: Row(
                children: [
                  Text(
                    '${activePoint.label} ',
                    style: GoogleFonts.instrumentSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: ui.muted,
                    ),
                  ),
                  Text(
                    _rupiahStat.format(activePoint.value),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: ui.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 155,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: chartMaxY,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final isSelected = idx == _touchedTrendIndex;
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          points[idx].label,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? ui.ink : ui.muted,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchCallback: (event, response) {
                  if (response != null &&
                      response.lineBarSpots != null &&
                      response.lineBarSpots!.isNotEmpty) {
                    setState(() {
                      _touchedTrendIndex =
                          response.lineBarSpots!.first.x.toInt();
                    });
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF17171A),
                  tooltipRoundedRadius: 6,
                  getTooltipItems: (spots) => spots.map((spot) {
                    return LineTooltipItem(
                      _rupiahStat.format(spot.y),
                      GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF7F6F3),
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (int i = 0; i < points.length; i++)
                      FlSpot(i.toDouble(), points[i].value),
                  ],
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: lineColor,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, barData) =>
                        spot.x.toInt() == _touchedTrendIndex,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 4.5,
                      color: lineColor,
                      strokeWidth: 2,
                      strokeColor: ui.sheet,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: lineColor.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}