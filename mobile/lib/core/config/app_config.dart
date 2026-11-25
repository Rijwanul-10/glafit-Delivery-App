import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static String? _runtimeHostOverride;

  static Future<void> loadSavedHost() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('twobee_server_origin');
    if (saved != null && saved.trim().isNotEmpty) {
      _runtimeHostOverride = saved.trim().replaceAll(RegExp(r'/+$'), '');
    }
  }

  static Future<void> setServerOrigin(String? origin) async {
    final prefs = await SharedPreferences.getInstance();
    if (origin == null || origin.trim().isEmpty) {
      _runtimeHostOverride = null;
      await prefs.remove('twobee_server_origin');
      return;
    }
    final clean = origin.trim().replaceAll(RegExp(r'/+$'), '');
    _runtimeHostOverride = clean;
    await prefs.setString('twobee_server_origin', clean);
  }

  static const String defaultProdServerOrigin =
      'https://twobee-api-1o6z.onrender.com';

  static String get serverOrigin {
    if (_runtimeHostOverride != null && _runtimeHostOverride!.isNotEmpty) {
      return _runtimeHostOverride!;
    }
    const defined = String.fromEnvironment('SOCKET_URL');
    if (defined.isNotEmpty) return defined;
    return defaultProdServerOrigin;
  }

  static String get apiBaseUrl {
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty && _runtimeHostOverride == null) return defined;
    return '$serverOrigin/api/v1';
  }

  static String get socketUrl => serverOrigin;

  static const String mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const bool mfsPreviewOnly = true;
}
