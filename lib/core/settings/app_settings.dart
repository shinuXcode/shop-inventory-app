import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  String get businessName => _prefs.getString('businessName') ?? 'SBILL Shop';
  String get businessPhone => _prefs.getString('businessPhone') ?? '';
  String get businessEmail => _prefs.getString('businessEmail') ?? '';
  String get businessAddress => _prefs.getString('businessAddress') ?? '';
  String get gstNumber => _prefs.getString('gstNumber') ?? '';
  String get invoicePrefix => _prefs.getString('invoicePrefix') ?? 'INV';
  String get invoiceFooter => _prefs.getString('invoiceFooter') ?? 'Thank you for your business.';
  String get currency => _prefs.getString('currency') ?? 'INR';
  bool get thermalReceipt => _prefs.getBool('thermalReceipt') ?? false;
  bool get darkMode => _prefs.getBool('darkMode') ?? false;
  String? get businessId => _prefs.getString('businessId');
  String? get accountUserId => _prefs.getString('accountUserId');
  bool get cloudConfigured => businessId != null && businessId!.isNotEmpty;
  bool get accountBound => accountUserId != null && accountUserId!.isNotEmpty;

  Future<void> save({
    required String businessName,
    required String businessPhone,
    required String businessEmail,
    required String businessAddress,
    required String gstNumber,
    required String invoicePrefix,
    required bool thermalReceipt,
    required bool darkMode,
    String currency = 'INR',
    String invoiceFooter = 'Thank you for your business.',
    String? businessId,
    String? accountUserId,
  }) async {
    await _prefs.setString('businessName', businessName);
    await _prefs.setString('businessPhone', businessPhone);
    await _prefs.setString('businessEmail', businessEmail);
    await _prefs.setString('businessAddress', businessAddress);
    await _prefs.setString('gstNumber', gstNumber);
    await _prefs.setString('invoicePrefix', invoicePrefix);
    await _prefs.setString('currency', currency.trim().isEmpty ? 'INR' : currency.trim().toUpperCase());
    await _prefs.setBool('thermalReceipt', thermalReceipt);
    await _prefs.setBool('darkMode', darkMode);
    await _prefs.setString('invoiceFooter', invoiceFooter.trim().isEmpty ? 'Thank you for your business.' : invoiceFooter.trim());
    if (businessId != null && businessId.isNotEmpty) {
      await _prefs.setString('businessId', businessId);
    }
    if (accountUserId != null && accountUserId.isNotEmpty) {
      await _prefs.setString('accountUserId', accountUserId);
    }
  }

  Future<void> clearCloudBinding() async {
    // Preserve accountUserId so the app can distinguish the same user from a new user after sign-out.
    await _prefs.remove('businessId');
  }
}
