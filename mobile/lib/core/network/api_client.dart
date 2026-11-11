import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  ApiException(this.code, this.message, {this.statusCode});

  @override
  String toString() => message;
}

class SocketService {
  io.Socket? _socket;
  io.Socket? get socket => _socket;

  void connect(String? token) {
    _socket?.dispose();
    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth(token != null ? {'token': token} : {})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
  }

  void joinUser(String userId) => _socket?.emit('join:user', userId);
  void joinRider(String riderId) => _socket?.emit('join:rider', riderId);
  void joinMerchant(String merchantId) => _socket?.emit('join:merchant', merchantId);

  void joinTracking(String serviceType, String orderId) {
    _socket?.emit('join:tracking', {'serviceType': serviceType, 'orderId': orderId});
  }

  void joinChat(String threadId) => _socket?.emit('join:chat', threadId);

  void streamRiderLocation({
    required String riderId,
    required double lat,
    required double lng,
    String? activeParcelId,
    String? activeRideId,
    String? activeFoodOrderId,
  }) {
    _socket?.emit('rider:location:update', {
      'riderId': riderId,
      'lat': lat,
      'lng': lng,
      'services': ['food', 'parcel', 'ride'],
      'activeParcelId': ?activeParcelId,
      'activeRideId': ?activeRideId,
      'activeFoodOrderId': ?activeFoodOrderId,
    });
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}

class AuthSessionState {
  final bool initialized;
  final bool onboardingSeen;
  final String? accessToken;
  final String? riderRoleToken;
  final String? merchantRoleToken;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? roles;
  final DateTime lastActivityAt;
  final bool lockModalNeeded;

  const AuthSessionState({
    this.initialized = false,
    this.onboardingSeen = false,
    this.accessToken,
    this.riderRoleToken,
    this.merchantRoleToken,
    this.user,
    this.roles,
    required this.lastActivityAt,
    this.lockModalNeeded = false,
  });

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  String get activeRole => (user?['activeRole'] as String?) ?? 'CLIENT';

  AuthSessionState copyWith({
    bool? initialized,
    bool? onboardingSeen,
    String? accessToken,
    String? riderRoleToken,
    String? merchantRoleToken,
    Map<String, dynamic>? user,
    Map<String, dynamic>? roles,
    DateTime? lastActivityAt,
    bool? lockModalNeeded,
    bool clearTokens = false,
    bool clearRoleTokens = false,
  }) {
    return AuthSessionState(
      initialized: initialized ?? this.initialized,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      accessToken: clearTokens ? null : (accessToken ?? this.accessToken),
      riderRoleToken: clearTokens || clearRoleTokens ? null : (riderRoleToken ?? this.riderRoleToken),
      merchantRoleToken: clearTokens || clearRoleTokens ? null : (merchantRoleToken ?? this.merchantRoleToken),
      user: clearTokens ? null : (user ?? this.user),
      roles: clearTokens ? null : (roles ?? this.roles),
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      lockModalNeeded: lockModalNeeded ?? this.lockModalNeeded,
    );
  }
}

class ApiClient {
  final Dio dio;
  final Ref ref;

  ApiClient(this.ref)
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 12),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  Options _opts({String? roleToken}) {
    dio.options.baseUrl = AppConfig.apiBaseUrl;
    final s = ref.read(authControllerProvider);
    final headers = <String, dynamic>{};
    if (s.accessToken != null) headers['Authorization'] = 'Bearer ${s.accessToken}';
    if (roleToken != null) headers['x-role-token'] = roleToken;
    return Options(headers: headers);
  }

  Future<Map<String, dynamic>> get(String path, {String? roleToken, Map<String, dynamic>? query}) async {
    ref.read(authControllerProvider.notifier).touch();
    try {
      final res = await dio.get(path, queryParameters: query, options: _opts(roleToken: roleToken));
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> post(String path, {dynamic body, String? roleToken}) async {
    ref.read(authControllerProvider.notifier).touch();
    try {
      final res = await dio.post(path, data: body ?? {}, options: _opts(roleToken: roleToken));
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> patch(String path, {dynamic body, String? roleToken}) async {
    ref.read(authControllerProvider.notifier).touch();
    try {
      final res = await dio.patch(path, data: body ?? {}, options: _opts(roleToken: roleToken));
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> delete(String path, {String? roleToken}) async {
    ref.read(authControllerProvider.notifier).touch();
    try {
      final res = await dio.delete(path, options: _opts(roleToken: roleToken));
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = (data['code'] as String?) ?? 'API_ERROR';
      final msg = (data['message'] as String?) ?? 'Request failed';
      if (code == 'ROLE_INACTIVITY_LOCKED' || code == 'ROLE_LOCKED') {
        ref.read(authControllerProvider.notifier).markRoleLocked();
      }
      return ApiException(code, msg, statusCode: e.response?.statusCode);
    }
    return ApiException('NETWORK_ERROR', e.message ?? 'Cannot reach 2Bee backend server');
  }
}

class AuthController extends StateNotifier<AuthSessionState> {
  final Ref ref;
  Timer? _idleTimer;

  AuthController(this.ref) : super(AuthSessionState(lastActivityAt: DateTime.now())) {
    _idleTimer = Timer.periodic(const Duration(seconds: 30), (_) => checkInactivity());
  }

  Future<void> init() async {
    await AppConfig.loadSavedHost();
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('twobee_onboarding_seen') ?? false;
    final token = prefs.getString('twobee_access_token');
    state = state.copyWith(initialized: true, onboardingSeen: seen, accessToken: token);

    if (token != null && token.isNotEmpty) {
      ref.read(socketServiceProvider).connect(token);
      try {
        await refreshRoles();
      } catch (_) {
        // Keep session recoverable or allow relogin
      }
    }
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('twobee_onboarding_seen', true);
    state = state.copyWith(onboardingSeen: true);
  }

  Future<void> applyOtpLogin(Map<String, dynamic> data) async {
    final token = data['accessToken'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('twobee_access_token', token);
    state = state.copyWith(
      accessToken: token,
      user: Map<String, dynamic>.from(data['user'] as Map),
      roles: Map<String, dynamic>.from(data['roles'] as Map),
      lastActivityAt: DateTime.now(),
      lockModalNeeded: false,
    );
    final sock = ref.read(socketServiceProvider);
    sock.connect(token);
    sock.joinUser(data['user']['id'] as String);
  }

  Future<void> refreshRoles() async {
    if (!state.isLoggedIn) return;
    final res = await ref.read(apiClientProvider).get('/auth/me/roles');
    state = state.copyWith(
      user: Map<String, dynamic>.from(res['user'] as Map),
      roles: Map<String, dynamic>.from(res['roles'] as Map),
    );
  }

  Future<void> switchRole(String role) async {
    final res = await ref.read(apiClientProvider).post('/auth/switch-role', body: {'role': role});
    state = state.copyWith(
      user: Map<String, dynamic>.from(res['user'] as Map),
      roles: Map<String, dynamic>.from(res['roles'] as Map),
    );
  }

  void setRiderToken(String token) {
    state = state.copyWith(riderRoleToken: token, lastActivityAt: DateTime.now(), lockModalNeeded: false);
    final rId = state.roles?['rider']?['profileId'] as String?;
    if (rId != null) ref.read(socketServiceProvider).joinRider(rId);
  }

  void setMerchantToken(String token) {
    state = state.copyWith(merchantRoleToken: token, lastActivityAt: DateTime.now(), lockModalNeeded: false);
    final mId = state.roles?['merchant']?['profileId'] as String?;
    if (mId != null) ref.read(socketServiceProvider).joinMerchant(mId);
  }

  void touch() {
    state = state.copyWith(lastActivityAt: DateTime.now());
  }

  void markRoleLocked() {
    state = state.copyWith(clearRoleTokens: true, lockModalNeeded: true);
  }

  void checkInactivity() {
    final active = state.activeRole;
    if ((active == 'RIDER' || active == 'MERCHANT') &&
        (state.riderRoleToken != null || state.merchantRoleToken != null)) {
      if (DateTime.now().difference(state.lastActivityAt) > const Duration(minutes: 15)) {
        markRoleLocked();
      }
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('twobee_access_token');
    ref.read(socketServiceProvider).dispose();
    state = state.copyWith(clearTokens: true, initialized: true);
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }
}

final socketServiceProvider = Provider<SocketService>((ref) => SocketService());
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref));
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthSessionState>((ref) => AuthController(ref));

