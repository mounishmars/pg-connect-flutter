import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pg_connect/core/api/api_client.dart';
import 'package:pg_connect/core/api/data_providers.dart';
import 'package:pg_connect/core/auth/token_storage.dart';
import 'package:pg_connect/features/owner/owner_inventory_screen.dart';
import 'package:pg_connect/features/owner/owner_invoices.dart';
import 'package:pg_connect/features/owner/property_photos_screen.dart';
import 'package:pg_connect/features/owner/property_amenities_screen.dart';

class TestPhotoPicker extends ImagePicker {
  TestPhotoPicker(this.bytes);
  final Uint8List bytes;
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth, double? maxHeight, int? imageQuality, int? limit, bool requestFullMetadata = true,
  }) async => [XFile.fromData(bytes, name: 'test.png', mimeType: 'image/png')];
}

void main() {
  testWidgets('saves selected catalog amenities for the owner property', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'pg_connect_access_token': 'token'});
    final api = ApiClient(TokenStorage());
    List<dynamic>? saved;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.headers['Authorization'], 'Bearer token');
      if (request.path == '/amenities') {
        handler.resolve(Response(requestOptions: request, statusCode: 200, data: [
          {'code': 'wifi', 'name': 'Wi-Fi'}, {'code': 'parking', 'name': 'Parking'},
        ]));
      } else if (request.path == '/owner/properties/property-id/amenities' && request.method == 'GET') {
        handler.resolve(Response(requestOptions: request, statusCode: 200, data: ['wifi']));
      } else if (request.path == '/owner/properties/property-id/amenities' && request.method == 'PUT') {
        saved = request.data['codes'] as List<dynamic>;
        handler.resolve(Response(requestOptions: request, statusCode: 200));
      } else {
        handler.reject(DioException(requestOptions: request));
      }
    }));
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: PropertyAmenitiesScreen(propertyId: 'property-id'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wi-Fi'));
    await tester.tap(find.text('Parking'));
    await tester.tap(find.text('Save amenities'));
    await tester.pumpAndSettle();
    expect(saved, ['parking']);
  });

  testWidgets('uploads a selected property photo using the owner session', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'pg_connect_access_token': 'token'});
    final api = ApiClient(TokenStorage());
    bool uploaded = false;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.path, '/owner/properties/property-id/photos');
      expect(request.headers['Authorization'], 'Bearer token');
      expect((request.data as FormData).files.single.key, 'file');
      uploaded = true;
      handler.resolve(Response(requestOptions: request, statusCode: 200, data: {'id': 'photo'}));
    }));
    final png = Uint8List.fromList(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg=='));
    await tester.pumpWidget(ProviderScope(overrides: [
      apiClientProvider.overrideWithValue(api),
      photoPickerProvider.overrideWithValue(TestPhotoPicker(png)),
      ownerPhotosProvider.overrideWith((ref, propertyId) async => []),
    ], child: const MaterialApp(home: PropertyPhotosScreen(propertyId: 'property-id'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add photos'));
    await tester.pumpAndSettle();
    expect(uploaded, isTrue);
    expect(find.text('1 photo uploaded.'), findsOneWidget);
  });

  testWidgets('sets the cover and reorders property photos', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'pg_connect_access_token': 'token'});
    final api = ApiClient(TokenStorage());
    var ids = ['one', 'two'];
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.headers['Authorization'], 'Bearer token');
      if (request.path.endsWith('/two/cover')) {
        ids = ['two', 'one'];
      } else if (request.path.endsWith('/order')) {
        ids = List<String>.from(request.data['photoIds'] as List);
      } else {
        handler.reject(DioException(requestOptions: request));
        return;
      }
      handler.resolve(Response(requestOptions: request, statusCode: 200));
    }));
    final png = Uint8List.fromList(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg=='));
    await tester.pumpWidget(ProviderScope(overrides: [
      apiClientProvider.overrideWithValue(api),
      ownerPhotosProvider.overrideWith((ref, propertyId) async => [
        for (var i = 0; i < ids.length; i++) {'id': ids[i], 'position': i, 'cover': i == 0},
      ]),
      photoBytesProvider.overrideWith((ref, path) async => png),
    ], child: const MaterialApp(home: PropertyPhotosScreen(propertyId: 'property-id'))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Set cover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set cover'));
    await tester.pumpAndSettle();
    expect(ids, ['two', 'one']);
    await tester.ensureVisible(find.byTooltip('Move photo up').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move photo up').last);
    await tester.pumpAndSettle();
    expect(ids, ['one', 'two']);
  });

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
