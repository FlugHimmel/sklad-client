// Экспорт CSV для Flutter Web.
// Использует package:web (замена устаревшего dart:html).
// ignore_for_file: avoid_web_libraries_in_flutter

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
class CsvExporter {
  /// Экспорт в CSV. Автоматически добавляет BOM и оборачивает значения.
  static void export({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final sb = StringBuffer();
    sb.write('\uFEFF'); // BOM для Excel
    sb.writeln(headers.map(_escape).join(';'));
    for (final r in rows) {
      sb.writeln(r.map(_escape).join(';'));
    }
    final bytes = utf8.encode(sb.toString());
    _download(bytes, filename);
  }

  static String _escape(String? s) {
    if (s == null) return '';
    final v = s.toString();
    if (v.contains(';') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static void _download(List<int> bytes, String filename) {
    final uint8 = Uint8List.fromList(bytes);
    final blob = web.Blob(
      [uint8.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor =
        web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = filename;
    anchor.style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  /// Дата для имени файла: 2026-09-14
  static String today() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Красивый формат числа: 150.000 → 150; 10.500 → 10.5
  static String numStr(String? s) {
    if (s == null || s.isEmpty) return '';
    final n = double.tryParse(s);
    if (n == null) return s;
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    return n.toString().replaceAll(RegExp(r'\.?0+$'), '');
  }

  /// Дата/время в формате dd.MM.yyyy HH:mm
  static String dateTimeStr(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}.'
        '${l.year} '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }
}
