import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/token_storage.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8081/api/v1');
const developmentOtp = bool.fromEnvironment('DEVELOPMENT_OTP');
const firebaseAuthEnabled = bool.fromEnvironment('FIREBASE_AUTH_ENABLED');
const stripeTestCheckout = bool.fromEnvironment('STRIPE_TEST_CHECKOUT');
const stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

String apiError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) return 'Session or code is invalid or expired.';
    if (status == 403) return 'You do not have permission for this action.';
    if (status == 409) return 'This request conflicts with existing data.';
    if (status == 429) return 'Please wait before trying again.';
    if (status != null) return 'Server error ($status). Please try again.';
    return 'Cannot reach the server. Check your connection and API URL.';
  }
  return 'Something went wrong. Please try again.';
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(TokenStorage()));

class ApiClient {
  ApiClient(this._tokens) {
    dio = Dio(BaseOptions(baseUrl: apiBaseUrl, connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      try {
        final token = firebaseAuthEnabled
            ? await FirebaseAuth.instance.currentUser?.getIdToken()
            : (kDebugMode && developmentOtp ? await _tokens.readAccessToken() : null);
        if (token != null && token.isNotEmpty) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      } catch (error) {
        handler.reject(DioException(requestOptions: options, error: error, message: 'Unable to obtain authentication token.'));
      }
    }));
  }
  final TokenStorage _tokens;
  late final Dio dio;
}
