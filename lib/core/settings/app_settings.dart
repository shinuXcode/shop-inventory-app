import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  String get businessName => _prefs.getString('businessName') ?? 'SBILL Shop';
  String get businessPhone => _prefs.getString('businessPhone') ?? '';
  String get businessAddress => _prefs.getString('businessAddress') ?? '';
  String get gstNumber => _prefs.getString('gstNumber') ?? '';
  String get invoicePrefix => _prefs.getString('invoicePrefix') ?? 'INV';
  String get currency => _prefs.getString('currency') ?? 'INR';
  bool get thermalReceipt => _prefs.getBool('thermalReceipt') ?? false;
  bool get darkMode => _prefs.getBool('darkMode') ?? false;

  Future<void> save({
    required String businessName,
    required String businessPhone,
    required String businessAddress,
    required String gstNumber,
    required String invoicePrefix,
    required bool thermalReceipt,
    required bool darkMode,
  }) async {
    await _prefs.setString('businessName', businessName);
    await _prefs.setString('businessPhone', businessPhone);
    await _prefs.setString('businessAddress', businessAddress);
    await _prefs.setString('gstNumber', gstNumber);
    await _prefs.setString('invoicePrefix', invoicePrefix);
    await _prefs.setBool('thermalReceipt', thermalReceipt);
    await _prefs.setBool('darkMode', darkMode);
  }
}
