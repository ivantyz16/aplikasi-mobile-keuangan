import 'package:flutter/material.dart';

class TransactionCategory {
  final String name;
  final IconData icon;
  final bool isIncome;
  const TransactionCategory(this.name, this.icon, this.isIncome);
}

/// Kategori pemasukan — kontekstual pelajar kelas 12.
const List<TransactionCategory> incomeCategories = [
  TransactionCategory('Uang Saku', Icons.account_balance_wallet_outlined, true),
  TransactionCategory('Gaji', Icons.payments_outlined, true),
  TransactionCategory('Bonus / Lomba', Icons.emoji_events_outlined, true),
  TransactionCategory('Penjualan / Jasa', Icons.storefront_outlined, true),
  TransactionCategory('Lainnya', Icons.add_circle_outline, true),
];

/// Kategori pengeluaran — relatable untuk anak sekolah.
const List<TransactionCategory> expenseCategories = [
  TransactionCategory('Jajan & Kantin', Icons.fastfood_outlined, false),
  TransactionCategory('Transport & Bensin', Icons.two_wheeler_outlined, false),
  TransactionCategory('Kebutuhan Sekolah', Icons.menu_book_outlined, false),
  TransactionCategory('Kuota & Paket Data', Icons.wifi_outlined, false),
  TransactionCategory('Hiburan & Game', Icons.sports_esports_outlined, false),
  TransactionCategory('Tabungan / Darurat', Icons.savings_outlined, false),
  TransactionCategory('Lainnya', Icons.more_horiz, false),
];

List<TransactionCategory> categoriesFor(bool isIncome) =>
    isIncome ? incomeCategories : expenseCategories;

/// Semua nama kategori unik (untuk dropdown filter).
List<String> get allCategoryNames {
  final set = <String>{};
  for (final c in [...incomeCategories, ...expenseCategories]) {
    set.add(c.name);
  }
  return set.toList()..sort();
}

/// Resolusi ikon berdasarkan nama kategori.
/// Mendukung nama kategori lama (seed data) agar tetap kompatibel.
IconData iconForCategory(String name) {
  for (final c in [...incomeCategories, ...expenseCategories]) {
    if (c.name == name) return c.icon;
  }
  // Legacy mapping (seed data versi dashboard lama)
  switch (name) {
    case 'Makan':
      return Icons.fastfood_outlined;
    case 'Transport':
      return Icons.two_wheeler_outlined;
    case 'Belanja':
      return Icons.shopping_bag_outlined;
    case 'Tagihan':
      return Icons.receipt_long_outlined;
    case 'Hiburan':
      return Icons.movie_outlined;
    case 'Gaji':
      return Icons.payments_outlined;
    case 'Transfer':
      return Icons.swap_horiz_outlined;
    default:
      return Icons.receipt_outlined;
  }
}