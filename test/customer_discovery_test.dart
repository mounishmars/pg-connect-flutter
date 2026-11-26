import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_connect/core/api/api_client.dart';
import 'package:pg_connect/core/api/data_providers.dart';
import 'package:pg_connect/core/auth/token_storage.dart';
import 'package:pg_connect/features/customer/customer_home_screen.dart';

void main() {
  testWidgets('loads property details and submits a booking request', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'pg_connect_access_token': 'token'});
    final api = ApiClient(TokenStorage());
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      if (request.path == '/properties/property-1') {
        handler.resolve(Response(requestOptions: request, statusCode: 200, data: {
          'name': 'Test PG', 'address': 'Test Road', 'area': 'OMR', 'city': 'Chennai',
          'description': 'A room', 'rooms': [{'id': 'room-1', 'name': '101'}],
          'availableBeds': [{'id': 'bed-1', 'roomId': 'room-1', 'label': 'A'}],
        }));
      } else if (request.path == '/customer/bookings') {
        expect(request.headers['Authorization'], 'Bearer token');
        expect(request.data, {'bedId': 'bed-1'});
        handler.resolve(Response(requestOptions: request, statusCode: 200, data: {'id': 'booking-1', 'status': 'PENDING'}));
      } else {
        handler.reject(DioException(requestOptions: request));
      }
    }));
    await tester.pumpWidget(ProviderScope(overrides: [
      apiClientProvider.overrideWithValue(api),
      propertiesProvider.overrideWith((ref) async => [
        {'id': 'property-1', 'name': 'Test PG', 'area': 'OMR', 'city': 'Chennai',
          'startingRent': 8000, 'availableBeds': 1},
      ]),
    ], child: const MaterialApp(home: CustomerHomeScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test PG'));
    await tester.pumpAndSettle();
    expect(find.text('Room 101 · Bed A'), findsOneWidget);
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.text('Booking requested; awaiting owner approval.'), findsOneWidget);
  });
}
