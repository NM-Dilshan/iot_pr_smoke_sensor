import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/history_filter.dart';
import '../models/history_report.dart';
import '../models/safety_status.dart';

class ReportService {
  const ReportService({this.compress = true});
  final bool compress;

  static const title = 'SafeStart Prototype Alcohol Sensor Test Report';
  static const disclaimer =
      'This report contains prototype alcohol sensor readings and safety classifications from the SafeStart university project. It is not a certified breathalyzer report, medical assessment, or legal BAC determination.';

  Future<Uint8List> generate(HistoryReport report) async {
    final pdf = pw.Document(
      title: title,
      subject: disclaimer,
      author: 'SafeStart',
      compress: compress,
    );
    final analytics = report.analytics;
    final gold = PdfColor.fromHex('#FFC72C');
    final dark = PdfColor.fromHex('#111418');
    final summary = <List<String>>[
      ['Total Tests', '${analytics.total}'],
      for (final status in SafetyStatus.values)
        [
          status.name.toUpperCase(),
          '${analytics.count(status)} (${analytics.percentage(status).toStringAsFixed(1)}%)',
        ],
      [
        'Average Prototype Sensor Reading',
        analytics.averageReading.toStringAsFixed(3),
      ],
      [
        'Highest Prototype Sensor Reading',
        analytics.highestReading.toStringAsFixed(2),
      ],
      ['Vehicle Tests', '${analytics.vehicleCount}'],
      ['Office Tests', '${analytics.officeCount}'],
    ];
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 200,
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        header: (_) => pw.Container(
          width: double.infinity,
          color: dark,
          padding: const pw.EdgeInsets.all(16),
          margin: const pw.EdgeInsets.only(bottom: 18),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SafeStart',
                style: pw.TextStyle(
                  color: gold,
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Prototype Alcohol Sensor Test Report',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 14),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                report.isDemo
                    ? 'DEMO HISTORY - DEMO DATA'
                    : 'SAVED PROTOTYPE SENSOR RECORDS',
                style: pw.TextStyle(color: gold, fontSize: 10),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Divider(color: PdfColors.grey400),
            pw.Text(
              disclaimer,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        build: (_) => [
          if (report.profile != null) ...[
            pw.Text('Name: ${report.profile!.fullName}'),
            pw.Text('Employee ID: ${report.profile!.employeeId}'),
          ],
          pw.Text(
            'Generated: ${historyDate(report.generatedAt)} ${historyTime(report.generatedAt)} (local time)',
          ),
          pw.SizedBox(height: 6),
          pw.Text('Period: ${report.filter.periodLabel}'),
          pw.Text('Test type filter: ${report.filter.typeLabel}'),
          pw.Text('Date range: ${report.filter.rangeLabel} (inclusive)'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Analytics',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerCount: 0,
            data: summary,
            cellPadding: const pw.EdgeInsets.all(7),
            border: pw.TableBorder.all(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            report.isDemo
                ? 'Demo prototype records'
                : 'Saved prototype records',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (report.records.isEmpty)
            pw.Text('No test records found for this period.')
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Time',
                'Test Type',
                'Sensor Reading',
                'Status',
              ],
              data: [
                for (final record in report.records)
                  [
                    historyDate(record.timestamp),
                    historyTime(record.timestamp),
                    record.testType.label,
                    record.sensorReading.toStringAsFixed(2),
                    record.status.name.toUpperCase(),
                  ],
              ],
              headerDecoration: pw.BoxDecoration(color: dark),
              headerStyle: pw.TextStyle(
                color: gold,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.all(7),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),
        ],
      ),
    );
    return pdf.save();
  }
}
