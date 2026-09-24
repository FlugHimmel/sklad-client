import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/container.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/containers_repo.dart';
import '../../services/shipment_repo.dart';
import '../scanner/scanner_screen.dart';

/// Экран «Подготовить отгрузку» — для литейщиков.
///
/// Верх — «НАКЛАДНАЯ ЗА СЕГОДНЯ»: формирует одну накладную на все тары,
///   которые сейчас на Завод и ещё не в накладных.
/// Низ — «Вручную»: скан/выбор отдельных тар → своя накладная.
class ShippingDocsScreen extends StatefulWidget {
  const ShippingDocsScreen({super.key});

  @override
  State<ShippingDocsScreen> createState() => _ShippingDocsScreenState();
}

class _Scanned {
  final String code;
  final int? id;
  final String? productArticle;
  final String? productName;
  final String? quantity;
  final String? warehouseName;
  final String? error;
  _Scanned({
    required this.code, this.id, this.productArticle, this.productName,
    this.quantity, this.warehouseName, this.error,
  });
}

class _ShippingDocsScreenState extends State<ShippingDocsScreen> {
  final _codeCtrl = TextEditingController();
  final List<_Scanned> _scanned = [];
  bool _busy = false;
  bool _todayLoading = true;
  String? _todayError;
  List<StockContainer> _todayContainers = [];
  bool _isFoundry = false;

  @override
  void initState() {
    super.initState();
    _initRole();
    _loadTodayContainers();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _initRole() {
    try {
      final auth = context.read<AuthService>();
      final role = (auth.user?['role'] ?? 'user').toString();
      _isFoundry = role == 'foundry';
    } catch (_) {}
  }

  Future<void> _loadTodayContainers() async {
    setState(() {
      _todayLoading = true;
      _todayError = null;
    });
    try {
      final repo = ContainersRepo(context.read<ApiClient>());
      final page = await repo.list(pageSize: 500);
      if (!mounted) return;
      setState(() {
        _todayContainers = page.items
            .where((c) =>
                c.shippedAt == null &&
                (c.warehouseName ?? '').toLowerCase().contains('злк'))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _todayError = e.toString());
    } finally {
      if (mounted) setState(() => _todayLoading = false);
    }
  }

  Future<void> _createTodayNote() async {
    if (_todayContainers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('На Завод нет тар для отгрузки')));
      return;
    }

    final total = _todayContainers.fold<double>(
        0, (a, c) => a + (double.tryParse(c.quantity) ?? 0));

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Накладная за сегодня'),
        content: Text(
          'Будет создана накладная на ${_todayContainers.length} тар '
          '(${total.toStringAsFixed(0)} шт).\n\n'
          'Эти тары попадут в накладную и больше не будут '
          'включаться в следующие.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('Создать'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final repo = ShipmentRepo(context.read<ApiClient>());
      final note = await repo.createNoteForToday();
      final bytes = await repo.notePdf(note.id);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'note-${note.number}.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Накладная ${note.number} · тар ${note.linesCount} · '
            '${note.totalWeightKg} кг'),
        backgroundColor: Colors.green,
      ));
      await _loadTodayContainers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'),
              backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Старый механизм (ручной) ──────────────────────────────────────

  Future<void> _scan() async {
    final code = await Navigator.push<String>(context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (code == null || code.isEmpty) return;
    await _addByCode(code);
  }

  Future<void> _addByCode(String raw) async {
    final code = raw.trim();
    if (code.isEmpty) return;
    if (_scanned.any((s) => s.code == code)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Тара $code уже в списке')));
      _codeCtrl.clear();
      return;
    }
    if (code.startsWith('PART:')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Это ШК детали, а не тары')));
      _codeCtrl.clear();
      return;
    }
    setState(() => _scanned.add(_Scanned(code: code, error: 'проверяется...')));
    _codeCtrl.clear();
    try {
      final resp = await context.read<ApiClient>()
          .get('/api/containers/by-code/', query: {'code': code});
      final data = resp as Map<String, dynamic>;
      final lines = (data['lines'] ?? []) as List;
      final first = lines.isNotEmpty ? lines.first as Map<String, dynamic> : null;
      if (!mounted) return;
      setState(() {
        final idx = _scanned.indexWhere((s) => s.code == code);
        if (idx == -1) return;
        _scanned[idx] = _Scanned(
          code: code,
          id: data['id'] as int?,
          productArticle: (data['product_article'] ??
              first?['product_article'] ?? '').toString(),
          productName: (data['product_name'] ??
              first?['product_name'] ?? '').toString(),
          quantity: (data['quantity'] ?? first?['quantity'] ?? '0').toString(),
          warehouseName: (data['warehouse_name'] ?? '').toString(),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final idx = _scanned.indexWhere((s) => s.code == code);
        if (idx == -1) return;
        _scanned[idx] = _Scanned(code: code, error: 'не найдена');
      });
    }
  }

  Future<void> _pickFromList() async {
    List<StockContainer> containers;
    try {
      final repo = ContainersRepo(context.read<ApiClient>());
      final page = await repo.list(page: 1, pageSize: 500);
      containers = page.items.where((c) => c.shippedAt == null).toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')));
      return;
    }
    final already = _scanned.map((s) => s.code).toSet();
    containers = containers.where((c) => !already.contains(c.code)).toList();

    if (!mounted) return;
    final picked = await showDialog<List<StockContainer>>(
      context: context,
      builder: (_) => _PickContainersDialog(all: containers),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    for (final c in picked) {
      if (_scanned.any((s) => s.code == c.code)) continue;
      final first = c.lines.isNotEmpty ? c.lines.first : null;
      _scanned.add(_Scanned(
        code: c.code,
        id: c.id,
        productArticle: first?.productArticle ?? c.productArticle ?? '',
        productName: first?.productName ?? c.productName ?? '',
        quantity: first?.quantity ?? c.quantity,
        warehouseName: c.warehouseName,
      ));
    }
    if (mounted) setState(() {});
  }

  bool get _hasValid =>
      _scanned.any((s) => s.id != null && s.error == null) && !_busy;

  List<String> get _validCodes => _scanned
      .where((s) => s.id != null && s.error == null)
      .map((s) => s.code)
      .toList();

  Future<void> _printNote() async {
    final codes = _validCodes;
    if (codes.isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = ShipmentRepo(context.read<ApiClient>());
      final note = await repo.createNote(codes: codes, comment: '');
      final bytes = await repo.notePdf(note.id);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'note-${note.number}.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Накладная ${note.number} · тар ${note.linesCount} · '
            '${note.totalWeightKg} кг'),
      ));
      setState(_scanned.clear);
      await _loadTodayContainers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printPackingAll() async {
    final ids = _scanned
        .where((s) => s.id != null && s.error == null)
        .map((s) => s.id!)
        .toList();
    if (ids.isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = ContainersRepo(context.read<ApiClient>());
      final bytes = await repo.bulkPackingPdf(ids);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'packing-all.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Упаковочных листов: ${ids.length}'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _scanned.where((s) => s.id != null && s.error == null).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isFoundry
            ? 'Отгрузка ($valid)'
            : 'Подготовить отгрузку ($valid)'),
        actions: [
          if (_scanned.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Очистить список',
              onPressed: () => setState(_scanned.clear),
            ),
        ],
      ),
      body: ListView(children: [
        if (_isFoundry) _buildTodayBlock(),
        _buildManualBlock(),
      ]),
    );
  }

  // ─── ВЕРХНИЙ БЛОК: накладная за сегодня ────────────────────────────
  Widget _buildTodayBlock() {
    final totalQty = _todayContainers.fold<double>(
        0, (a, c) => a + (double.tryParse(c.quantity) ?? 0));

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.today, color: Colors.green.shade800, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('НАКЛАДНАЯ ЗА СЕГОДНЯ',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Сформирует одну накладную на все тары,\n'
            'которые сейчас на Завод и ещё не в накладной.',
            style: TextStyle(fontSize: 12, color: Colors.green.shade900),
          ),
          const SizedBox(height: 10),
          if (_todayLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ))
          else if (_todayError != null)
            Text('Ошибка: $_todayError',
                style: const TextStyle(color: Colors.red, fontSize: 13))
          else if (_todayContainers.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Сейчас на Завод нет тар для отгрузки',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade700),
              ),
            )
          else ...[
            // Предпросмотр
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Готово к отправке: ',
                        style: TextStyle(fontSize: 13,
                            color: Colors.green.shade800)),
                    Text('${_todayContainers.length} тар · '
                        '${totalQty.toStringAsFixed(0)} шт',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900)),
                  ]),
                  const Divider(height: 12),
                  ..._todayContainers.take(5).map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Icon(Icons.qr_code, size: 12,
                              color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(c.code,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text('${c.quantity} шт',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                      )),
                  if (_todayContainers.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '...и ещё ${_todayContainers.length - 5} тар',
                        style: TextStyle(fontSize: 11,
                            color: Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _busy ? null : _createTodayNote,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.receipt_long, size: 22),
                label: const Text('СОЗДАТЬ НАКЛАДНУЮ',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : _loadTodayContainers,
              child: const Text('Обновить список', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  // ─── НИЖНИЙ БЛОК: вручную (старый механизм) ───────────────────────
  Widget _buildManualBlock() {
    return Container(
      margin: EdgeInsets.fromLTRB(12, _isFoundry ? 0 : 12, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.edit_note,
                color: Colors.blueGrey.shade700, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('ВРУЧНУЮ (несколько тар)',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Сканируй конкретные тары и создай накладную только на них.',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
          ),
          const SizedBox(height: 10),

          // Поле ввода
          Row(children: [
            Expanded(
              child: TextField(
                controller: _codeCtrl,
                onSubmitted: _addByCode,
                decoration: const InputDecoration(
                  hintText: 'Код тары (TARA-XXXXXX)',
                  prefixIcon: Icon(Icons.qr_code_2),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add),
              onPressed: () => _addByCode(_codeCtrl.text),
              style: IconButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _scan,
              style: IconButton.styleFrom(
                  backgroundColor: Colors.black87),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              icon: const Icon(Icons.list),
              onPressed: _pickFromList,
            ),
          ]),

          if (_scanned.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ..._scanned.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              final ok = s.error == null && s.id != null;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: ok ? Colors.green : Colors.red,
                  child: Icon(ok ? Icons.check : Icons.close,
                      color: Colors.white, size: 16),
                ),
                title: Text(s.code,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace', fontSize: 13)),
                subtitle: ok
                    ? Text('${s.productArticle} · ${s.quantity} шт',
                        style: const TextStyle(fontSize: 11))
                    : Text(s.error ?? '—',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      setState(() => _scanned.removeAt(i)),
                ),
              );
            }),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _hasValid ? _printNote : null,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.receipt_long, size: 20),
                label: Text('НАКЛАДНАЯ (${_validCodes.length})',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _hasValid ? _printPackingAll : null,
                icon: const Icon(Icons.description, size: 18),
                label: const Text('УПАКОВОЧНЫЕ ЛИСТЫ'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Диалог выбора тар из списка
// ───────────────────────────────────────────────────────────────────────
class _PickContainersDialog extends StatefulWidget {
  final List<StockContainer> all;
  const _PickContainersDialog({required this.all});

  @override
  State<_PickContainersDialog> createState() => _PickContainersDialogState();
}

class _PickContainersDialogState extends State<_PickContainersDialog> {
  final _searchCtrl = TextEditingController();
  final Set<int> _picked = {};
  late List<StockContainer> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.all;
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.all;
      } else {
        _filtered = widget.all.where((c) {
          if (c.code.toLowerCase().contains(q)) return true;
          for (final l in c.lines) {
            if ((l.productArticle ?? '').toLowerCase().contains(q)) return true;
            if ((l.productName ?? '').toLowerCase().contains(q)) return true;
          }
          return false;
        }).toList();
      }
    });
  }

  void _toggle(StockContainer c) {
    setState(() {
      if (_picked.contains(c.id)) {
        _picked.remove(c.id);
      } else {
        _picked.add(c.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
              child: Row(children: [
                const Icon(Icons.list, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Выбор тар (${widget.all.length} доступно)',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск по коду или артикулу',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                TextButton.icon(
                  onPressed: _filtered.isEmpty ? null : () {
                    setState(() {
                      _picked.addAll(_filtered.map((c) => c.id));
                    });
                  },
                  icon: const Icon(Icons.done_all, size: 18),
                  label: Text('Выбрать все (${_filtered.length})'),
                ),
                if (_picked.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(_picked.clear),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Снять'),
                  ),
                const Spacer(),
                if (_picked.isNotEmpty)
                  Chip(
                    label: Text('Выбрано: ${_picked.length}'),
                    backgroundColor: Colors.teal.shade50,
                  ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text('Ничего не найдено',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final c = _filtered[i];
                        final checked = _picked.contains(c.id);
                        final content = c.lines.isEmpty
                            ? '—'
                            : c.lines
                                .map((l) =>
                                    '${l.productArticle} × ${l.quantity}')
                                .join(', ');
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (_) => _toggle(c),
                          title: Text(c.code,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                  fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(content,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                  '${c.quantity} шт · ${c.warehouseName ?? '—'}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black54)),
                            ],
                          ),
                          isThreeLine: true,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _picked.isEmpty
                        ? null
                        : () {
                            final chosen = widget.all
                                .where((c) => _picked.contains(c.id))
                                .toList();
                            Navigator.pop(context, chosen);
                          },
                    icon: const Icon(Icons.add),
                    label: Text(_picked.isEmpty
                        ? 'Выберите тары'
                        : 'Добавить: ${_picked.length}'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
