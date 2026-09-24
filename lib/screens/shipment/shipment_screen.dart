import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/shipment_repo.dart';
import '../../services/warehouses_repo.dart';
import '../scanner/scanner_screen.dart';

class ShipmentScreen extends StatefulWidget {
  /// Заголовок окна, напр. «Отгрузка в цех».
  final String title;
  /// Описание в шапке, напр. «Завод / Литейка → Основной склад».
  final String subtitle;
  /// Код склада-источника, напр. 'ZLK'.
  final String fromWarehouseCode;
  /// Код склада-приёмника, напр. 'MAIN'.
  final String toWarehouseCode;
  /// Текст на большой кнопке: «ОТГРУЗИТЬ» или «ПРИНЯТЬ».
  final String actionVerb;
  /// Предлагать печать накладной после перемещения?
  final bool askPrintNote;

  const ShipmentScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fromWarehouseCode,
    required this.toWarehouseCode,
    required this.actionVerb,
    this.askPrintNote = true,
  });

  @override
  State<ShipmentScreen> createState() => _ShipmentScreenState();
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

class _ShipmentScreenState extends State<ShipmentScreen> {
  final _codeCtrl = TextEditingController();
  final List<_Scanned> _scanned = [];
  Warehouse? _from;
  Warehouse? _to;
  bool _loadingWh = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _loadWarehouses(); }

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _loadWarehouses() async {
    setState(() { _loadingWh = true; _error = null; });
    try {
      final list = await WarehousesRepo(context.read<ApiClient>()).list();
      Warehouse? from;
      Warehouse? to;
      for (final w in list) {
        if (w.code == widget.fromWarehouseCode) from = w;
        if (w.code == widget.toWarehouseCode) to = w;
      }
      if (from == null || to == null) {
        setState(() => _error =
            'Не нашёл склад ${widget.fromWarehouseCode} → ${widget.toWarehouseCode}');
      }
      if (!mounted) return;
      setState(() { _from = from; _to = to; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingWh = false);
    }
  }

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

  bool get _canTransfer {
    if (_from == null || _to == null || _busy) return false;
    final valid = _scanned
        .where((s) => s.id != null && s.error == null)
        .toList();
    if (valid.isEmpty) return false;
    // все валидные должны быть на складе-источнике
    return valid.every((s) => (s.warehouseName ?? '') == (_from!.name));
  }

  Future<void> _doTransfer() async {
    if (_from == null || _to == null) return;
    final codes = _scanned
        .where((s) => s.id != null && s.error == null)
        .map((s) => s.code).toList();
    if (codes.isEmpty) return;

    setState(() => _busy = true);
    try {
      final repo = ShipmentRepo(context.read<ApiClient>());
      final res = await repo.bulkTransfer(
        codes: codes,
        fromWarehouseId: _from!.id,
        toWarehouseId: _to!.id,
        comment: '${widget.title} ${_from!.name} → ${_to!.name}',
      );
      if (!mounted) return;

      final msg = StringBuffer()
        ..writeln('Перемещено: ${res.moved.length}')
        ..writeln('Не найдено: ${res.notFound.length}')
        ..writeln('Ошибок: ${res.errors.length}');
      if (res.notFound.isNotEmpty) {
        msg.writeln();
        msg.writeln('Не найдено: ${res.notFound.join(", ")}');
      }
      if (res.errors.isNotEmpty) {
        msg.writeln();
        for (final e in res.errors) {
          msg.writeln('${e['code']}: ${e['error']}');
        }
      }

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Готово'),
          content: SingleChildScrollView(child: Text(msg.toString())),
          actions: [
            if (res.moved.isNotEmpty && widget.askPrintNote)
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _printNote(codes);
                },
                icon: const Icon(Icons.print),
                label: const Text('Печать накладной'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _scanned.clear());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printNote(List<String> codes) async {
    if (_from == null || _to == null) return;
    try {
      final bytes = await ShipmentRepo(context.read<ApiClient>()).transferNotePdf(
        codes: codes,
        fromWarehouseId: _from!.id,
        toWarehouseId: _to!.id,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'transfer-note.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка печати: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _scanned.where((s) => s.id != null && s.error == null).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} ($valid)'),
        actions: [
          if (_scanned.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Очистить список',
              onPressed: () => setState(_scanned.clear),
            ),
        ],
      ),
      body: _loadingWh
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: Colors.blueGrey.shade50,
                    child: Text(widget.subtitle,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
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
                        tooltip: 'Добавить',
                        onPressed: () => _addByCode(_codeCtrl.text),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'Сканировать',
                        onPressed: _scan,
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _buildList()),
                  if (_scanned.isNotEmpty)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy || _scanned.isEmpty
                                  ? null
                                  : () async {
                                      final codes = _scanned
                                          .where((s) => s.id != null)
                                          .map((s) => s.code)
                                          .toList();
                                      if (codes.isEmpty) return;
                                      await _printNote(codes);
                                    },
                              icon: const Icon(Icons.print),
                              label: const Text('Накладная'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: _canTransfer ? _doTransfer : null,
                              icon: _busy
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.local_shipping, size: 22),
                              label: Text(
                                _busy
                                    ? 'Работаю...'
                                    : '${widget.actionVerb} ВСЁ ($valid)',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                ]),
    );
  }

  Widget _buildList() {
    if (_scanned.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_2, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('Сканируйте тары одну за другой',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              const Text('Отсканировали все? — нажмите большую кнопку внизу.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _scanned.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final s = _scanned[i];
        final ok = s.error == null && s.id != null;
        final onSource = (s.warehouseName ?? '') == (_from?.name ?? '');
        Color avColor;
        IconData avIcon;
        if (!ok) {
          avColor = Colors.red;
          avIcon = Icons.close;
        } else if (!onSource) {
          avColor = Colors.orange;
          avIcon = Icons.warning_amber;
        } else {
          avColor = Colors.green;
          avIcon = Icons.check;
        }
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: avColor,
            child: Icon(avIcon, color: Colors.white),
          ),
          title: Text(s.code,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          subtitle: ok
              ? Text(
                  '${s.productArticle ?? ''} · ${s.productName ?? ''}\n'
                  'Сейчас: ${s.warehouseName ?? '?'} · ${s.quantity ?? '?'} шт',
                  style: const TextStyle(fontSize: 12))
              : Text(s.error ?? '—',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
          isThreeLine: ok,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _scanned.removeAt(i)),
          ),
        );
      },
    );
  }
}
