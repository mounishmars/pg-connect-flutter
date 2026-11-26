import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_connect/core/api/api_client.dart';
import 'package:pg_connect/core/auth/auth_controller.dart';
import 'package:pg_connect/core/auth/token_storage.dart';

void main() {
  test('development login stores bearer token and obtains owner role from server', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = TokenStorage();
    final api = ApiClient(storage);
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      switch (request.path) {
        case '/auth/dev/otp':
          handler.resolve(Response(requestOptions: request, data: {'code': '123456'}, statusCode: 200));
        case '/auth/dev/verify':
          expect(request.data, {'phone': '+919876543210', 'code': '123456', 'fullName': 'User'});
          handler.resolve(Response(requestOptions: request, data: {'accessToken': 'test-token'}, statusCode: 200));
        case '/me':
          expect(request.headers['Authorization'], 'Bearer test-token');
          handler.resolve(Response(requestOptions: request, data: {'fullName': 'User', 'ownerId': 'owner-id'}, statusCode: 200));
        case '/auth/logout':
          handler.resolve(Response<void>(requestOptions: request, statusCode: 200));
        default:
          handler.reject(DioException(requestOptions: request));
      }
    }));
    final auth = AuthController(storage, api);
    await auth.restore();
    expect(await auth.requestOtp('+919876543210'), '123456');
    await auth.verifyOtp('+919876543210', '123456', 'User');
    expect(auth.state.isAuthenticated, isTrue);
    expect(auth.state.role, UserRole.owner);
    expect(await storage.readAccessToken(), 'test-token');
    await auth.signOut();
    expect(await storage.readAccessToken(), isNull);
    expect(auth.state.isAuthenticated, isFalse);
    auth.dispose();
  });
}
