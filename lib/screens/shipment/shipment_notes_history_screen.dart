import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/shipment_repo.dart';

/// История накладных на отгрузку Завод → Модель.
class ShipmentNotesHistoryScreen extends StatefulWidget {
  const ShipmentNotesHistoryScreen({super.key});

  @override
  State<ShipmentNotesHistoryScreen> createState() =>
      _ShipmentNotesHistoryScreenState();
}

class _ShipmentNotesHistoryScreenState
    extends State<ShipmentNotesHistoryScreen> {
  final _searchCtrl = TextEditingController();
  final List<ShipmentNoteListItem> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  bool _initialLoading = true;
  String? _error;

  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ShipmentRepo get _repo => ShipmentRepo(context.read<ApiClient>());

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _page = 1;
      }
    });
    try {
      final result = await _repo.listNotes(
        page: _page,
        pageSize: _pageSize,
        search: _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _total = result.count;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() {
        _loading = false;
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _items.length >= _total) return;
    _page += 1;
    await _load();
  }

  Future<void> _openNote(ShipmentNoteListItem item) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final detail = await _repo.noteDetail(item.id);
      if (!mounted) return;
      Navigator.pop(context); // закрываем крутилку
      await showDialog<void>(
        context: context,
        builder: (_) => _NoteDetailDialog(detail: detail),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _reprint(int noteId, String number) async {
    try {
      final bytes = await _repo.notePdf(noteId);
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'note-$number.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка печати: $e')));
    }
  }

  String _fmtKg(String s) {
    final d = double.tryParse(s);
    if (d == null) return s;
    return d.toStringAsFixed(3);
  }

  String _fmtQty(String s) {
    final d = double.tryParse(s);
    if (d == null) return s;
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('История накладных (${_items.length}/$_total)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _load(reset: true),
              decoration: InputDecoration(
                hintText: 'Поиск по номеру (ЗАВ-2026-0001)',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _load(reset: true);
                  },
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildList()),
          if (_items.length < _total && !_loading)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Icons.expand_more),
                  label: Text(
                      'Загрузить ещё (${_total - _items.length} осталось)'),
                ),
              ),
            ),
          if (_loading && _items.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _load(reset: true),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Накладных пока нет.\n'
            'Они появятся здесь после первого «Подготовить отгрузку».',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final item = _items[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.indigo.shade100,
            child: const Icon(Icons.receipt_long, color: Colors.indigo),
          ),
          title: Text(item.number,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          subtitle: Text(
            '${item.noteDate} · тар: ${item.linesCount} · '
            'кол-во: ${_fmtQty(item.totalQty)} · '
            '${_fmtKg(item.totalWeightKg)} кг'
            '${item.createdBy != null ? " · ${item.createdBy}" : ""}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: 'Перепечатать PDF',
                onPressed: () => _reprint(item.id, item.number),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => _openNote(item),
        );
      },
    );
  }
}

class _NoteDetailDialog extends StatelessWidget {
  final ShipmentNoteDetail detail;
  const _NoteDetailDialog({required this.detail});

  String _fmtKg(String s) {
    final d = double.tryParse(s);
    if (d == null) return s;
    return d.toStringAsFixed(3);
  }

  String _fmtQty(String s) {
    final d = double.tryParse(s);
    if (d == null) return s;
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toString();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 700;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWide ? 720 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height - 40,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(Icons.receipt_long,
                    size: 32, color: Colors.indigo.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(detail.number,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w900,
                              fontSize: 20)),
                      Text('от ${detail.noteDate}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Отправитель: ${detail.fromName}',
                        style: const TextStyle(fontSize: 12)),
                    if (detail.fromAddress.isNotEmpty)
                      Text(detail.fromAddress,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('Получатель: ${detail.toName}',
                        style: const TextStyle(fontSize: 12)),
                    if (detail.toAddress.isNotEmpty)
                      Text(detail.toAddress,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Содержимое:',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _buildTable(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Тар: ${detail.lines.length}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    Text('Кол-во: ${_fmtQty(detail.totalQty)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    Text('Вес: ${_fmtKg(detail.totalWeightKg)} кг',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.indigo)),
                  ],
                ),
              ),
              if (detail.comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Примечание: ${detail.comment}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(0.6),
        1: FlexColumnWidth(2.2),
        2: FlexColumnWidth(1.6),
        3: FlexColumnWidth(3.2),
        4: FlexColumnWidth(1.1),
        5: FlexColumnWidth(1.3),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: const [
            _Th('№', align: TextAlign.center),
            _Th('Код тары'),
            _Th('Артикул'),
            _Th('Наименование'),
            _Th('Кол-во', align: TextAlign.right),
            _Th('Вес, кг', align: TextAlign.right),
          ],
        ),
        ...detail.lines.map(
          (l) => TableRow(
            children: [
              _Td(Text(l.sequence.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12))),
              _Td(Text(l.code,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12))),
              _Td(Text(l.productArticle,
                  style: const TextStyle(fontSize: 12))),
              _Td(Text(l.productName,
                  style: const TextStyle(fontSize: 12))),
              _Td(Text(_fmtQty(l.quantity),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12))),
              _Td(Text(_fmtKg(l.weightKg),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
      ],
    );
  }
}

class _Th extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _Th(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _Td extends StatelessWidget {
  final Widget child;
  const _Td(this.child);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: child,
    );
  }
}
