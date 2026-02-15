import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService._();

  // Settings keys
  static const _keyDeadWeight = 'dead_weight';
  static const _keyFullWeight = 'full_weight';
  static const _keyWarningPercent = 'warning_percent';

  // Runtime state keys
  static const _keyLastWeight = 'last_weight';
  static const _keyLastReceivedMs = 'last_received_ms';
  static const _keyLastConnectedMs = 'last_connected_ms';

  // ── Settings ──────────────────────────────────────────────────────────────

  static Future<Map<String, double>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'deadWeight': prefs.getDouble(_keyDeadWeight) ?? 0.0,
      'fullWeight': prefs.getDouble(_keyFullWeight) ?? 0.0,
      'warningPercent': prefs.getDouble(_keyWarningPercent) ?? 20.0,
    };
  }

  static Future<void> saveDeadWeight(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyDeadWeight, value);
  }

  static Future<void> saveFullWeight(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFullWeight, value);
  }

  static Future<void> saveWarningPercent(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyWarningPercent, value);
  }

  // ── Last known state ──────────────────────────────────────────────────────

  static Future<void> saveLastWeight(double kg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLastWeight, kg);
  }

  static Future<double?> getLastWeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyLastWeight);
  }

  static Future<void> saveLastReceivedTime(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastReceivedMs, dt.millisecondsSinceEpoch);
  }

  static Future<DateTime?> getLastReceivedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyLastReceivedMs);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  static Future<void> saveLastConnectedTime(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastConnectedMs, dt.millisecondsSinceEpoch);
  }

  static Future<DateTime?> getLastConnectedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyLastConnectedMs);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }
}