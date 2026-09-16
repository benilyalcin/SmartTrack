import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;
import 'package:share_plus/share_plus.dart';

class KLineLogExportService {
  KLineLogExportService._();

  static Future<void> exportAndShare(List<String> lines) async {
    final monoFont = await PdfGoogleFonts.robotoMonoRegular();
    final boldFont = await PdfGoogleFonts.robotoMonoBold();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: monoFont, bold: boldFont),
    );

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'SmartTrack K-LINE Log'),
          pw.Text(
            'Oluşturulma: ${_fmt(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          ...lines.map(
            (line) => pw.Text(line, style: const pw.TextStyle(fontSize: 7)),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/smarttrack_kline_log_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(path)],
      fileNameOverrides: ['smarttrack_kline_log.pdf'],
    );
  }

  static String _fmt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year} $h:$min';
  }
}
