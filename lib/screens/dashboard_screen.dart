import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/saving_goal_model.dart';
import '../models/transaction_model.dart';
import '../services/hive_service.dart';
import '../utils/categories.dart';
import '../widgets/transaction_form_sheet.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'transactions_screen.dart';

final NumberFormat _rupiah =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

String _formatRupiah(num value) => _rupiah.format(value.abs());
String _formatSigned(num value) =>
    '${value < 0 ? '-' : ''}${_rupiah.format(value.abs())}';

/// ============================================================================
/// DESIGN TOKENS — palet NoUploadPDF
/// Paper hangat, tinta pekat, satu hijau "privacy" yang hanya bermakna
/// (positif / sukses / aksi di atas tinta). Datar: tanpa shadow / elevation.
/// ============================================================================
class _Ui {
  final bool dark;
  const _Ui(this.dark);

  factory _Ui.of(BuildContext context) =>
      _Ui(Theme.of(context).brightness == Brightness.dark);

  // Halaman (paper) dan lembar konten di atasnya.
  Color get canvas =>
      dark ? const Color(0xFF111113) : const Color(0xFFF7F6F3);
  Color get sheet =>
      dark ? const Color(0xFF1A1A1E) : const Color(0xFFFFFFFF);

  // Blok baris / tile di dalam lembar (surface-sunk) dan hairline (outline).
  Color get tint =>
      dark ? const Color(0xFF161619) : const Color(0xFFFBFAF8);
  Color get border =>
      dark ? const Color(0xFF2A2A30) : const Color(0xFFE4E2DC);
  Color get divider =>
      dark ? const Color(0xFF24242A) : const Color(0xFFEEECE7);

  Color get ink => dark ? const Color(0xFFEDEDEA) : const Color(0xFF17171A);
  Color get muted =>
      dark ? const Color(0xFF9E9D97) : const Color(0xFF6B6A64);
  Color get subtle =>
      dark ? const Color(0xFF8B8A84) : const Color(0xFF8A8880);

  // Kartu saldo & tombol ikon (ink / dark-band).
  Color get card => dark ? const Color(0xFF19191C) : const Color(0xFF17171A);
  Color get cardBorder =>
      dark ? const Color(0xFF3B3B42) : const Color(0xFF17171A);
  Color get chip => dark ? const Color(0xFF2A2A30) : const Color(0xFF17171A);
  static const Color onCard = Color(0xFFF7F6F3);
  static const Color onCardMuted = Color(0xFFA9A8A2);

  // Hijau di atas tinta (accent-light) untuk CTA utama.
  static const Color accentOnInk = Color(0xFF56D298);
  static const Color onAccent = Color(0xFF17171A);

  // Positif = Privacy Green. Negatif = crimson (tidak ada di palet sumber).
  Color get gain =>
      dark ? const Color(0xFF5FD49E) : const Color(0xFF007D50);
  Color get gainTint =>
      dark ? const Color(0xFF0F3B29) : const Color(0xFFDEF5E8);
  Color get loss =>
      dark ? const Color(0xFFFF6B7A) : const Color(0xFFB91C1C);
  Color get lossTint =>
      dark ? const Color(0xFF36181D) : const Color(0xFFFEE2E2);
  Color get line => gain;
}

/// ============================================================================
/// DASHBOARD SCREEN
/// ============================================================================
class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);

    return Scaffold(
      backgroundColor: ui.canvas,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<Box<TransactionModel>>(
          valueListenable: HiveService.box.listenable(),
          builder: (context, box, _) {
            return ValueListenableBuilder<Box<SavingGoalModel>>(
              valueListenable: HiveService.goalsBox.listenable(),
              builder: (context, goalsBox, _) {
                final txs = box.values.toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
                final goals = goalsBox.values.toList()
                  ..sort((a, b) {
                    if (a.isCompleted != b.isCompleted) {
                      return a.isCompleted ? 1 : -1;
                    }
                    return b.createdAt.compareTo(a.createdAt);
                  });

                final totals = _Totals.from(txs);
                final growth = _savingsRate(txs);
                final streak = _SavingStreakData.from(txs, goals, totals);
                final insight = _FinancialInsightData.from(txs);
                final goal = _activeGoal(goals);

                return Column(
                  children: [
                    // ---- Header tetap: ikon, judul, kartu saldo ----
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TopBar(
                            onGoals: () => _openGoals(context),
                            onStats: () => _openStatistics(context),
                            onSettings: () => _openSettings(context),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Ringkasan',
                            style: GoogleFonts.instrumentSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: ui.ink,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _BalanceCard(
                            balance: totals.balance,
                            growth: growth,
                            onAdd: () => _openTransactionForm(context),
                          ),
                        ],
                      ),
                    ),

                    // ---- Lembar putih yang bisa di-scroll ----
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: ui.sheet,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                          border: Border(
                            top: BorderSide(color: ui.border, width: 1),
                          ),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
                          children: [
                            // 1. Streak Menabung + Pencapaian
                            _SavingStreakCard(
                              data: streak,
                              onRecordNow: () => _openTransactionForm(context),
                            ),
                            const SizedBox(height: 14),

                            // 2. Pemasukan & Pengeluaran
                            _CashflowRow(
                              income: totals.income,
                              expense: totals.expense,
                            ),
                            const SizedBox(height: 14),

                            // 3. Financial Insight (sebelum Target Tabungan)
                            _FinancialInsightCard(data: insight),
                            const SizedBox(height: 14),

                            // 4. Target Tabungan
                            _GoalStrip(
                              goal: goal,
                              onTap: () => _openGoals(context),
                            ),
                            const SizedBox(height: 26),

                            // 5. Transaksi Terakhir
                            _TransactionList(
                              transactions: txs.take(6).toList(),
                              onTap: (tx) =>
                                  _openTransactionForm(context, initial: tx),
                              onLongPress: (tx) => _confirmDelete(context, tx),
                              onSeeAll: () => _openTransactions(context),
                            ),
                          ],
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

  // --------------------------------------------------------------------------
  // Perhitungan
  // --------------------------------------------------------------------------

  double _savingsRate(List<TransactionModel> txs) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    double income = 0, expense = 0;
    for (final tx in txs) {
      if (tx.date.isBefore(monthStart)) continue;
      if (tx.isIncome) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }
    if (income <= 0) return 0;
    return ((income - expense) / income) * 100;
  }

  _GoalSummary? _activeGoal(List<SavingGoalModel> goals) {
    if (goals.isEmpty) return null;
    final active = goals.firstWhere(
      (g) => !g.isCompleted,
      orElse: () => goals.first,
    );
    return _GoalSummary(
      title: active.title,
      saved: active.currentAmount,
      target: active.targetAmount,
    );
  }

  // --------------------------------------------------------------------------
  // Aksi Navigasi
  // --------------------------------------------------------------------------

  void _openTransactionForm(BuildContext context, {TransactionModel? initial}) {
    TransactionFormSheet.show(context, initial: initial);
  }

  void _openTransactions(BuildContext context) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TransactionsScreen()),
    );
  }

  void _openGoals(BuildContext context) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(2);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GoalsScreen()),
    );
  }

  void _openStatistics(BuildContext context) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(3);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StatisticsScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(4);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _confirmDelete(BuildContext context, TransactionModel tx) async {
    final ui = _Ui.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ui.sheet,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ui.border),
        ),
        title: Text(
          'Hapus transaksi?',
          style: GoogleFonts.instrumentSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: ui.ink,
          ),
        ),
        content: Text(
          tx.title,
          style: GoogleFonts.instrumentSans(fontSize: 13, color: ui.muted),
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
              'Hapus',
              style: GoogleFonts.instrumentSans(
                fontWeight: FontWeight.w600,
                color: ui.loss,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HiveService.delete(tx.id);
    }
  }
}

/// ============================================================================
/// HELPERS, FINANCIAL INSIGHT & STREAK DATA
/// ============================================================================

class _Totals {
  final double income;
  final double expense;
  final double balance;
  const _Totals(this.income, this.expense, this.balance);

  factory _Totals.from(List<TransactionModel> txs) {
    double income = 0, expense = 0;
    for (final t in txs) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return _Totals(income, expense, income - expense);
  }
}

class _GoalSummary {
  final String title;
  final double saved;
  final double target;
  const _GoalSummary({
    required this.title,
    required this.saved,
    required this.target,
  });

  double get progress =>
      target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0).toDouble();
}

class _FinancialInsightData {
  final String? topExpenseCategory;
  final double topExpenseAmount;
  final String habitHeadline;
  final String habitDescription;
  final bool isHabitPositive;
  final bool hasAnyData;

  const _FinancialInsightData({
    required this.topExpenseCategory,
    required this.topExpenseAmount,
    required this.habitHeadline,
    required this.habitDescription,
    required this.isHabitPositive,
    required this.hasAnyData,
  });

  factory _FinancialInsightData.from(List<TransactionModel> txs) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);

    final expenseByCategory = <String, double>{};
    double thisMonthIncome = 0;
    double prevMonthIncome = 0;
    int thisMonthIncomeCount = 0;

    for (final tx in txs) {
      if (!tx.date.isBefore(thisMonthStart)) {
        if (tx.isIncome) {
          thisMonthIncome += tx.amount;
          thisMonthIncomeCount++;
        } else {
          expenseByCategory[tx.category] =
              (expenseByCategory[tx.category] ?? 0) + tx.amount;
        }
      } else if (!tx.date.isBefore(prevMonthStart) &&
          tx.date.isBefore(thisMonthStart)) {
        if (tx.isIncome) {
          prevMonthIncome += tx.amount;
        }
      }
    }

    String? topCat;
    double topAmt = 0;
    expenseByCategory.forEach((cat, amount) {
      if (amount > topAmt) {
        topAmt = amount;
        topCat = cat;
      }
    });

    final String headline;
    final String description;
    final bool positive;

    if (thisMonthIncome <= 0 && prevMonthIncome <= 0) {
      headline = 'Belum ada catatan tabungan';
      description = 'Mulai catat pemasukan bulan ini untuk melihat analisis';
      positive = false;
    } else if (prevMonthIncome <= 0 && thisMonthIncome > 0) {
      headline = 'Konsisten mulai menabung';
      description =
          'Tercatat $thisMonthIncomeCount kali pemasukan tabungan bulan ini';
      positive = true;
    } else if (thisMonthIncome > prevMonthIncome) {
      headline = 'Konsisten meningkat';
      description = 'Pemasukan tabungan lebih tinggi dibanding bulan lalu';
      positive = true;
    } else if (thisMonthIncome == prevMonthIncome) {
      headline = 'Stabil terjaga';
      description = 'Pemasukan tabungan sama seperti bulan lalu';
      positive = true;
    } else {
      headline = 'Perlu ditingkatkan';
      description = 'Pemasukan tabungan masih di bawah bulan lalu';
      positive = false;
    }

    return _FinancialInsightData(
      topExpenseCategory: topCat,
      topExpenseAmount: topAmt,
      habitHeadline: headline,
      habitDescription: description,
      isHabitPositive: positive,
      hasAnyData: topCat != null || thisMonthIncome > 0 || prevMonthIncome > 0,
    );
  }
}

class _DayActivity {
  final String dayLabel;
  final bool saved;
  final bool isToday;

  const _DayActivity({
    required this.dayLabel,
    required this.saved,
    required this.isToday,
  });
}

class _AchievementItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool unlocked;

  const _AchievementItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.unlocked,
  });
}

class _SavingStreakData {
  final int currentStreak;
  final int bestStreak;
  final bool savedToday;
  final List<_DayActivity> last7Days;
  final List<_AchievementItem> achievements;

  const _SavingStreakData({
    required this.currentStreak,
    required this.bestStreak,
    required this.savedToday,
    required this.last7Days,
    required this.achievements,
  });

  int get unlockedCount => achievements.where((a) => a.unlocked).length;

  factory _SavingStreakData.from(
    List<TransactionModel> txs,
    List<SavingGoalModel> goals,
    _Totals totals,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Tanggal unik di mana pengguna mencatat pemasukan / menabung
    final savedDays = <DateTime>{};
    bool hasFirstSaving = false;
    for (final tx in txs) {
      if (tx.isIncome && tx.amount > 0) {
        hasFirstSaving = true;
        savedDays.add(DateTime(tx.date.year, tx.date.month, tx.date.day));
      }
    }

    final savedToday = savedDays.contains(today);

    // Hitung streak aktif berturut-turut
    int current = 0;
    DateTime? cursor;
    if (savedToday) {
      cursor = today;
    } else if (savedDays.contains(yesterday)) {
      cursor = yesterday;
    }

    while (cursor != null && savedDays.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Rekor streak terpanjang sepanjang riwayat
    int best = 0;
    if (savedDays.isNotEmpty) {
      final sorted = savedDays.toList()..sort();
      int run = 1;
      best = 1;
      for (int i = 1; i < sorted.length; i++) {
        if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
          run++;
          if (run > best) best = run;
        } else {
          run = 1;
        }
      }
    }
    if (current > best) best = current;

    // 7 hari terakhir untuk indikator visual harian
    const shortDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final last7 = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return _DayActivity(
        dayLabel: shortDays[d.weekday - 1],
        saved: savedDays.contains(d),
        isToday: d == today,
      );
    });

    // Evaluasi 6 pencapaian
    final hasCompletedGoal = goals.any((g) => g.isCompleted);
    final hasOneMillion =
        totals.income >= 1000000 || totals.balance >= 1000000;

    final achievements = <_AchievementItem>[
      _AchievementItem(
        title: 'Menabung pertama kali',
        subtitle: 'Catat pemasukan tabungan perdana',
        icon: Icons.south_west_rounded,
        unlocked: hasFirstSaving,
      ),
      _AchievementItem(
        title: 'Streak 7 hari',
        subtitle: 'Konsisten menabung 7 hari berturut-turut',
        icon: Icons.local_fire_department_rounded,
        unlocked: best >= 7,
      ),
      _AchievementItem(
        title: 'Streak 14 hari',
        subtitle: 'Konsisten menabung 14 hari berturut-turut',
        icon: Icons.local_fire_department_rounded,
        unlocked: best >= 14,
      ),
      _AchievementItem(
        title: 'Streak 30 hari',
        subtitle: 'Konsisten menabung 30 hari penuh',
        icon: Icons.workspace_premium_rounded,
        unlocked: best >= 30,
      ),
      _AchievementItem(
        title: 'Target tabungan pertama tercapai',
        subtitle: 'Selesaikan 1 target tabungan',
        icon: Icons.flag_rounded,
        unlocked: hasCompletedGoal,
      ),
      _AchievementItem(
        title: 'Mengumpulkan Rp1 juta pertama',
        subtitle: 'Total pemasukan tabungan mencapai Rp1.000.000',
        icon: Icons.savings_rounded,
        unlocked: hasOneMillion,
      ),
    ];

    return _SavingStreakData(
      currentStreak: current,
      bestStreak: best,
      savedToday: savedToday,
      last7Days: last7,
      achievements: achievements,
    );
  }
}

/// Teks nominal uang — JetBrains Mono + tabular figures agar presisi.
class MoneyText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final double? letterSpacing;

  const MoneyText(
    this.text, {
    super.key,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      style: GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? _Ui.of(context).ink,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// ============================================================================
/// WIDGETS
/// ============================================================================

// --- Top Bar: tombol ikon squircle gelap ------------------------------------
class _TopBar extends StatelessWidget {
  final VoidCallback onGoals;
  final VoidCallback onStats;
  final VoidCallback onSettings;

  const _TopBar({
    required this.onGoals,
    required this.onStats,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SquircleButton(icon: Icons.bar_chart_rounded, onTap: onStats),
        const Spacer(),
        _SquircleButton(icon: Icons.savings_outlined, onTap: onGoals),
        const SizedBox(width: 8),
        _SquircleButton(icon: Icons.settings_outlined, onTap: onSettings),
      ],
    );
  }
}

class _SquircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    return Material(
      color: ui.chip,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 19, color: _Ui.onCard),
        ),
      ),
    );
  }
}

// --- Balance Card -----------------------------------------------------------
class _BalanceCard extends StatelessWidget {
  final double balance;
  final double growth;
  final VoidCallback onAdd;

  const _BalanceCard({
    required this.balance,
    required this.growth,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final positive = growth >= 0;
    final rateColor = positive ? _Ui.accentOnInk : const Color(0xFFFF7A87);
    final sign = positive ? '+' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Total saldo',
                style: GoogleFonts.instrumentSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: _Ui.onCardMuted,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                positive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 13,
                color: rateColor,
              ),
              const SizedBox(width: 3),
              MoneyText(
                '$sign${growth.toStringAsFixed(1)}%',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: rateColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(
                    _formatSigned(balance),
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: _Ui.onCard,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: _Ui.accentOnInk,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onAdd,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Catat',
                          style: GoogleFonts.instrumentSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _Ui.onAccent,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.add_rounded,
                            size: 16, color: _Ui.onAccent),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Streak Menabung + Achievements Card ------------------------------------
class _SavingStreakCard extends StatefulWidget {
  final _SavingStreakData data;
  final VoidCallback onRecordNow;

  const _SavingStreakCard({
    required this.data,
    required this.onRecordNow,
  });

  @override
  State<_SavingStreakCard> createState() => _SavingStreakCardState();
}

class _SavingStreakCardState extends State<_SavingStreakCard> {
  bool _showAllAchievements = false;

  static const _milestones = [7, 14, 30];

  int _nextMilestone() {
    for (final m in _milestones) {
      if (widget.data.currentStreak < m) return m;
    }
    return 30;
  }

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final data = widget.data;
    final nextTarget = _nextMilestone();
    final remainingDays = (nextTarget - data.currentStreak).clamp(0, 30);

    final visibleAchievements = _showAllAchievements
        ? data.achievements
        : data.achievements.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.tint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ui.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Streak & Rekor
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: data.currentStreak > 0 ? ui.gainTint : ui.sheet,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: data.currentStreak > 0
                        ? ui.gain.withValues(alpha: 0.35)
                        : ui.border,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 20,
                  color: data.currentStreak > 0 ? ui.gain : ui.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Streak Menabung',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ui.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.currentStreak >= 30
                          ? 'Semua target streak utama tercapai'
                          : remainingDays == 0
                              ? 'Target $nextTarget hari tercapai'
                              : '$remainingDays hari lagi menuju streak $nextTarget hari',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 11.5,
                        color: ui.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${data.currentStreak}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: data.currentStreak > 0 ? ui.gain : ui.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'hari',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: ui.muted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Rekor ${data.bestStreak}h',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      color: ui.subtle,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Indikator Konsistensi 7 Hari Terakhir
          Row(
            children: data.last7Days.map((day) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Column(
                    children: [
                      Container(
                        height: 30,
                        decoration: BoxDecoration(
                          color: day.saved ? ui.gainTint : ui.sheet,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: day.saved
                                ? ui.gain
                                : (day.isToday ? ui.ink : ui.border),
                            width: day.isToday && !day.saved ? 1.2 : 1,
                          ),
                        ),
                        child: Center(
                          child: day.saved
                              ? Icon(Icons.check_rounded,
                                  size: 15, color: ui.gain)
                              : Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: day.isToday ? ui.ink : ui.border,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        day.dayLabel,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight:
                              day.isToday ? FontWeight.w600 : FontWeight.w400,
                          color: day.isToday ? ui.ink : ui.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          if (!data.savedToday) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: widget.onRecordNow,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ui.sheet,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ui.border, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        size: 15, color: ui.gain),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Catat pemasukan hari ini untuk menjaga streak.',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: ui.ink,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: ui.muted),
                  ],
                ),
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, thickness: 1, color: ui.divider),
          ),

          // C. ACHIEVEMENTS — Di bawah informasi streak
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Pencapaian',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: ui.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            data.unlockedCount > 0 ? ui.gainTint : ui.sheet,
                        borderRadius: BorderRadius.circular(4),
                        border: data.unlockedCount == 0
                            ? Border.all(color: ui.border, width: 1)
                            : null,
                      ),
                      child: Text(
                        '${data.unlockedCount}/${data.achievements.length}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: data.unlockedCount > 0 ? ui.gain : ui.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(
                    () => _showAllAchievements = !_showAllAchievements),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showAllAchievements ? 'Tutup' : 'Lihat semua',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ui.muted,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _showAllAchievements
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: ui.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              for (int i = 0; i < visibleAchievements.length; i++) ...[
                _AchievementRow(
                  item: visibleAchievements[i],
                  ui: ui,
                ),
                if (i < visibleAchievements.length - 1)
                  const SizedBox(height: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  final _AchievementItem item;
  final _Ui ui;

  const _AchievementRow({
    required this.item,
    required this.ui,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ui.sheet,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.unlocked ? ui.gain.withValues(alpha: 0.4) : ui.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: item.unlocked ? ui.gainTint : ui.tint,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    item.unlocked ? ui.gain.withValues(alpha: 0.3) : ui.border,
                width: 1,
              ),
            ),
            child: Icon(
              item.icon,
              size: 15,
              color: item.unlocked ? ui.gain : ui.subtle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: item.unlocked ? ui.ink : ui.muted,
                  ),
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 10.5,
                    color: ui.subtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: item.unlocked ? ui.gainTint : ui.tint,
              borderRadius: BorderRadius.circular(4),
              border: !item.unlocked
                  ? Border.all(color: ui.border, width: 1)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.unlocked
                      ? Icons.check_rounded
                      : Icons.lock_outline_rounded,
                  size: 11,
                  color: item.unlocked ? ui.gain : ui.subtle,
                ),
                const SizedBox(width: 3),
                Text(
                  item.unlocked ? 'Tercapai' : 'Terkunci',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: item.unlocked ? ui.gain : ui.subtle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Cashflow ---------------------------------------------------------------
class _CashflowRow extends StatelessWidget {
  final double income;
  final double expense;
  const _CashflowRow({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _CashflowTile(
              label: 'Pemasukan',
              icon: Icons.south_west_rounded,
              color: ui.gain,
              amount: income,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CashflowTile(
              label: 'Pengeluaran',
              icon: Icons.north_east_rounded,
              color: ui.loss,
              amount: expense,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double amount;

  const _CashflowTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.tint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ui.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: ui.sheet,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ui.border, width: 1),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ui.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(
              _formatRupiah(amount),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// --- B. Financial Insight Card (Sebelum Target Tabungan) --------------------
class _FinancialInsightCard extends StatelessWidget {
  final _FinancialInsightData data;

  const _FinancialInsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.tint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ui.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Insight',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ui.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Analisis keuangan bulan ini',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 11.5,
                        color: ui.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ui.sheet,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ui.border, width: 1),
                ),
                child: Text(
                  monthLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: ui.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Pengeluaran terbesar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ui.sheet,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ui.border, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: data.topExpenseCategory != null
                        ? ui.lossTint
                        : ui.tint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    data.topExpenseCategory != null
                        ? iconForCategory(data.topExpenseCategory!)
                        : Icons.receipt_long_outlined,
                    size: 16,
                    color:
                        data.topExpenseCategory != null ? ui.loss : ui.subtle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengeluaran terbesar',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ui.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.topExpenseCategory ?? 'Belum ada pengeluaran',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.instrumentSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: ui.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(
                      data.topExpenseCategory != null
                          ? _formatRupiah(data.topExpenseAmount)
                          : 'Rp 0',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          data.topExpenseCategory != null ? ui.loss : ui.muted,
                    ),
                    Text(
                      'bulan ini',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 10.5,
                        color: ui.subtle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 2. Kebiasaan menabung
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ui.sheet,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ui.border, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: data.isHabitPositive ? ui.gainTint : ui.tint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    data.isHabitPositive
                        ? Icons.trending_up_rounded
                        : Icons.insights_rounded,
                    size: 16,
                    color: data.isHabitPositive ? ui.gain : ui.muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Kebiasaan menabung',
                            style: GoogleFonts.instrumentSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: ui.muted,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  data.isHabitPositive ? ui.gainTint : ui.tint,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              data.habitHeadline,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color:
                                    data.isHabitPositive ? ui.gain : ui.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.habitDescription,
                        style: GoogleFonts.instrumentSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: ui.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Goal Strip -------------------------------------------------------------
class _GoalStrip extends StatelessWidget {
  final _GoalSummary? goal;
  final VoidCallback onTap;
  const _GoalStrip({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final g = goal;

    return Material(
      color: ui.tint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ui.border, width: 1),
          ),
          child: g == null
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target aktif',
                            style: GoogleFonts.instrumentSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: ui.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Belum ada target. Buat satu untuk mulai menabung.',
                            style: GoogleFonts.instrumentSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: ui.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: ui.muted),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            g.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.instrumentSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: ui.ink,
                            ),
                          ),
                        ),
                        MoneyText(
                          '${(g.progress * 100).toStringAsFixed(0)}%',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ui.gain,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ProgressBar(value: g.progress),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        MoneyText(
                          _formatRupiah(g.saved),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ui.ink,
                        ),
                        Text(
                          '  dari  ',
                          style: GoogleFonts.instrumentSans(
                            fontSize: 11,
                            color: ui.muted,
                          ),
                        ),
                        MoneyText(
                          _formatRupiah(g.target),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ui.muted,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: ui.border)),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              child: ColoredBox(
                color: ui.line,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Transaction List -------------------------------------------------------
class _TransactionList extends StatelessWidget {
  final List<TransactionModel> transactions;
  final ValueChanged<TransactionModel> onTap;
  final ValueChanged<TransactionModel> onLongPress;
  final VoidCallback onSeeAll;

  const _TransactionList({
    required this.transactions,
    required this.onTap,
    required this.onLongPress,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Transaksi Terakhir',
                style: GoogleFonts.instrumentSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ui.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSeeAll,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: ui.tint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ui.border, width: 1),
                ),
                child: Text(
                  'Semua',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ui.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          const _EmptyList()
        else
          for (int i = 0; i < transactions.length; i++) ...[
            _TransactionRow(
              tx: transactions[i],
              onTap: () => onTap(transactions[i]),
              onLongPress: () => onLongPress(transactions[i]),
            ),
            if (i < transactions.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final TransactionModel tx;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TransactionRow({
    required this.tx,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final amountColor = tx.isIncome ? ui.gain : ui.loss;
    final sign = tx.isIncome ? '+' : '-';
    final dateLabel = DateFormat('d MMM yyyy', 'id_ID').format(tx.date);

    return Material(
      color: ui.tint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ui.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ui.sheet,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ui.border, width: 1),
                ),
                child: Icon(
                  iconForCategory(tx.category),
                  size: 17,
                  color: ui.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.instrumentSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: ui.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: GoogleFonts.instrumentSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: ui.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MoneyText(
                '$sign${_formatRupiah(tx.amount)}',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: amountColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: ui.tint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ui.border, width: 1),
      ),
      child: Center(
        child: Text(
          'Belum ada transaksi. Ketuk Catat untuk menambah.',
          textAlign: TextAlign.center,
          style: GoogleFonts.instrumentSans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: ui.muted,
          ),
        ),
      ),
    );
  }
}