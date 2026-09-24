import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/containers_repo.dart';
import '../scanner/scanner_screen.dart';

class TransferWarehouse {
  final int id;
  final String code;
  final String name;
  TransferWarehouse({required this.id, required this.code, required this.name});
  factory TransferWarehouse.fromJson(Map<String, dynamic> j) =>
      TransferWarehouse(
        id: j['id'] as int,
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
      );
}

class _ScannedContainer {
  final String code;
  final int? id;
  final String? name;
  final String? quantity;
  final String? warehouseName;
  final String? error;

  _ScannedContainer({
    required this.code,
    this.id,
    this.name,
    this.quantity,
    this.warehouseName,
    this.error,
  });
}

class ContainerTransferScreen extends StatefulWidget {
  final String? prefillCode;
  const ContainerTransferScreen({super.key, this.prefillCode});

  @override
  State<ContainerTransferScreen> createState() =>
      _ContainerTransferScreenState();
}

class _ContainerTransferScreenState extends State<ContainerTransferScreen> {
  List<TransferWarehouse> _warehouses = [];
  TransferWarehouse? _from;
  TransferWarehouse? _to;
  final _codeCtrl = TextEditingController();
  final List<_ScannedContainer> _scanned = [];
  bool _loadingWh = true;
  String? _error;
  bool _busy = false;
  bool _prefillApplied = false;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    setState(() { _loadingWh = true; _error = null; });
    try {
      final api = context.read<ApiClient>();
      final resp = await api.get('/api/warehouses/');
      List<dynamic> raw;
      if (resp is Map<String, dynamic> && resp['results'] is List) {
        raw = resp['results'] as List;
      } else if (resp is List) {
        raw = resp;
      } else {
        raw = const [];
      }
      final list = raw
          .map((e) => TransferWarehouse.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _warehouses = list;
        if (list.isEmpty) {
          _from = null;
          _to = null;
        } else {
          _from = list.firstWhere((w) => w.code == 'MAIN',
              orElse: () => list.first);
          _to = list.firstWhere((w) => w.code == 'ZLK',
              orElse: () => list.length > 1 ? list[1] : list.first);
        }
      });
      if (!_prefillApplied &&
          widget.prefillCode != null &&
          widget.prefillCode!.isNotEmpty) {
        _prefillApplied = true;
        await _addByCode(widget.prefillCode!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingWh = false);
    }
  }

  Future<void> _scanWithCamera() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (result == null || result.isEmpty) return;
    await _addByCode(result);
  }

  Future<void> _addByCode(String raw) async {
    final c = raw.trim();
    if (c.isEmpty) return;
    if (_scanned.any((s) => s.code == c)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Тара $c уже в списке')));
      _codeCtrl.clear();
      return;
    }
    setState(() {
      _scanned.add(_ScannedContainer(code: c, error: 'проверяется...'));
    });
    _codeCtrl.clear();
    try {
      final resp = await context
          .read<ApiClient>()
          .get('/api/containers/by-code/', query: {'code': c});
      final data = resp as Map<String, dynamic>;
      final lines = (data['lines'] ?? []) as List;
      final firstLine =
          lines.isNotEmpty ? (lines.first as Map<String, dynamic>) : null;
      if (!mounted) return;
      setState(() {
        final idx = _scanned.indexWhere((s) => s.code == c);
        if (idx == -1) return;
        _scanned[idx] = _ScannedContainer(
          code: c,
          id: data['id'] as int?,
          name: (data['product_name'] ??
                  firstLine?['product_name'] ??
                  data['name'] ??
                  '')
              .toString(),
          quantity: (data['quantity'] ??
                  firstLine?['quantity'] ??
                  '0')
              .toString(),
          warehouseName: (data['warehouse_name'] ?? '').toString(),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final idx = _scanned.indexWhere((s) => s.code == c);
        if (idx == -1) return;
        _scanned[idx] = _ScannedContainer(code: c, error: 'не найдена');
      });
    }
  }

  Future<void> _transferAll() async {
    if (_from == null || _to == null) return;
    if (_from!.id == _to!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Откуда и Куда — один и тот же склад')));
      return;
    }
    final codes = _scanned
        .where((s) => s.error == null && s.id != null)
        .map((s) => s.code)
        .toList();
    if (codes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет валидных тар для перемещения')));
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ContainersRepo(context.read<ApiClient>());
      final resp = await repo.bulkMove(
        codes: codes,
        warehouseId: _to!.id,
        comment: 'Перемещение ${_from!.name} → ${_to!.name}',
      );
      if (!mounted) return;
      final moved = (resp['moved'] as List?) ?? const [];
      final notFound = (resp['not_found'] as List?) ?? const [];
      final errs = (resp['errors'] as List?) ?? const [];
      final sb = StringBuffer()
        ..writeln('Перемещено: ${moved.length}')
        ..writeln('Не найдено: ${notFound.length}')
        ..writeln('Ошибок: ${errs.length}');
      if (notFound.isNotEmpty) {
        sb.writeln();
        sb.writeln('Не найдено: ${notFound.join(", ")}');
      }
      if (errs.isNotEmpty) {
        sb.writeln();
        for (final e in errs) {
          sb.writeln('${e['code']}: ${e['error']}');
        }
      }
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Готово'),
          content: SingleChildScrollView(child: Text(sb.toString())),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ок'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() {
        _scanned.clear();
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _scanned.where((s) => s.error == null && s.id != null).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Перемещение ($valid)'),
        actions: [
          if (_scanned.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Очистить список',
              onPressed: () => setState(() => _scanned.clear()),
            ),
        ],
      ),
      body: _loadingWh
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(
                              child: _whPicker('Откуда', _from,
                                  (w) => setState(() => _from = w)),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward, size: 20),
                            ),
                            Expanded(
                              child: _whPicker('Куда', _to,
                                  (w) => setState(() => _to = w)),
                            ),
                          ]),
                          const SizedBox(height: 12),
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
                              tooltip: 'Добавить',
                              onPressed: () => _addByCode(_codeCtrl.text),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.qr_code_scanner),
                              tooltip: 'Сканировать',
                              onPressed: _scanWithCamera,
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildList()),
                    if (_scanned.isNotEmpty)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _transferAll,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.local_shipping),
                              label: Text(_busy
                                  ? 'Перемещаю...'
                                  : 'Переместить всё на «${_to?.name ?? ''}»'),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _whPicker(String label, TransferWarehouse? selected,
      ValueChanged<TransferWarehouse?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey)),
        const SizedBox(height: 2),
        DropdownButtonFormField<int>(
          value: selected?.id,
          isDense: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          items: _warehouses
              .map((w) => DropdownMenuItem(
                    value: w.id,
                    child: Text(w.name,
                        style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            onChanged(_warehouses.firstWhere((w) => w.id == id));
          },
        ),
      ],
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
              const Text('Отсканируйте или введите код тары',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              const Text('Можно отсканировать несколько тар подряд',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
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
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: ok ? Colors.green : Colors.red,
            child: Icon(ok ? Icons.check : Icons.close, color: Colors.white),
          ),
          title: Text(s.code,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          subtitle: ok
              ? Text(
                  '${s.name ?? ''}\nСейчас: ${s.warehouseName ?? '?'} · ${s.quantity ?? '?'} шт',
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
