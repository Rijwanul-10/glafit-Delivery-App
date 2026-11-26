import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

/// Handles safe Firebase initialization and FCM token sync with `/api/v1/common/fcm-token`.
/// Gracefully no-ops when `google-services.json` / `GoogleService-Info.plist` / Web options
/// are not yet bundled, so local/web builds and widget tests never crash.
class FirebasePushService {
  static bool _initialized = false;

  static Future<void> initSafely() async {
    if (_initialized) return;
    // On Web, Firebase.initializeApp() requires explicit FirebaseOptions; skip unless configured.
    if (kIsWeb) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _initialized = true;
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Safe no-op when native Firebase config files aren't added yet
    }
  }

  static Future<void> syncTokenWithBackend(Ref ref, {String role = 'CLIENT'}) async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.length < 10) return;
      final platform = kIsWeb
          ? 'WEB'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'IOS'
              : 'ANDROID';
      await ref.read(apiClientProvider).post(
        '/common/fcm-token',
        body: {
          'token': token,
          'role': role.toUpperCase(),
          'platform': platform,
        },
      );
    } catch (_) {
      // Non-fatal push sync error
    }
  }
}
