import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/design_widgets.dart';

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
  String? verificationId;
  int? resendToken;
  String? error;
  bool busy = false;
  bool phoneConsent = false;
  bool completing = false;
  int requestGeneration = 0;

  @override
  void dispose() {
    requestGeneration++;
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
    if (firebaseAuthEnabled) {
      if (name.text.trim().isEmpty || name.text.trim().length > 150) {
        setState(() => error = 'Enter your full name (up to 150 characters).');
        return;
      }
      if (!phoneConsent) {
        setState(() => error = 'Please consent to phone verification.');
        return;
      }
      final generation = ++requestGeneration;
      setState(() { busy = true; error = null; });
      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: number,
          forceResendingToken: resendToken,
          verificationCompleted: (credential) async {
            if (!mounted || generation != requestGeneration || completing) return;
            await completeFirebase(credential);
          },
          verificationFailed: (failure) {
            if (!mounted || generation != requestGeneration || completing) return;
            setState(() { error = firebaseError(failure); busy = false; });
          },
          codeSent: (id, token) {
            if (!mounted || generation != requestGeneration || completing) return;
            setState(() {
              requestedPhone = number;
              verificationId = id;
              resendToken = token;
              busy = false;
            });
          },
          codeAutoRetrievalTimeout: (id) {
            if (!mounted || generation != requestGeneration || completing) return;
            setState(() { verificationId = id; requestedPhone = number; busy = false; });
          },
        );
      } on FirebaseAuthException catch (failure) {
        if (mounted && generation == requestGeneration) setState(() { error = firebaseError(failure); busy = false; });
      } catch (failure) {
        if (mounted && generation == requestGeneration) setState(() { error = apiError(failure); busy = false; });
      }
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
    if (firebaseAuthEnabled) {
      final id = verificationId;
      if (id == null) {
        setState(() => error = 'Request a new verification code.');
        return;
      }
      await completeFirebase(PhoneAuthProvider.credential(verificationId: id, smsCode: code.text.trim()));
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

  Future<void> completeFirebase(PhoneAuthCredential credential) async {
    if (completing) return;
    setState(() { completing = true; busy = true; error = null; });
    try {
      await ref.read(authControllerProvider.notifier).completeFirebaseSignIn(credential, name.text.trim());
      requestGeneration++;
    } on FirebaseAuthException catch (failure) {
      if (mounted) setState(() => error = firebaseError(failure));
    } catch (failure) {
      if (mounted) setState(() => error = apiError(failure));
    } finally {
      if (mounted) setState(() { completing = false; busy = false; });
    }
  }

  String firebaseError(FirebaseAuthException failure) {
    switch (failure.code) {
      case 'invalid-verification-code': return 'That code is incorrect. Try again.';
      case 'session-expired': return 'The code expired. Request a new code.';
      case 'too-many-requests': return 'Too many attempts. Please wait before trying again.';
      case 'invalid-phone-number': return 'That phone number is invalid.';
      case 'network-request-failed': return 'Cannot reach the verification service. Check your connection.';
      default: return 'Phone verification failed (${failure.code}). Please try again.';
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.forest, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 28),
          Text('Welcome to PG Connect', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('A better way to feel at home.', style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 24),
          if (auth.error != null) ...[
            Text(auth.error!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: () => ref.read(authControllerProvider.notifier).restore(), child: const Text('Retry session')),
          ],
          if (firebaseAuthEnabled) ...[
            const Text('Your phone number is sent to Google for verification and abuse prevention. SMS charges may apply.'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: phoneConsent,
              onChanged: busy || requestedPhone != null ? null : (value) => setState(() => phoneConsent = value == true),
              title: const Text('I agree to phone verification.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            TextField(controller: name, enabled: !busy && requestedPhone == null,
              maxLength: 150, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: phone, enabled: !busy && requestedPhone == null,
              keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone with country code')),
            if (requestedPhone != null) ...[
              const SizedBox(height: 12),
              Text('Code sent to $requestedPhone'),
              TextField(controller: code, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Six-digit code')),
              TextButton(onPressed: busy ? null : request, child: const Text('Request a new code')),
              TextButton(onPressed: busy ? null : () => setState(() {
                requestGeneration++;
                requestedPhone = null; verificationId = null; resendToken = null; code.clear(); error = null;
              }), child: const Text('Change phone')),
            ],
            if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : (requestedPhone == null ? request : verify),
              child: Text(busy ? 'Please wait...' : requestedPhone == null ? 'Request code' : 'Sign in'))),
          ] else if (!kDebugMode || !developmentOtp)
            const Text('Production sign-in is not configured. Enable DEVELOPMENT_OTP only for local development.')
          else ...[
            const DesignPanel(color: AppTheme.paleGreen, child: Text('Development sign-in: the test code is displayed here; no SMS is sent.')),
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
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : (requestedPhone == null ? request : verify),
              child: Text(busy ? 'Please wait...' : requestedPhone == null ? 'Request code' : 'Sign in'))),
          ],
        ])),
    ))));
  }
}
