import 'package:hive/hive.dart';

/// Model transaksi. Adapter ditulis manual agar proyek
/// langsung bisa dikompilasi tanpa `build_runner`.
class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final bool isIncome;
  final String category;
  final DateTime date;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.date,
  });
}

/// Adapter manual — setara dengan hasil generator Hive.
/// Field index:
/// 0 -> id, 1 -> title, 2 -> amount, 3 -> isIncome, 4 -> category, 5 -> date
class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 0;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      isIncome: fields[3] as bool,
      category: fields[4] as String,
      date: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.isIncome)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModelAdapter && other.typeId == typeId;
}