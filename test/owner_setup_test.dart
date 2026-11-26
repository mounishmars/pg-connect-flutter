import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_connect/core/api/api_client.dart';
import 'package:pg_connect/core/auth/token_storage.dart';
import 'package:pg_connect/features/owner/owner_inventory_screen.dart';
import 'package:pg_connect/features/owner/owner_invoices.dart';

void main() {
  testWidgets('creates a property using the authenticated API', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'pg_connect_access_token': 'token'});
    final api = ApiClient(TokenStorage());
    Map<String, dynamic>? sent;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.path, '/owner/properties');
      expect(request.headers['Authorization'], 'Bearer token');
      sent = Map<String, dynamic>.from(request.data as Map);
      handler.resolve(Response(requestOptions: request, statusCode: 200, data: {'id': 'property-id'}));
    }));
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute<bool>(builder: (_) => const PropertyForm())),
        child: const Text('Open form')))))));
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save property'));
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required.'), findsWidgets);
    await tester.enterText(find.widgetWithText(TextFormField, 'Property name'), 'Test PG');
    await tester.enterText(find.widgetWithText(TextFormField, 'Address'), 'Main Road');
    await tester.enterText(find.widgetWithText(TextFormField, 'Area'), 'OMR');
    await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Chennai');
    await tester.ensureVisible(find.text('Save property'));
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();
    expect(sent, {'name': 'Test PG', 'description': '', 'address': 'Main Road',
      'area': 'OMR', 'city': 'Chennai', 'active': true});
  });

  testWidgets('creates an invoice with a selected due date', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'pg_connect_access_token': 'token'});
    final api = ApiClient(TokenStorage());
    Map<String, dynamic>? sent;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.path, '/owner/invoices');
      sent = Map<String, dynamic>.from(request.data as Map);
      handler.resolve(Response(requestOptions: request, statusCode: 200, data: {'id': 'invoice-id'}));
    }));
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute<bool>(builder: (_) => const CreateInvoice(
          booking: {'id': 'booking-id', 'tenantName': 'Tenant', 'propertyName': 'Test PG'}))),
        child: const Text('Open invoice')))))));
    await tester.tap(find.text('Open invoice'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount (INR)'), '8000.50');
    await tester.tap(find.text('Create invoice'));
    await tester.pump();
    expect(find.text('Select a due date.'), findsOneWidget);
    await tester.tap(find.text('Select due date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create invoice'));
    await tester.pumpAndSettle();
    expect(sent?['bookingId'], 'booking-id');
    expect(sent?['amount'], '8000.50');
    expect(sent?['dueDate'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  testWidgets('adds a room and bed to a property', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'pg_connect_access_token': 'token'});
    final api = ApiClient(TokenStorage());
    bool hasRoom = false;
    bool hasBed = false;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      if (request.method == 'GET' && request.path == '/owner/properties/property-id/rooms') {
        handler.resolve(Response(requestOptions: request, statusCode: 200, data: hasRoom ? [{
          'id': 'room-id', 'name': '101', 'monthlyRent': 8000, 'active': true,
          'bedId': hasBed ? 'bed-id' : null, 'bedLabel': hasBed ? 'A' : null,
          'bedActive': hasBed ? true : null,
        }] : []));
      } else if (request.path == '/owner/properties/property-id/rooms') {
        expect(request.data, {'name': '101', 'monthlyRent': '8000'});
        hasRoom = true;
        handler.resolve(Response(requestOptions: request, statusCode: 200, data: {'id': 'room-id'}));
      } else if (request.path == '/owner/rooms/room-id/beds') {
        expect(request.data, {'label': 'A'});
        hasBed = true;
        handler.resolve(Response(requestOptions: request, statusCode: 200, data: {'id': 'bed-id'}));
      } else {
        handler.reject(DioException(requestOptions: request));
      }
    }));
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: InventoryScreen(property: {'id': 'property-id', 'name': 'Test PG'}))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add room'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Room name'), '101');
    await tester.enterText(find.widgetWithText(TextFormField, 'Monthly rent (INR)'), '8000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Room 101'), findsOneWidget);
    await tester.tap(find.text('Add bed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Bed label'), 'A');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Bed A'), findsOneWidget);
  });
}
