import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_connect/core/api/api_client.dart';
import 'package:pg_connect/core/api/data_providers.dart';
import 'package:pg_connect/core/auth/token_storage.dart';
import 'package:pg_connect/core/theme/app_theme.dart';
import 'package:pg_connect/features/customer/customer_home_screen.dart';

void main() {
  testWidgets('sends location, rent, availability and amenity filters to the server', (tester) async {
    String? requestedPath;
    await tester.pumpWidget(ProviderScope(overrides: [
      propertiesProvider.overrideWith((ref) async => []),
      amenitiesProvider.overrideWith((ref) async => [
        {'code': 'wifi', 'name': 'Wi-Fi'}, {'code': 'parking', 'name': 'Parking'},
      ]),
      searchPropertiesProvider.overrideWith((ref, path) async {
        requestedPath = path;
        return [];
      }),
    ], child: const MaterialApp(home: CustomerHomeScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search area, city or property'), 'Chennai');
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Maximum monthly rent (INR)'), '6000');
    await tester.tap(find.text('Available beds only'));
    await tester.scrollUntilVisible(find.text('Wi-Fi'), 150, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Wi-Fi'));
    await tester.scrollUntilVisible(find.text('Parking'), 150, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Parking'));
    await tester.scrollUntilVisible(find.text('Search'), 150, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    final params = Uri.parse(requestedPath!).queryParameters;
    expect(params['query'], 'Chennai');
    expect(params['maxRent'], '6000');
    expect(params['availableOnly'], 'true');
    expect(Uri.parse(requestedPath!).queryParametersAll['amenity'], containsAll(['wifi', 'parking']));
  });

  testWidgets('loads another page using the active search filters', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = ApiClient(TokenStorage());
    Uri? pageUri;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      pageUri = request.uri;
      handler.resolve(Response(requestOptions: request, statusCode: 200, data: [
        {'id': 'last', 'name': 'Last PG', 'area': 'OMR', 'city': 'Chennai', 'availableBeds': 1},
      ]));
    }));
    await tester.pumpWidget(ProviderScope(overrides: [
      apiClientProvider.overrideWithValue(api),
      amenitiesProvider.overrideWith((ref) async => []),
      propertiesProvider.overrideWith((ref) async => []),
      searchPropertiesProvider.overrideWith((ref, path) async => [
        for (var i = 0; i < 50; i++)
          {'id': '$i', 'name': 'PG $i', 'area': 'OMR', 'city': 'Chennai', 'availableBeds': 1},
      ]),
    ], child: const MaterialApp(home: CustomerHomeScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Chennai');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Load more'), 500,
      scrollable: find.byType(Scrollable).first, maxScrolls: 100);
    await tester.ensureVisible(find.text('Load more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(pageUri!.queryParameters['query'], 'Chennai');
    expect(pageUri!.queryParameters['offset'], '50');
    expect(find.text('Last PG'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('saves and removes a property for the current user', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'pg_connect_access_token': 'token'});
    final api = ApiClient(TokenStorage());
    bool saved = false;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      if (request.path == '/properties/property-1') {
        handler.resolve(Response(requestOptions: request,statusCode: 200,data: {
          'name': 'Test PG', 'address': 'Test Road', 'area': 'OMR', 'city': 'Chennai',
          'description': 'A room', 'rooms': [], 'availableBeds': [],
        }));
      } else if (request.path == '/customer/saved-properties/property-1') {
        expect(request.headers['Authorization'], 'Bearer token');
        saved = request.method == 'POST';
        handler.resolve(Response(requestOptions: request,statusCode: 200));
      } else {
        handler.reject(DioException(requestOptions: request));
      }
    }));
    await tester.pumpWidget(ProviderScope(overrides: [
      apiClientProvider.overrideWithValue(api),
      savedPropertiesProvider.overrideWith((ref) async => saved ? [{'id':'property-1'}] : []),
    ], child: const MaterialApp(home: PropertyDetails(id: 'property-1'))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save PG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save PG'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    await tester.ensureVisible(find.text('Remove from saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from saved'));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('discovery remains usable on a narrow $platform viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(overrides: [
        propertiesProvider.overrideWith((ref) async => [
          {'id': 'one', 'name': 'First PG', 'area': 'OMR', 'city': 'Chennai', 'startingRent': 8000, 'availableBeds': 1},
        ]),
      ], child: MaterialApp(theme: AppTheme.light.copyWith(platform: platform), home: const CustomerHomeScreen())));
      await tester.pumpAndSettle();
      expect(find.text('Find a place that\nfeels like you.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Chennai');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('First PG'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('First PG'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('applies and clears search against the server', (tester) async {
    final first = {'id': 'one', 'name': 'First PG', 'area': 'OMR', 'city': 'Chennai', 'startingRent': 8000, 'availableBeds': 1};
    final second = {'id': 'two', 'name': 'Second PG', 'area': 'Whitefield', 'city': 'Bengaluru', 'startingRent': 9000, 'availableBeds': 2};
    await tester.pumpWidget(ProviderScope(overrides: [
      amenitiesProvider.overrideWith((ref) async => []),
      propertiesProvider.overrideWith((ref) async => [first, second]),
      searchPropertiesProvider.overrideWith((ref, path) async {
        final term = Uri.parse(path).queryParameters['query'];
        return term == 'whitefield' ? [second] : term == 'not found' ? [] : [first, second];
      }),
    ], child: const MaterialApp(home: CustomerHomeScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'whitefield');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('First PG'), findsNothing);
    expect(find.text('Second PG'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'not found');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('No places match your search.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('First PG'), findsOneWidget);
  });

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
      savedPropertiesProvider.overrideWith((ref) async => []),
      amenitiesProvider.overrideWith((ref) async => []),
      propertiesProvider.overrideWith((ref) async => [
        {'id': 'property-1', 'name': 'Test PG', 'area': 'OMR', 'city': 'Chennai',
          'startingRent': 8000, 'availableBeds': 1},
      ]),
    ], child: const MaterialApp(home: CustomerHomeScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Test PG'), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Test PG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test PG'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Request'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Room 101 · Bed A'), findsOneWidget);
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.text('Booking requested; awaiting owner approval.'), findsOneWidget);
  });
}
