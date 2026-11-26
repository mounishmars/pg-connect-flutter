import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'app/pg_connect_app.dart';
import 'core/api/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (firebaseAuthEnabled) {
    try {
      if (developmentOtp) throw StateError('Firebase and development OTP cannot be enabled together.');
      if (kReleaseMode && Uri.parse(apiBaseUrl).scheme != 'https') {
        throw StateError('Firebase authentication requires an HTTPS API in release builds.');
      }
      const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
      const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
      const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
      const androidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
      const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
      const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
      final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      final appId = isAndroid ? androidAppId : iosAppId;
      final apiKey = isAndroid ? androidApiKey : iosApiKey;
      if ((!isAndroid && !isIos) || projectId.isEmpty || senderId.isEmpty || appId.isEmpty || apiKey.isEmpty) {
        throw StateError('Firebase configuration is missing or this platform is unsupported.');
      }
      await Firebase.initializeApp(options: FirebaseOptions(
        apiKey: apiKey, appId: appId, messagingSenderId: senderId, projectId: projectId,
        iosBundleId: isIos ? const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID') : null,
      ));
    } catch (error) {
      runApp(MaterialApp(home: Scaffold(body: Center(
        child: Text('Firebase initialization failed: $error', textAlign: TextAlign.center),
      ))));
      return;
    }
  }
  runApp(const ProviderScope(child: PgConnectApp()));
}
