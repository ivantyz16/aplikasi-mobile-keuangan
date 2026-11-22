import 'package:hive/hive.dart';

/// Model target tabungan (celengan).
/// Adapter manual agar langsung compile tanpa `build_runner`.
class SavingGoalModel {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String? imagePath;
  final DateTime? deadline;
  final DateTime createdAt;

  const SavingGoalModel({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.imagePath,
    this.deadline,
    required this.createdAt,
  });

  /// Progres 0.0–1.0 (sudah di-clamp).
  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0.0, 1.0);

  bool get isCompleted => currentAmount >= targetAmount;

  /// Sisa kekurangan (tidak negatif).
  double get remaining =>
      (targetAmount - currentAmount).clamp(0.0, targetAmount);

  SavingGoalModel copyWith({
    String? title,
    double? targetAmount,
    double? currentAmount,
    String? imagePath,
    bool clearImage = false,
    DateTime? deadline,
    bool clearDeadline = false,
  }) {
    return SavingGoalModel(
      id: id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      createdAt: createdAt,
    );
  }
}

/// Adapter manual — setara hasil generator Hive.
/// Field index: 0 id, 1 title, 2 targetAmount, 3 currentAmount,
///              4 imagePath, 5 deadline, 6 createdAt
class SavingGoalModelAdapter extends TypeAdapter<SavingGoalModel> {
  @override
  final int typeId = 1;

  @override
  SavingGoalModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavingGoalModel(
      id: fields[0] as String,
      title: fields[1] as String,
      targetAmount: (fields[2] as num).toDouble(),
      currentAmount: (fields[3] as num?)?.toDouble() ?? 0.0,
      imagePath: fields[4] as String?,
      deadline: fields[5] as DateTime?,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SavingGoalModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.title)
      ..writeByte(2)..write(obj.targetAmount)
      ..writeByte(3)..write(obj.currentAmount)
      ..writeByte(4)..write(obj.imagePath)
      ..writeByte(5)..write(obj.deadline)
      ..writeByte(6)..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingGoalModelAdapter && other.typeId == typeId;
}