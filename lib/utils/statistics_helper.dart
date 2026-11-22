import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/saving_goal_model.dart';

class CategoryStat {
  final String category;
  final double amount;
  final double percentage;
  final Color color;

  CategoryStat({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.color,
  });
}

class MonthlyTrendPoint {
  final String label;
  final DateTime date;
  final double value;

  MonthlyTrendPoint({
    required this.label,
    required this.date,
    required this.value,
  });
}

class StatisticsHelper {
  // Palet warna harmonis hijau-sage-terracotta (Anti AI-Slop)
  static const List<Color> chartPalette = [
    Color(0xFF0F291E), // Dark Forest
    Color(0xFF1B9C67), // Emerald
    Color(0xFF52B788), // Medium Sea Green
    Color(0xFF8AB8A3), // Sage Muted
    Color(0xFFC84B31), // Muted Terracotta
    Color(0xFFD9822B), // Warm Amber
    Color(0xFF63736B), // Slate Green
  ];

  /// Menghitung rincian per kategori untuk Donut Chart
  static List<CategoryStat> getCategoryBreakdown({
    required List<TransactionModel> transactions,
    required DateTime selectedMonth,
    required bool isYearly,
    required bool isIncome,
  }) {
    final filtered = transactions.where((tx) {
      if (tx.isIncome != isIncome) return false;
      if (isYearly) {
        return tx.date.year == selectedMonth.year;
      }
      return tx.date.year == selectedMonth.year &&
          tx.date.month == selectedMonth.month;
    }).toList();

    if (filtered.isEmpty) return [];

    final Map<String, double> totals = {};
    double grandTotal = 0;

    for (final tx in filtered) {
      totals[tx.category] = (totals[tx.category] ?? 0) + tx.amount;
      grandTotal += tx.amount;
    }

    if (grandTotal == 0) return [];

    final sortedEntries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<CategoryStat> results = [];
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      results.add(
        CategoryStat(
          category: entry.key,
          amount: entry.value,
          percentage: (entry.value / grandTotal) * 100,
          color: chartPalette[i % chartPalette.length],
        ),
      );
    }

    return results;
  }

  /// Menghitung distribusi Pemasukan vs Pengeluaran vs Tabungan untuk Pie Chart
  static Map<String, double> getCashflowDistribution({
    required List<TransactionModel> transactions,
    required List<SavingGoalModel> goals,
    required DateTime selectedMonth,
    required bool isYearly,
  }) {
    final filtered = transactions.where((tx) {
      if (isYearly) {
        return tx.date.year == selectedMonth.year;
      }
      return tx.date.year == selectedMonth.year &&
          tx.date.month == selectedMonth.month;
    });

    double income = 0;
    double expense = 0;
    double savings = 0;

    for (final tx in filtered) {
      if (tx.isIncome) {
        income += tx.amount;
      } else {
        if (tx.category.toLowerCase().contains('tabungan') ||
            tx.title.toLowerCase().startsWith('alokasi:')) {
          savings += tx.amount;
        } else {
          expense += tx.amount;
        }
      }
    }

    // Jika belum ada mutasi tabungan di bulan itu, ambil dari total target aktif sebagai referensi
    if (savings == 0 && goals.isNotEmpty) {
      savings = goals.fold(0.0, (sum, g) => sum + g.currentAmount);
    }

    final total = income + expense + savings;
    if (total == 0) {
      return {'income': 0, 'expense': 0, 'savings': 0};
    }

    return {
      'income': (income / total) * 100,
      'expense': (expense / total) * 100,
      'savings': (savings / total) * 100,
    };
  }

  /// Menghitung data 7 bulan terakhir untuk Grafik Kurva Bawah
  /// mode: 'savings' | 'income' | 'expense'
  static List<MonthlyTrendPoint> get7MonthsTrend({
    required List<TransactionModel> transactions,
    required DateTime anchorMonth,
    required String mode,
  }) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];

    final List<MonthlyTrendPoint> points = [];

    for (int i = 6; i >= 0; i--) {
      final targetDate = DateTime(anchorMonth.year, anchorMonth.month - i, 1);
      final label = monthNames[targetDate.month - 1];

      double value = 0;

      if (mode == 'savings') {
        // Akumulasi saldo bersih hingga akhir bulan tersebut
        final endOfMonth = DateTime(targetDate.year, targetDate.month + 1, 0, 23, 59, 59);
        for (final tx in transactions) {
          if (tx.date.isBefore(endOfMonth) || tx.date.isAtSameMomentAs(endOfMonth)) {
            value += tx.isIncome ? tx.amount : -tx.amount;
          }
        }
        if (value < 0) value = 0;
      } else if (mode == 'income') {
        for (final tx in transactions) {
          if (tx.isIncome &&
              tx.date.year == targetDate.year &&
              tx.date.month == targetDate.month) {
            value += tx.amount;
          }
        }
      } else {
        for (final tx in transactions) {
          if (!tx.isIncome &&
              tx.date.year == targetDate.year &&
              tx.date.month == targetDate.month) {
            value += tx.amount;
          }
        }
      }

      points.add(MonthlyTrendPoint(label: label, date: targetDate, value: value));
    }

    return points;
  }
}