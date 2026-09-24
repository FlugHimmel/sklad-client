import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/company_settings_repo.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Обычный блок
  final _ownershipCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerAddrCtrl = TextEditingController();
  final _supplierNameCtrl = TextEditingController();
  final _supplierAddrCtrl = TextEditingController();

  // Блок литейки
  final _fOwnershipCtrl = TextEditingController();
  final _fCustomerNameCtrl = TextEditingController();
  final _fCustomerAddrCtrl = TextEditingController();
  final _fSupplierNameCtrl = TextEditingController();
  final _fSupplierAddrCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _ownershipCtrl, _titleCtrl, _customerNameCtrl, _customerAddrCtrl,
      _supplierNameCtrl, _supplierAddrCtrl,
      _fOwnershipCtrl, _fCustomerNameCtrl, _fCustomerAddrCtrl,
      _fSupplierNameCtrl, _fSupplierAddrCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await CompanySettingsRepo(context.read<ApiClient>()).get();
      if (!mounted) return;
      setState(() {
        _ownershipCtrl.text = s.ownershipNote;
        _titleCtrl.text = s.packingListTitle;
        _customerNameCtrl.text = s.customerName;
        _customerAddrCtrl.text = s.customerAddress;
        _supplierNameCtrl.text = s.supplierName;
        _supplierAddrCtrl.text = s.supplierAddress;
        _fOwnershipCtrl.text = s.foundryOwnershipNote;
        _fCustomerNameCtrl.text = s.foundryCustomerName;
        _fCustomerAddrCtrl.text = s.foundryCustomerAddress;
        _fSupplierNameCtrl.text = s.foundrySupplierName;
        _fSupplierAddrCtrl.text = s.foundrySupplierAddress;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final data = CompanySettings(
        id: 1,
        ownershipNote: _ownershipCtrl.text.trim(),
        packingListTitle: _titleCtrl.text.trim(),
        customerName: _customerNameCtrl.text.trim(),
        customerAddress: _customerAddrCtrl.text.trim(),
        supplierName: _supplierNameCtrl.text.trim(),
        supplierAddress: _supplierAddrCtrl.text.trim(),
        foundryOwnershipNote: _fOwnershipCtrl.text.trim(),
        foundryCustomerName: _fCustomerNameCtrl.text.trim(),
        foundryCustomerAddress: _fCustomerAddrCtrl.text.trim(),
        foundrySupplierName: _fSupplierNameCtrl.text.trim(),
        foundrySupplierAddress: _fSupplierAddrCtrl.text.trim(),
      );
      await CompanySettingsRepo(context.read<ApiClient>()).update(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранено')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Реквизиты для печати')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _infoBox(
                        'Эти реквизиты попадают в шапку упаковочного листа.\n\n'
                        'Есть два блока:\n'
                        '• Обычный — для тебя (Модель → Ромашка)\n'
                        '• Литейки — для литейщиков (Завод → Модель)\n\n'
                        'При печати программа сама подставит нужный блок.',
                      ),
                      const SizedBox(height: 20),

                      _sectionTitle('ОСНОВНОЙ ДОКУМЕНТ',
                          color: Colors.blueGrey.shade700),
                      TextFormField(
                        controller: _ownershipCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Строка собственности',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Заголовок документа',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 24),
                      _sectionTitle('ЗАКАЗЧИК (основной блок)',
                          color: Colors.blue.shade700),
                      TextFormField(
                        controller: _customerNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Наименование',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customerAddrCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Адрес (можно несколько строк)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                      ),

                      const SizedBox(height: 24),
                      _sectionTitle('ПОСТАВЩИК (основной блок)',
                          color: Colors.blue.shade700),
                      TextFormField(
                        controller: _supplierNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Наименование',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _supplierAddrCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Адрес',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),

                      // ─── Блок для литейки ─────────────────────────
                      const SizedBox(height: 32),
                      _sectionTitle('ДЛЯ ЛИТЕЙКИ — строка собственности',
                          color: Colors.orange.shade800),
                      TextFormField(
                        controller: _fOwnershipCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Строка собственности (литейка)',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),
                      _sectionTitle('ДЛЯ ЛИТЕЙКИ — заказчик',
                          color: Colors.orange.shade800),
                      TextFormField(
                        controller: _fCustomerNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Заказчик (кому везёт литейка)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fCustomerAddrCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Адрес заказчика',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),

                      const SizedBox(height: 16),
                      _sectionTitle('ДЛЯ ЛИТЕЙКИ — поставщик',
                          color: Colors.orange.shade800),
                      TextFormField(
                        controller: _fSupplierNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Поставщик (от кого литейка)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fSupplierAddrCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Адрес поставщика',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),

                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Сохранить'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _infoBox(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      );

  Widget _sectionTitle(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
      );
}
