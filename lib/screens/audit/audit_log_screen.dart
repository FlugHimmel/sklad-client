import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/audit.dart';
import '../../services/api_client.dart';
import '../../services/audit_repo.dart';
import '../../utils/csv_export.dart';
import '../../widgets/stale_banner.dart';

const Map<String, String> _fieldNames = {
  'article': 'Артикул',
  'name': 'Наименование',
  'product_type': 'Тип',
  'category_id': 'Категория',
  'uom': 'Ед. изм.',
  'weight_g': 'Вес, г',
  'min_stock': 'Мин. остаток',
  'is_active': 'Активен',
  'mo1_id': 'Mo1', 'mo2_id': 'Mo2', 'mo3_id': 'Mo3', 'mo4_id': 'Mo4',
  'mo5_id': 'Mo5', 'mo6_id': 'Mo6', 'mo7_id': 'Mo7', 'mo8_id': 'Mo8',
  'number': 'Номер',
  'kind': 'Тип заказа',
  'customer': 'Заказчик',
  'status': 'Статус',
  'due_date': 'Срок',
  'comment': 'Комментарий',
  'quantity_planned': 'План, шт',
  'quantity_done': 'Готово, шт',
  'quantity_shipped': 'Отгружено, шт',
  'sequence': 'п/п',
  'machine': '№станка',
  'ready_date': 'Готовность',
  'shipped_date': 'Отгружено (дата)',
  'reserve_qty': 'Задел',
  'places': 'Мест',
  'warehouse_id': 'Склад',
  'order_id': 'Заказ',
  'product_id': 'Артикул',
  'casting_id': 'Литьё',
  'quantity': 'Количество',
  'code': 'Код',
  'note': 'Примечание',
  'label_printed_at': 'Этикетка напечатана',
  'quantity_theory': 'По учёту',
  'quantity_fact': 'Факт',
  'movement_type': 'Тип движения',
  'warehouse_from_id': 'Откуда',
  'warehouse_to_id': 'Куда',
  'container_id': 'Тара',
  'production_run_id': 'Операция',
  'qty_source_used': 'Взято',
  'qty_good': 'Годных',
  'qty_scrap': 'Брак',
  'reserve_qty_qty': 'Задел',
  'username': 'Логин',
  'first_name': 'Имя',
  'last_name': 'Фамилия',
  'email': 'Email',
  'phone': 'Телефон',
  'role': 'Роль',
  'is_active_': 'Активен',
  'customer_name': 'Заказчик (печать)',
  'customer_address': 'Адрес заказчика',
  'supplier_name': 'Поставщик',
  'supplier_address': 'Адрес поставщика',
  'ownership_note': 'Примечание о праве',
  'packing_list_title': 'Заголовок упак. листа',
};

String _humanField(String key) => _fieldNames[key] ?? key;

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<AuditLog> _items = [];
  List<Map<String, dynamic>> _models = [];
  bool _loading = true;
  String? _error;
  String? _filterModel;
  String? _filterAction;
  String _datePreset = 'week';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static const _actions = [
    ('create', 'Создано', Colors.green),
    ('update', 'Изменено', Colors.orange),
    ('delete', 'Удалено', Colors.red),
  ];

  @override
  void initState() {
    super.initState();
    _setPreset('week', reload: false);
    _loadModels();
    _load();
  }

  @override
  void dispose() { _debounce?.cancel(); _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadModels() async {
    try {
      final models = await AuditRepo(context.read<ApiClient>()).models();
      if (!mounted) return;
      setState(() => _models = models);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await AuditRepo(context.read<ApiClient>()).list(
        search: _searchCtrl.text.trim(),
        model: _filterModel,
        action: _filterAction,
        dateFrom: _fmt(_dateFrom),
        dateTo: _fmt(_dateTo),
      );
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _fmt(DateTime? d) {
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  void _setPreset(String p, {bool reload = true}) {
    final now = DateTime.now();
    DateTime? f, t;
    switch (p) {
      case 'today':
        f = DateTime(now.year, now.month, now.day);
        t = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'week':
        f = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        t = now;
        break;
      case 'month':
        f = DateTime(now.year, now.month, 1);
        t = now;
        break;
      case 'all':
        f = null; t = null;
        break;
    }
    setState(() { _datePreset = p; _dateFrom = f; _dateTo = t; });
    if (reload) _load();
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _exportCsv() {
    if (_items.isEmpty) return;
    CsvExporter.export(
      filename: 'audit_${CsvExporter.today()}.csv',
      headers: const ['Когда', 'Кто', 'Объект', 'Действие', 'Что изменилось'],
      rows: _items.map((r) => [
        CsvExporter.dateTimeStr(DateTime.tryParse(r.createdAt)),
        r.userRepr,
        '${r.modelName} ${r.objectRepr}',
        r.actionDisplay,
        _changesText(r),
      ]).toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Экспортировано: ${_items.length} строк')));
  }

  String _changesText(AuditLog r) {
    if (r.action == 'create') return 'Создан объект';
    if (r.action == 'delete') return 'Удалён объект';
    final parts = <String>[];
    r.changes.forEach((k, v) {
      if (v is Map) {
        parts.add('${_humanField(k)}: ${v['from']} → ${v['to']}');
      }
    });
    return parts.join('; ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Журнал изменений (${_items.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.download),
            tooltip: 'Экспорт CSV', onPressed: _exportCsv),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        StaleBanner(onRefresh: _load),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            decoration: const InputDecoration(
              hintText: 'Поиск: объект, имя пользователя, модель',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(), isDense: true),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            const Text('Период:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            for (final p in const [
              ('today', 'Сегодня'), ('week', 'Неделя'),
              ('month', 'Месяц'), ('all', 'Всё время')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(p.$2),
                  selected: _datePreset == p.$1,
                  onSelected: (_) => _setPreset(p.$1))),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            const Text('Действие:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            FilterChip(label: const Text('Все'),
              selected: _filterAction == null,
              onSelected: (_) { setState(() => _filterAction = null); _load(); }),
            for (final a in _actions)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FilterChip(label: Text(a.$2),
                  selected: _filterAction == a.$1,
                  onSelected: (v) {
                    setState(() => _filterAction = v ? a.$1 : null);
                    _load();
                  })),
            const SizedBox(width: 16),
            const Text('Объект:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            FilterChip(label: const Text('Все'),
              selected: _filterModel == null,
              onSelected: (_) { setState(() => _filterModel = null); _load(); }),
            ..._models.take(12).map((m) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: FilterChip(
                label: Text('${m['model_name']} (${m['cnt']})'),
                selected: _filterModel == m['model_name'],
                onSelected: (v) {
                  setState(() => _filterModel = v ? m['model_name'] as String : null);
                  _load();
                }))),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    if (_items.isEmpty) {
      return const Center(child: Text('Изменений нет',
          style: TextStyle(color: Colors.grey)));
    }
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14, horizontalMargin: 12,
          headingRowHeight: 44, dataRowMinHeight: 34, dataRowMaxHeight: 120,
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
          columns: const [
            DataColumn(label: _Th('Когда')),
            DataColumn(label: _Th('Кто')),
            DataColumn(label: _Th('Объект')),
            DataColumn(label: _Th('Действие')),
            DataColumn(label: _Th('Что изменилось')),
          ],
          rows: _items.map(_buildRow).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(AuditLog r) {
    final dt = DateTime.tryParse(r.createdAt)?.toLocal();
    final when = dt == null ? '—'
        : '${dt.day.toString().padLeft(2, '0')}.'
          '${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';

    Color actionColor;
    switch (r.action) {
      case 'create': actionColor = Colors.green; break;
      case 'update': actionColor = Colors.orange; break;
      case 'delete': actionColor = Colors.red; break;
      default: actionColor = Colors.grey;
    }

    return DataRow(cells: [
      DataCell(Text(when, style: const TextStyle(fontSize: 13))),
      DataCell(Text(r.userRepr.isEmpty ? '—' : r.userRepr,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      DataCell(ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text('${r.modelName}: ${r.objectRepr}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13)))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: actionColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10)),
        child: Text(r.actionDisplay,
            style: TextStyle(color: actionColor,
                fontSize: 11, fontWeight: FontWeight.w600)),
      )),
      DataCell(ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _buildChanges(r),
      )),
    ]);
  }

  Widget _buildChanges(AuditLog r) {
    if (r.action == 'create') {
      return const Text('— объект создан',
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    if (r.action == 'delete') {
      return const Text('— объект удалён',
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    if (r.changes.isEmpty) {
      return const Text('—',
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: r.changes.entries.map((e) {
        final v = e.value;
        String from = '—', to = '—';
        if (v is Map) {
          from = (v['from'] ?? '—').toString();
          to = (v['to'] ?? '—').toString();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black),
              children: [
                TextSpan(text: '${_humanField(e.key)}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: from,
                    style: const TextStyle(color: Colors.red)),
                const TextSpan(text: '  →  '),
                TextSpan(text: to,
                    style: const TextStyle(color: Colors.green,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
}
