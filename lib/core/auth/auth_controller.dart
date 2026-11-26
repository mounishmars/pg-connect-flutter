import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'token_storage.dart';

enum UserRole { customer, owner }

class AuthState {
  const AuthState({this.loading = false, this.isAuthenticated = false,
    this.role = UserRole.customer, this.displayName = '', this.ownerId,
    this.ownerApplicationStatus, this.error});
  final bool loading;
  final bool isAuthenticated;
  final UserRole role;
  final String displayName;
  final String? ownerId;
  final String? ownerApplicationStatus;
  final String? error;
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(TokenStorage(), ref.read(apiClientProvider));
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._storage, this._api) : super(const AuthState(loading: true)) {
    restore();
  }
  final TokenStorage _storage;
  final ApiClient _api;

  Future<void> restore() async {
    try {
      final token = await _storage.readAccessToken();
      if (token == null || token.isEmpty) {
        state = const AuthState();
        return;
      }
      await refreshProfile();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _storage.clear();
        state = const AuthState(error: 'Session expired. Please sign in again.');
      } else {
        state = const AuthState(error: 'Unable to restore session. Check your connection and retry.');
      }
    } catch (error) {
      state = const AuthState(error: 'Unable to read the saved session.');
    }
  }

  Future<String> requestOtp(String phone) async {
    final response = await _api.dio.post<Map<String, dynamic>>('/auth/dev/otp', data: {'phone': phone});
    final code = response.data?['code'];
    if (code is! String || code.isEmpty) throw const FormatException('The server did not return a development code.');
    return code;
  }

  Future<void> verifyOtp(String phone, String code, String fullName) async {
    final response = await _api.dio.post<Map<String, dynamic>>('/auth/dev/verify',
      data: {'phone': phone, 'code': code, 'fullName': fullName});
    final token = response.data?['accessToken'];
    if (token is! String || token.isEmpty) throw const FormatException('The server did not return a session token.');
    await _storage.saveAccessToken(token);
    try {
      await refreshProfile();
    } catch (_) {
      await _storage.clear();
      rethrow;
    }
  }

  Future<void> refreshProfile() async {
    final response = await _api.dio.get<Map<String, dynamic>>('/me');
    final profile = response.data;
    if (profile == null || profile['fullName'] is! String) throw const FormatException('Invalid profile response.');
    final ownerId = profile['ownerId'] as String?;
    state = AuthState(isAuthenticated: true, displayName: profile['fullName'] as String,
      ownerId: ownerId, ownerApplicationStatus: profile['ownerApplicationStatus'] as String?,
      role: ownerId == null ? UserRole.customer : UserRole.owner);
  }

  void switchRole(UserRole role) {
    if (role == UserRole.owner && state.ownerId == null) return;
    state = AuthState(isAuthenticated: true, role: role, displayName: state.displayName,
      ownerId: state.ownerId, ownerApplicationStatus: state.ownerApplicationStatus);
  }

  Future<void> signOut() async {
    await _api.dio.post<void>('/auth/logout');
    await _storage.clear();
    state = const AuthState();
  }
}
