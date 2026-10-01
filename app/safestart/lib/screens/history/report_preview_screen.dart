import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class ReportPreviewScreen extends StatelessWidget {
  const ReportPreviewScreen({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Report Preview')),
    body: SafeArea(
      child: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: 'safestart-prototype-report.pdf',
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: true,
        onError: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Unable to preview this PDF. Return to History and try again.',
            ),
          ),
        ),
      ),
    ),
  );
}
