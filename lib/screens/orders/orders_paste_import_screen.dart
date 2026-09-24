import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';
import '../../services/orders_repo.dart';

class OrdersPasteImportScreen extends StatefulWidget {
  const OrdersPasteImportScreen({super.key});
  @override
  State<OrdersPasteImportScreen> createState() =>
      _OrdersPasteImportScreenState();
}

class _OrdersPasteImportScreenState extends State<OrdersPasteImportScreen> {
  final _textCtrl = TextEditingController();
  String _mode = 'skip_existing';
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final text = _textCtrl.text;
    if (text.trim().isEmpty) {
      setState(() => _error = 'Вставьте данные из Excel');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final resp = await context.read<ApiClient>().post(
        '/api/orders/import-paste/',
        body: {'text': text, 'mode': _mode, 'kind': 'production'},
      );
      if (!mounted) return;
      setState(() => _result = resp as Map<String, dynamic>);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _pasteFromClipboardHint() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Скопируйте таблицу в Excel → выделите → Ctrl+C → '
          'вернитесь сюда и вставьте в поле (Ctrl+V или долгое нажатие)'),
      duration: Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Импорт заказов из Excel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Как копировать',
            onPressed: _pasteFromClipboardHint,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          const Card(
            color: Color(0xFFFFF8E1),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Как использовать:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(
                    '1. В Excel выделите таблицу заказов (включая шапку)\n'
                    '2. Ctrl+C\n'
                    '3. Вставьте сюда (Ctrl+V) или кнопкой ниже\n'
                    '4. Проверьте предпросмотр → «Импортировать»',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Существующие заказы:'),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _mode,
              items: const [
                DropdownMenuItem(value: 'skip_existing',
                    child: Text('Пропустить')),
                DropdownMenuItem(value: 'append_lines',
                    child: Text('Добавить позиции')),
              ],
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _mode = v ?? 'skip_existing'),
            ),
          ]),
          const SizedBox(height: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _textCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Вставьте сюда таблицу из Excel '
                    '(Ctrl+V или долгое нажатие)...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final data =
                            await Clipboard.getData('text/plain');
                        if (data != null && data.text != null) {
                          _textCtrl.text = data.text!;
                        }
                      },
                icon: const Icon(Icons.content_paste),
                label: const Text('Вставить из буфера'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _import,
                icon: _busy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload),
                label: const Text('Импортировать'),
              ),
            ),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Ошибка: $_error',
                  style: TextStyle(color: Colors.red.shade900)),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 8),
            Expanded(flex: 2, child: _buildResult(_result!)),
          ],
        ]),
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> r) {
    final created = (r['created_orders'] as List?)?.cast<String>() ?? [];
    final skipped = (r['skipped_orders'] as List?) ?? [];
    final errors = (r['errors'] as List?) ?? [];
    final summary = (r['summary'] as Map?) ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(children: [
          Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text('Создано заказов: ${summary['orders_created'] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            Text('Строк: ${summary['lines_created'] ?? 0}'),
          ]),
          if (created.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Номера: ${created.join(", ")}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          if (skipped.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.skip_next, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text('Пропущено заказов: ${skipped.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            ...skipped.map((s) {
              final m = s as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text('${m['number']} — ${m['reason']}',
                    style: const TextStyle(fontSize: 12)),
              );
            }),
          ],
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.error, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text('Ошибок: ${errors.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            ...errors.map((e) {
              final m = e as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text(
                    '${m['order'] ?? ''} ${m['line'] ?? ''}: ${m['error'] ?? ''}',
                    style: const TextStyle(fontSize: 12)),
              );
            }),
          ],
          if (summary['orders_created'] != 0) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Готово — вернуться к списку'),
            ),
          ],
        ]),
      ),
    );
  }
}
