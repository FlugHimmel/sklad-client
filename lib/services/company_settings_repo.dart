import 'api_client.dart';

class CompanySettings {
  final int id;

  // Обычный блок (для админа/менеджера)
  final String ownershipNote;
  final String packingListTitle;
  final String customerName;
  final String customerAddress;
  final String supplierName;
  final String supplierAddress;

  // Блок литейки
  final String foundryOwnershipNote;
  final String foundryCustomerName;
  final String foundryCustomerAddress;
  final String foundrySupplierName;
  final String foundrySupplierAddress;

  CompanySettings({
    required this.id,
    required this.ownershipNote,
    required this.packingListTitle,
    required this.customerName,
    required this.customerAddress,
    required this.supplierName,
    required this.supplierAddress,
    this.foundryOwnershipNote = '',
    this.foundryCustomerName = '',
    this.foundryCustomerAddress = '',
    this.foundrySupplierName = '',
    this.foundrySupplierAddress = '',
  });

  factory CompanySettings.fromJson(Map<String, dynamic> j) {
    return CompanySettings(
      id: j['id'] as int,
      ownershipNote: (j['ownership_note'] ?? '').toString(),
      packingListTitle: (j['packing_list_title'] ?? '').toString(),
      customerName: (j['customer_name'] ?? '').toString(),
      customerAddress: (j['customer_address'] ?? '').toString(),
      supplierName: (j['supplier_name'] ?? '').toString(),
      supplierAddress: (j['supplier_address'] ?? '').toString(),
      foundryOwnershipNote: (j['foundry_ownership_note'] ?? '').toString(),
      foundryCustomerName: (j['foundry_customer_name'] ?? '').toString(),
      foundryCustomerAddress: (j['foundry_customer_address'] ?? '').toString(),
      foundrySupplierName: (j['foundry_supplier_name'] ?? '').toString(),
      foundrySupplierAddress: (j['foundry_supplier_address'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'ownership_note': ownershipNote,
        'packing_list_title': packingListTitle,
        'customer_name': customerName,
        'customer_address': customerAddress,
        'supplier_name': supplierName,
        'supplier_address': supplierAddress,
        'foundry_ownership_note': foundryOwnershipNote,
        'foundry_customer_name': foundryCustomerName,
        'foundry_customer_address': foundryCustomerAddress,
        'foundry_supplier_name': foundrySupplierName,
        'foundry_supplier_address': foundrySupplierAddress,
      };
}

class CompanySettingsRepo {
  final ApiClient _api;
  CompanySettingsRepo(this._api);

  Future<CompanySettings> get() async {
    final resp = await _api.get('/api/company-settings/1/');
    return CompanySettings.fromJson(resp as Map<String, dynamic>);
  }

  Future<CompanySettings> update(CompanySettings data) async {
    final resp = await _api.put('/api/company-settings/1/', body: data.toJson());
    return CompanySettings.fromJson(resp as Map<String, dynamic>);
  }
}
