import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/auth_controller.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class PgConnectApp extends ConsumerWidget {
  const PgConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return MaterialApp.router(
      title: 'PG Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: createRouter(auth),
    );
  }
}
