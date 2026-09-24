import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/users_repo.dart';
import 'user_form_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});
  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  List<AppUser> _items = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  bool _onlyActive = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await UsersRepo(context.read<ApiClient>())
          .list(onlyActive: _onlyActive);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppUser> get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items.where((u) =>
        u.username.toLowerCase().contains(q) ||
        u.firstName.toLowerCase().contains(q) ||
        u.lastName.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q)).toList();
  }

  Future<void> _openForm({AppUser? existing}) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => UserFormScreen(existing: existing)));
    if (saved == true) _load();
  }

  Future<void> _delete(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text('Удалить «${u.username}» (${u.displayName})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await UsersRepo(context.read<ApiClient>()).delete(u.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Удалено: ${u.username}')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Пользователи (${_items.length})'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Новый пользователь'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Поиск по логину, имени, email',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            FilterChip(
              label: const Text('Только активные'),
              selected: _onlyActive,
              onSelected: (v) { setState(() => _onlyActive = v); _load(); },
            ),
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
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Пользователей нет',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.person_add),
            label: const Text('Создать первого'),
          ),
        ],
      ));
    }
    final rows = _filtered;
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          horizontalMargin: 12,
          headingRowHeight: 42,
          dataRowMinHeight: 34,
          dataRowMaxHeight: 44,
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
          columns: const [
            DataColumn(label: _Th('Логин')),
            DataColumn(label: _Th('ФИО')),
            DataColumn(label: _Th('Email')),
            DataColumn(label: _Th('Телефон')),
            DataColumn(label: _Th('Роль')),
            DataColumn(label: _Th('Активен')),
            DataColumn(label: _Th('')),
          ],
          rows: rows.map((u) {
            return DataRow(
              color: u.isActive
                  ? null
                  : MaterialStateProperty.all(Colors.grey.shade100),
              cells: [
                DataCell(Text(u.username,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13))),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(u.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)))),
                DataCell(Text(u.email.isEmpty ? '—' : u.email,
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text(u.phone.isEmpty ? '—' : u.phone,
                    style: const TextStyle(fontSize: 13))),
                DataCell(_roleChip(u)),
                DataCell(u.isActive
                    ? _chip('Да', Colors.green)
                    : _chip('Нет', Colors.grey)),
                DataCell(Row(children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Редактировать',
                    onPressed: () => _openForm(existing: u),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20,
                        color: Colors.red),
                    tooltip: 'Удалить',
                    onPressed: () => _delete(u),
                  ),
                ])),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _roleChip(AppUser u) {
    final isAdmin = u.isAdmin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isAdmin ? Colors.deepPurple : Colors.blueGrey)
            .withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(u.roleDisplay,
          style: TextStyle(
              color: isAdmin ? Colors.deepPurple : Colors.blueGrey,
              fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color,
        fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
}
