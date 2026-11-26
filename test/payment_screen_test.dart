import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_connect/core/api/api_client.dart';
import 'package:pg_connect/core/auth/token_storage.dart';
import 'package:pg_connect/features/payments/rent_payment_screen.dart';

void main() {
  testWidgets('resumes an open order, checks server status and can cancel', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'pg_connect_access_token': 'token'});
    final api=ApiClient(TokenStorage());
    bool cancelled=false;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.headers['Authorization'], 'Bearer token');
      if (request.path == '/customer/rent/payments/active') {
        expect(request.queryParameters['invoiceId'], 'invoice-id');
        handler.resolve(Response(requestOptions: request,statusCode: 200,data: {
          'paymentOrderId': 'order-id','amount': 1000,'status': 'ACTIVE','paymentSessionId': 'test-secret',
        }));
      } else if (request.path == '/customer/rent/payments/order-id/reconcile') {
        handler.resolve(Response(requestOptions: request,statusCode: 200,data: {'status': 'ACTIVE'}));
      } else if (request.path == '/customer/rent/payments/order-id/cancel') {
        cancelled=true;
        handler.resolve(Response<void>(requestOptions: request,statusCode: 200));
      } else {
        handler.reject(DioException(requestOptions: request));
      }
    }));
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: RentPaymentScreen(invoiceId: 'invoice-id',outstandingBalance: 2000))));
    await tester.pumpAndSettle();
    expect(find.text('Resume checkout'), findsOneWidget);
    await tester.tap(find.text('Check payment status'));
    await tester.pumpAndSettle();
    expect(find.text('Payment is not confirmed yet. Check status again later.'), findsOneWidget);
    await tester.tap(find.text('Cancel open payment'));
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
    expect(find.text('Payment cancelled.'), findsOneWidget);
    expect(find.text('Continue to Stripe'), findsOneWidget);
  }, skip: !stripeTestCheckout || !stripePublishableKey.startsWith('pk_test_'));
}
