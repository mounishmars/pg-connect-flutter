import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final phone = TextEditingController();
  final name = TextEditingController();
  final code = TextEditingController();
  String? requestedPhone;
  String? devCode;
  String? error;
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    name.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> request() async {
    final number = phone.text.trim();
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(number)) {
      setState(() => error = 'Enter a phone number with country code, e.g. +919876543210.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final result = await ref.read(authControllerProvider.notifier).requestOtp(number);
      if (mounted) setState(() { requestedPhone = number; devCode = result; });
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    if (name.text.trim().isEmpty || !RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(() => error = 'Enter your name and the six-digit code.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(requestedPhone!, code.text.trim(), name.text.trim());
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Welcome to PG Connect', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          if (auth.error != null) ...[
            Text(auth.error!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: () => ref.read(authControllerProvider.notifier).restore(), child: const Text('Retry session')),
          ],
          if (!kDebugMode || !developmentOtp)
            const Text('Production sign-in is not configured. Enable DEVELOPMENT_OTP only for local development.')
          else ...[
            const Text('Development sign-in: the test code is displayed here; no SMS is sent.'),
            const SizedBox(height: 20),
            TextField(controller: phone, enabled: !busy && requestedPhone == null,
              keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone with country code')),
            if (requestedPhone != null) ...[
              const SizedBox(height: 12),
              Text('Development code: $devCode'),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
              TextField(controller: code, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Six-digit code')),
              TextButton(onPressed: busy ? null : () => setState(() { requestedPhone = null; devCode = null; code.clear(); }),
                child: const Text('Change phone or request a new code')),
            ],
            if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : (requestedPhone == null ? request : verify),
              child: Text(busy ? 'Please wait...' : requestedPhone == null ? 'Request code' : 'Sign in')),
          ],
        ])),
    ))));
  }
}
