import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_model.dart';
import '../models/saving_goal_model.dart';

class HiveService {
  HiveService._();

  static const String boxName = 'transactions';
  static const String goalsBoxName = 'saving_goals';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionModelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SavingGoalModelAdapter());
    await Hive.openBox<TransactionModel>(boxName);
    await Hive.openBox<SavingGoalModel>(goalsBoxName);
  }

  // ---- Transaksi ------------------------------------------------------------
  static Box<TransactionModel> get box => Hive.box<TransactionModel>(boxName);
  static Future<void> add(TransactionModel tx) async => await box.put(tx.id, tx);
  static Future<void> delete(String id) async => await box.delete(id);
  static Future<void> clearAll() async => await box.clear();

  // ---- Target Tabungan ------------------------------------------------------
  static Box<SavingGoalModel> get goalsBox =>
      Hive.box<SavingGoalModel>(goalsBoxName);

  static Future<void> addGoal(SavingGoalModel goal) async =>
      await goalsBox.put(goal.id, goal);

  static Future<void> updateGoal(SavingGoalModel goal) async =>
      await goalsBox.put(goal.id, goal);

  /// Tambah alokasi ke target + catat transaksi pengeluaran
  /// berkategori "Tabungan / Darurat" agar saldo utama ikut turun.
  static Future<void> allocateToGoal(SavingGoalModel goal, double amount) async {
    if (amount <= 0) return;
    final updated = goal.copyWith(currentAmount: goal.currentAmount + amount);
    await updateGoal(updated);
    await add(TransactionModel(
      id: 'alloc_${goal.id}_${DateTime.now().microsecondsSinceEpoch}',
      title: 'Alokasi: ${goal.title}',
      amount: amount,
      isIncome: false,
      category: 'Tabungan / Darurat',
      date: DateTime.now(),
    ));
  }

  /// Tarik dana dari target + catat transaksi pemasukan
  /// berkategori "Lainnya" agar dana kembali ke saldo utama.
  static Future<void> withdrawFromGoal(
      SavingGoalModel goal, double amount) async {
    if (amount <= 0) return;
    final taken = amount.clamp(0.0, goal.currentAmount);
    if (taken <= 0) return;
    final updated = goal.copyWith(currentAmount: goal.currentAmount - taken);
    await updateGoal(updated);
    await add(TransactionModel(
      id: 'wd_${goal.id}_${DateTime.now().microsecondsSinceEpoch}',
      title: 'Tarik Target: ${goal.title}',
      amount: taken,
      isIncome: true,
      category: 'Lainnya',
      date: DateTime.now(),
    ));
  }

  /// Hapus target. Jika masih ada saldo, kembalikan ke saldo utama
  /// sebagai transaksi pemasukan.
  static Future<void> deleteGoal(SavingGoalModel goal) async {
    if (goal.currentAmount > 0) {
      await add(TransactionModel(
        id: 'refund_${goal.id}_${DateTime.now().microsecondsSinceEpoch}',
        title: 'Refund Target: ${goal.title}',
        amount: goal.currentAmount,
        isIncome: true,
        category: 'Lainnya',
        date: DateTime.now(),
      ));
    }
    await goalsBox.delete(goal.id);
  }
}