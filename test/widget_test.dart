import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pg_connect/app/pg_connect_app.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  testWidgets('shows the PG Connect login screen', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: PgConnectApp()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to PG Connect'), findsOneWidget);
  });
}
