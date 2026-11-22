import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/saving_goal_model.dart';
import '../models/transaction_model.dart';
import 'hive_service.dart';

class ExportBackupService {
  ExportBackupService._();

  static final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// ==========================================================================
  /// 1. BACKUP DATA KE JSON (Teks / File Download)
  /// ==========================================================================
  static String createBackupJsonString() {
    final txs = HiveService.box.values.map((t) {
      return {
        'id': t.id,
        'title': t.title,
        'amount': t.amount,
        'isIncome': t.isIncome,
        'category': t.category,
        'date': t.date.toIso8601String(),
      };
    }).toList();

    final goals = HiveService.goalsBox.values.map((g) {
      return {
        'id': g.id,
        'title': g.title,
        'targetAmount': g.targetAmount,
        'currentAmount': g.currentAmount,
        'imagePath': g.imagePath,
        'deadline': g.deadline?.toIso8601String(),
        'createdAt': g.createdAt.toIso8601String(),
      };
    }).toList();

    final payload = {
      'app': 'Tabungan',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': txs,
      'saving_goals': goals,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static Future<void> downloadBackupFile() async {
    final jsonString = createBackupJsonString();
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final dateTag = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'backup_tabungan_$dateTag.json',
    );
  }

  /// ==========================================================================
  /// 2. RESTORE DATA DARI FILE JSON
  /// ==========================================================================
  static Future<int> restoreFromJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return -1; // Dibatalkan user
    }

    final fileBytes = result.files.first.bytes;
    if (fileBytes == null) {
      throw Exception('Gagal membaca isi file backup.');
    }

    final rawString = utf8.decode(fileBytes);
    return restoreFromJsonString(rawString);
  }

  static Future<int> restoreFromJsonString(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic> ||
        !decoded.containsKey('transactions')) {
      throw Exception('Format file backup tidak valid.');
    }

    final txList = decoded['transactions'] as List<dynamic>;
    final txBox = HiveService.box;
    await txBox.clear();

    for (final item in txList) {
      final map = item as Map<String, dynamic>;
      final tx = TransactionModel(
        id: map['id'].toString(),
        title: map['title'].toString(),
        amount: (map['amount'] as num).toDouble(),
        isIncome: map['isIncome'] as bool,
        category: map['category'].toString(),
        date: DateTime.parse(map['date'].toString()),
      );
      await txBox.put(tx.id, tx);
    }

    final gBox = HiveService.goalsBox;
    if (decoded['saving_goals'] is List<dynamic>) {
      await gBox.clear();
      for (final item in (decoded['saving_goals'] as List<dynamic>)) {
        final map = item as Map<String, dynamic>;
        final goal = SavingGoalModel(
          id: map['id'].toString(),
          title: map['title'].toString(),
          targetAmount: (map['targetAmount'] as num).toDouble(),
          currentAmount: (map['currentAmount'] as num).toDouble(),
          imagePath: map['imagePath']?.toString(),
          deadline: map['deadline'] != null
              ? DateTime.tryParse(map['deadline'].toString())
              : null,
          createdAt: map['createdAt'] != null
              ? DateTime.parse(map['createdAt'].toString())
              : DateTime.now(),
        );
        await gBox.put(goal.id, goal);
      }
    }

    return txList.length;
  }

  /// ==========================================================================
  /// 3. EXPORT LAPORAN PDF
  /// ==========================================================================
  static Future<void> exportFinancialPdf() async {
    final pdf = pw.Document();
    final txs = HiveService.box.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final goals = HiveService.goalsBox.values.toList();

    double totalIncome = 0;
    double totalExpense = 0;
    for (final t in txs) {
      if (t.isIncome) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }
    final balance = totalIncome - totalExpense;

    final darkForest = PdfColor.fromHex('#0F291E');
    final emerald = PdfColor.fromHex('#1B9C67');
    final softMint = PdfColor.fromHex('#E5F2EC');
    final expenseRed = PdfColor.fromHex('#C84B31');
    final borderGrey = PdfColor.fromHex('#E2EAE5');
    final textMuted = PdfColor.fromHex('#63736B');

    final printDate =
        DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header Laporan
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: darkForest,
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LAPORAN TABUNGAN',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('#A3B8AE'),
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      _rupiah.format(balance),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Dicetak pada',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('#A3B8AE'),
                        fontSize: 9,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      printDate,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Ringkasan Pemasukan & Pengeluaran
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: softMint,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Pemasukan',
                          style: pw.TextStyle(color: textMuted, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _rupiah.format(totalIncome),
                        style: pw.TextStyle(
                          color: emerald,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: borderGrey),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Pengeluaran',
                          style: pw.TextStyle(color: textMuted, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _rupiah.format(totalExpense),
                        style: pw.TextStyle(
                          color: expenseRed,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Bagian Target Tabungan (Jika Ada)
          if (goals.isNotEmpty) ...[
            pw.Text(
              'Target Tabungan (${goals.length})',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: darkForest,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: darkForest),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              headers: ['Nama Target', 'Terkumpul', 'Target', 'Progress'],
              data: goals.map((g) {
                final pct = g.targetAmount > 0
                    ? ((g.currentAmount / g.targetAmount) * 100)
                        .clamp(0, 100)
                        .toStringAsFixed(0)
                    : '0';
                return [
                  g.title,
                  _rupiah.format(g.currentAmount),
                  _rupiah.format(g.targetAmount),
                  '$pct%',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
          ],

          // Tabel Mutasi Transaksi
          pw.Text(
            'Riwayat Transaksi (${txs.length})',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: darkForest,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: darkForest),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            headers: ['Tanggal', 'Judul', 'Kategori', 'Nominal'],
            data: txs.map((t) {
              final dateStr = DateFormat('dd/MM/yyyy').format(t.date);
              final sign = t.isIncome ? '+' : '-';
              return [
                dateStr,
                t.title,
                t.category,
                '$sign${_rupiah.format(t.amount)}',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final dateTag = DateFormat('yyyyMMdd').format(DateTime.now());
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Laporan_Tabungan_$dateTag.pdf',
    );
  }
}