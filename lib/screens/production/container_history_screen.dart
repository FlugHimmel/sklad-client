import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/container.dart';
import '../../models/operation.dart';
import '../../services/api_client.dart';
import '../../services/operations_repo.dart';

class ContainerHistoryScreen extends StatefulWidget {
  final StockContainer container;
  const ContainerHistoryScreen({super.key, required this.container});

  @override
  State<ContainerHistoryScreen> createState() =>
      _ContainerHistoryScreenState();
}

class _ContainerHistoryScreenState extends State<ContainerHistoryScreen> {
  List<ContainerHistoryRow> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = OperationsRepo(context.read<ApiClient>());
      final rows = await repo.containerHistory(widget.container.id);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _rollback(ContainerHistoryRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Откатить операцию?'),
        content: Text(
            'Это вернёт все тары к состоянию до операции #${row.operationId}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Откатить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = OperationsRepo(context.read<ApiClient>());
      await repo.rollback(row.operationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Операция откатана')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}.${l.year} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  Color _dirColor(String dir) {
    switch (dir) {
      case 'from':
        return Colors.orange;
      case 'to':
        return Colors.green;
      case 'scrap':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('История: ${widget.container.code}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _rows.isEmpty
                  ? const Center(child: Text('Пока никаких операций'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _rows.length,
                      itemBuilder: (_, i) {
                        final r = _rows[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: _dirColor(r.direction),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${r.operationTypeDisplay}  ·  ${r.directionDisplay}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            _fmtDate(r.createdAt),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.undo),
                                      onPressed: () => _rollback(r),
                                      tooltip: 'Откатить',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${r.productArticle} · ${r.productName}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${r.qty} шт',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (r.scrapReasonDisplay.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 8),
                                        child: Text(
                                          '(${r.scrapReasonDisplay})',
                                          style: const TextStyle(
                                              color: Colors.red),
                                        ),
                                      ),
                                  ],
                                ),
                                if (r.comment.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      r.comment,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                if (r.createdByUsername != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Записал: ${r.createdByUsername}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black38,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
