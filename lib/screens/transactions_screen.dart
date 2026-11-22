import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/hive_service.dart';
import '../utils/categories.dart';
import '../widgets/transaction_form_sheet.dart';

enum TypeFilter { all, income, expense }

enum TimeFilter { all, today, week, month }

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
  Color get gain => dark ? const Color(0xFF5FD49E) : const Color(0xFF007D50);
  Color get gainTint =>
      dark ? const Color(0xFF0F3B29) : const Color(0xFFDEF5E8);
  Color get loss => dark ? const Color(0xFFFF6B7A) : const Color(0xFFB91C1C);
  static const accentOnInk = Color(0xFF56D298);
}

final _rupiahTx =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  TypeFilter _typeFilter = TypeFilter.all;
  String? _categoryFilter;
  TimeFilter _timeFilter = TimeFilter.all;

  // State Kalender Keuangan
  bool _isCalendarView = false;
  late DateTime _selectedDate;
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _focusedMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Filter logic
  // ---------------------------------------------------------------------------

  DateTime? _timeStart(TimeFilter f) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (f) {
      case TimeFilter.all:
        return null;
      case TimeFilter.today:
        return today;
      case TimeFilter.week:
        return today.subtract(Duration(days: today.weekday - 1));
      case TimeFilter.month:
        return DateTime(now.year, now.month);
    }
  }

  List<TransactionModel> _applyFilters(List<TransactionModel> all) {
    final start = _isCalendarView ? null : _timeStart(_timeFilter);
    final q = _query.toLowerCase().trim();

    final filtered = all.where((tx) {
      if (_typeFilter == TypeFilter.income && !tx.isIncome) return false;
      if (_typeFilter == TypeFilter.expense && tx.isIncome) return false;
      if (_categoryFilter != null && tx.category != _categoryFilter) {
        return false;
      }
      if (start != null && tx.date.isBefore(start)) return false;
      if (q.isNotEmpty) {
        final hit = tx.title.toLowerCase().contains(q) ||
            tx.category.toLowerCase().contains(q);
        if (!hit) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  Map<DateTime, List<TransactionModel>> _groupByDay(
      List<TransactionModel> txs) {
    final map = <DateTime, List<TransactionModel>>{};
    for (final tx in txs) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      map.putIfAbsent(day, () => []).add(tx);
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _openEdit(TransactionModel tx) async {
    await TransactionFormSheet.show(context, initial: tx);
  }

  Future<void> _deleteWithUndo(TransactionModel tx) async {
    final ui = _Ui.of(context);
    await HiveService.delete(tx.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF17171A),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: ui.border, width: 1),
        ),
        content: Text(
          '${tx.title} dihapus.',
          style: GoogleFonts.instrumentSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFF7F6F3),
          ),
        ),
        action: SnackBarAction(
          label: 'Urungkan',
          textColor: _Ui.accentOnInk,
          onPressed: () => HiveService.add(tx),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);

    return Scaffold(
      backgroundColor: ui.canvas,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(
          onPressed: () => TransactionFormSheet.show(context),
          backgroundColor: ui.ink,
          foregroundColor: ui.canvas,
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            'Tambah',
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
        child: ValueListenableBuilder<Box<TransactionModel>>(
          valueListenable: HiveService.box.listenable(),
          builder: (context, box, _) {
            final all = box.values.toList();
            final filtered = _applyFilters(all);
            final groups = _groupByDay(filtered);

            final selectedKey = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            );
            final selectedDayTxs = groups[selectedKey] ?? const [];

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context, filtered.length)),
                SliverToBoxAdapter(child: _buildSearchBar(context)),
                SliverToBoxAdapter(child: _buildFilterBar(context)),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                if (_isCalendarView) ...[
                  SliverToBoxAdapter(
                    child: _FinancialCalendarCard(
                      focusedMonth: _focusedMonth,
                      selectedDate: selectedKey,
                      groupedByDay: groups,
                      onMonthChanged: (newMonth) {
                        setState(() => _focusedMonth = newMonth);
                      },
                      onDateSelected: (day) {
                        setState(() {
                          _selectedDate = day;
                          _focusedMonth = DateTime(day.year, day.month);
                        });
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _SelectedDateSummarySection(
                      date: selectedKey,
                      transactions: selectedDayTxs,
                      onTap: _openEdit,
                      onDelete: _deleteWithUndo,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 155)),
                ] else ...[
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState(context))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 155),
                      sliver: SliverList.separated(
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 18),
                        itemBuilder: (context, i) {
                          final day = groups.keys.elementAt(i);
                          final items = groups[day]!;
                          return _DateGroup(
                            date: day,
                            transactions: items,
                            onTap: _openEdit,
                            onDelete: _deleteWithUndo,
                          );
                        },
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header + Switch Daftar / Kalender
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, int count) {
    final ui = _Ui.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                child: Icon(Icons.arrow_back_rounded, size: 18, color: ui.ink),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCalendarView ? 'Kalender Keuangan' : 'Riwayat Transaksi',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: ui.ink,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count transaksi tercatat',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: ui.subtle,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: ui.chip,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ui.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewSwitchButton(
                  ui: ui,
                  icon: Icons.format_list_bulleted_rounded,
                  label: 'Daftar',
                  active: !_isCalendarView,
                  onTap: () => setState(() => _isCalendarView = false),
                ),
                _viewSwitchButton(
                  ui: ui,
                  icon: Icons.calendar_month_rounded,
                  label: 'Kalender',
                  active: _isCalendarView,
                  onTap: () => setState(() => _isCalendarView = true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewSwitchButton({
    required _Ui ui,
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? ui.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? ui.canvas : ui.muted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.instrumentSans(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? ui.canvas : ui.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final ui = _Ui.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: GoogleFonts.instrumentSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          color: ui.ink,
        ),
        decoration: InputDecoration(
          hintText: 'Cari judul atau kategori...',
          hintStyle: GoogleFonts.instrumentSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: ui.subtle,
          ),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: ui.muted),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: ui.muted),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          filled: true,
          fillColor: ui.sheet,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Filter bar
  // ---------------------------------------------------------------------------

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _typePill(context, 'Semua', _typeFilter == TypeFilter.all,
                () => setState(() => _typeFilter = TypeFilter.all)),
            const SizedBox(width: 6),
            _typePill(context, 'Pemasukan', _typeFilter == TypeFilter.income,
                () => setState(() => _typeFilter = TypeFilter.income)),
            const SizedBox(width: 6),
            _typePill(context, 'Pengeluaran', _typeFilter == TypeFilter.expense,
                () => setState(() => _typeFilter = TypeFilter.expense)),
            const SizedBox(width: 10),
            _categoryDropdown(context),
            if (!_isCalendarView) ...[
              const SizedBox(width: 6),
              _timeDropdown(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typePill(
      BuildContext context, String label, bool active, VoidCallback onTap) {
    final ui = _Ui.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active ? ui.ink : ui.sheet,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active ? ui.ink : ui.border,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.instrumentSans(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? ui.canvas : ui.ink,
          ),
        ),
      ),
    );
  }

  Widget _categoryDropdown(BuildContext context) {
    final ui = _Ui.of(context);
    final label = _categoryFilter ?? 'Kategori';
    final active = _categoryFilter != null;

    return PopupMenuButton<String?>(
      tooltip: '',
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      offset: const Offset(0, 38),
      color: ui.sheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ui.border, width: 1),
      ),
      onSelected: (value) => setState(() => _categoryFilter = value),
      itemBuilder: (context) => [
        _menuItem<String?>(
            context, null, 'Semua Kategori', Icons.grid_view_rounded),
        for (final name in allCategoryNames)
          _menuItem<String?>(context, name, name, iconForCategory(name)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? ui.gainTint : ui.sheet,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active ? ui.gain : ui.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.instrumentSans(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? ui.gain : ui.ink,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? ui.gain : ui.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeDropdown(BuildContext context) {
    final ui = _Ui.of(context);
    String label;
    switch (_timeFilter) {
      case TimeFilter.all:
        label = 'Semua Waktu';
        break;
      case TimeFilter.today:
        label = 'Hari Ini';
        break;
      case TimeFilter.week:
        label = 'Minggu Ini';
        break;
      case TimeFilter.month:
        label = 'Bulan Ini';
        break;
    }
    final active = _timeFilter != TimeFilter.all;

    return PopupMenuButton<TimeFilter>(
      tooltip: '',
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      offset: const Offset(0, 38),
      color: ui.sheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ui.border, width: 1),
      ),
      onSelected: (value) => setState(() => _timeFilter = value),
      itemBuilder: (context) => [
        _menuItem<TimeFilter>(
            context, TimeFilter.all, 'Semua Waktu', Icons.event_note_outlined),
        _menuItem<TimeFilter>(
            context, TimeFilter.today, 'Hari Ini', Icons.today_outlined),
        _menuItem<TimeFilter>(
            context, TimeFilter.week, 'Minggu Ini', Icons.date_range_outlined),
        _menuItem<TimeFilter>(context, TimeFilter.month, 'Bulan Ini',
            Icons.calendar_month_outlined),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? ui.gainTint : ui.sheet,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active ? ui.gain : ui.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.instrumentSans(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? ui.gain : ui.ink,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? ui.gain : ui.muted,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<T> _menuItem<T>(
      BuildContext context, T value, String label, IconData icon) {
    final ui = _Ui.of(context);
    return PopupMenuItem<T>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 16, color: ui.muted),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.instrumentSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: ui.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final ui = _Ui.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
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
              child:
                  Icon(Icons.receipt_long_outlined, size: 22, color: ui.ink),
            ),
            const SizedBox(height: 14),
            Text(
              'Tidak ada transaksi',
              style: GoogleFonts.instrumentSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ui.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ubah kata kunci filter atau catat transaksi baru.',
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
// Kalender Keuangan Grid Card
// =============================================================================

class _FinancialCalendarCard extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Map<DateTime, List<TransactionModel>> groupedByDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  const _FinancialCalendarCard({
    required this.focusedMonth,
    required this.selectedDate,
    required this.groupedByDay,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  static const _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const _dayHeaders = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final leadingEmpty = firstDayOfMonth.weekday - 1;
    final totalCells = leadingEmpty + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ui.sheet,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ui.border, width: 1),
        ),
        child: Column(
          children: [
            // Header Bulan & Navigasi
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_monthNames[focusedMonth.month - 1]} ${focusedMonth.year}',
                    style: GoogleFonts.instrumentSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ui.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => onDateSelected(today),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: ui.chip,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ui.border, width: 1),
                    ),
                    child: Text(
                      'Hari Ini',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ui.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _navIconBtn(
                  ui: ui,
                  icon: Icons.chevron_left_rounded,
                  onTap: () => onMonthChanged(
                    DateTime(focusedMonth.year, focusedMonth.month - 1),
                  ),
                ),
                const SizedBox(width: 4),
                _navIconBtn(
                  ui: ui,
                  icon: Icons.chevron_right_rounded,
                  onTap: () => onMonthChanged(
                    DateTime(focusedMonth.year, focusedMonth.month + 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Header Nama Hari (Sen - Min)
            Row(
              children: _dayHeaders.map((dayName) {
                return Expanded(
                  child: Center(
                    child: Text(
                      dayName,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: ui.subtle,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            // Grid Tanggal
            Column(
              children: List.generate(rowCount, (row) {
                return Padding(
                  padding: EdgeInsets.only(bottom: row < rowCount - 1 ? 4 : 0),
                  child: Row(
                    children: List.generate(7, (col) {
                      final cellIndex = (row * 7) + col;
                      final dayNumber = cellIndex - leadingEmpty + 1;

                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return const Expanded(child: SizedBox(height: 44));
                      }

                      final cellDate = DateTime(
                        focusedMonth.year,
                        focusedMonth.month,
                        dayNumber,
                      );
                      final isSelected = cellDate == selectedDate;
                      final isToday = cellDate == today;
                      final dayTxs = groupedByDay[cellDate] ?? const [];

                      final hasIncome = dayTxs.any((t) => t.isIncome);
                      final hasExpense = dayTxs.any((t) => !t.isIncome);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onDateSelected(cellDate),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? ui.ink
                                  : (isToday ? ui.tint : Colors.transparent),
                              borderRadius: BorderRadius.circular(10),
                              border: isToday && !isSelected
                                  ? Border.all(color: ui.ink, width: 1)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNumber',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected ? ui.canvas : ui.ink,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                SizedBox(
                                  height: 5,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (hasIncome)
                                        Container(
                                          width: 4.5,
                                          height: 4.5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? _Ui.accentOnInk
                                                : ui.gain,
                                          ),
                                        ),
                                      if (hasIncome && hasExpense)
                                        const SizedBox(width: 2.5),
                                      if (hasExpense)
                                        Container(
                                          width: 4.5,
                                          height: 4.5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: ui.loss,
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
                    }),
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: ui.divider),
            const SizedBox(height: 10),

            // Legenda Indikator Titik
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _dotLegend(ui.gain, 'Pemasukan', ui),
                const SizedBox(width: 14),
                _dotLegend(ui.loss, 'Pengeluaran', ui),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _navIconBtn({
    required _Ui ui,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: ui.tint,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ui.border, width: 1),
        ),
        child: Icon(icon, size: 17, color: ui.ink),
      ),
    );
  }

  Widget _dotLegend(Color dotColor, String label, _Ui ui) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.instrumentSans(
            fontSize: 11,
            color: ui.muted,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Ringkasan & Daftar Transaksi untuk Tanggal Terpilih
// =============================================================================

class _SelectedDateSummarySection extends StatelessWidget {
  final DateTime date;
  final List<TransactionModel> transactions;
  final ValueChanged<TransactionModel> onTap;
  final ValueChanged<TransactionModel> onDelete;

  const _SelectedDateSummarySection({
    required this.date,
    required this.transactions,
    required this.onTap,
    required this.onDelete,
  });

  String _formattedHeaderDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    final full = DateFormat('d MMMM yyyy', 'id_ID').format(date);
    if (diff == 0) return 'Hari Ini · $full';
    if (diff == 1) return 'Kemarin · $full';
    return full;
  }

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);

    double dayIncome = 0;
    double dayExpense = 0;
    for (final t in transactions) {
      if (t.isIncome) {
        dayIncome += t.amount;
      } else {
        dayExpense += t.amount;
      }
    }
    final net = dayIncome - dayExpense;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formattedHeaderDate(),
                  style: GoogleFonts.instrumentSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ui.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                '${transactions.length} aktivitas',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: ui.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Kartu Ringkasan Pemasukan & Pengeluaran Tanggal Terpilih
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ui.tint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ui.border, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pemasukan',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 11.5,
                          color: ui.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${_rupiahTx.format(dayIncome)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: dayIncome > 0 ? ui.gain : ui.subtle,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: ui.divider,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengeluaran',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 11.5,
                          color: ui.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '-${_rupiahTx.format(dayExpense)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: dayExpense > 0 ? ui.loss : ui.subtle,
                          fontFeatures: const [FontFeature.tabularFigures()],
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
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ui.border, width: 1),
                  ),
                  child: Text(
                    '${net >= 0 ? '+' : '-'}${_rupiahTx.format(net.abs())}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: net >= 0 ? ui.gain : ui.loss,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: ui.sheet,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ui.border, width: 1),
              ),
              child: Text(
                'Tidak ada pemasukan maupun pengeluaran pada tanggal ini.',
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSans(
                  fontSize: 12.5,
                  color: ui.muted,
                ),
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
                  for (int i = 0; i < transactions.length; i++) ...[
                    Dismissible(
                      key: ValueKey('cal_${transactions[i].id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: ui.loss,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(i == 0 ? 11 : 0),
                            bottom: Radius.circular(
                                i == transactions.length - 1 ? 11 : 0),
                          ),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.white, size: 20),
                      ),
                      onDismissed: (_) => onDelete(transactions[i]),
                      child: _TransactionTile(
                        tx: transactions[i],
                        onTap: () => onTap(transactions[i]),
                      ),
                    ),
                    if (i < transactions.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 64, right: 14),
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

// =============================================================================
// Date Group Container (Tampilan Daftar)
// =============================================================================

class _DateGroup extends StatelessWidget {
  final DateTime date;
  final List<TransactionModel> transactions;
  final ValueChanged<TransactionModel> onTap;
  final ValueChanged<TransactionModel> onDelete;

  const _DateGroup({
    required this.date,
    required this.transactions,
    required this.onTap,
    required this.onDelete,
  });

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Hari Ini';
    if (diff == 1) return 'Kemarin';
    return DateFormat('d MMM yyyy', 'id_ID').format(target);
  }

  double _dailyNet() {
    double net = 0;
    for (final t in transactions) {
      net += t.isIncome ? t.amount : -t.amount;
    }
    return net;
  }

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final net = _dailyNet();
    final netColor = net >= 0 ? ui.gain : ui.loss;
    final netSign = net >= 0 ? '+' : '-';
    final netText = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(net.abs());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _label(),
                  style: GoogleFonts.instrumentSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ui.muted,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                '$netSign$netText',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: netColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
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
              for (int i = 0; i < transactions.length; i++) ...[
                Dismissible(
                  key: ValueKey(transactions[i].id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: ui.loss,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(i == 0 ? 11 : 0),
                        bottom: Radius.circular(
                            i == transactions.length - 1 ? 11 : 0),
                      ),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.white, size: 20),
                  ),
                  onDismissed: (_) => onDelete(transactions[i]),
                  child: _TransactionTile(
                    tx: transactions[i],
                    onTap: () => onTap(transactions[i]),
                  ),
                ),
                if (i < transactions.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 64, right: 14),
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
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel tx;
  final VoidCallback onTap;
  const _TransactionTile({required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final sign = tx.isIncome ? '+' : '-';
    final amountColor = tx.isIncome ? ui.gain : ui.ink;
    final amount = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(tx.amount);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ui.tint,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: ui.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tx.category,
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: ui.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$sign$amount',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: amountColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}