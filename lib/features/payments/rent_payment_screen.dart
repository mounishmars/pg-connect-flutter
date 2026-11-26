import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../core/api/api_client.dart';
import '../../core/api/data_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/design_widgets.dart';
import '../owner/owner_inventory_screen.dart' show validAmount;

class RentPaymentScreen extends ConsumerStatefulWidget {
  const RentPaymentScreen({super.key, required this.invoiceId, required this.outstandingBalance});
  final String invoiceId;
  final num outstandingBalance;
  @override
  ConsumerState<RentPaymentScreen> createState() => _RentPaymentScreenState();
}

class _RentPaymentScreenState extends ConsumerState<RentPaymentScreen> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController();
  final email = TextEditingController();
  final storage = const FlutterSecureStorage();
  Json? active;
  Json? pending;
  bool loading = true;
  bool loadFailed = false;
  bool busy = false;
  String? message;
  String get storageKey => 'payment_request_${widget.invoiceId}';
  bool get enabled => kDebugMode && stripeTestCheckout && stripePublishableKey.startsWith('pk_test_');

  @override
  void initState() {
    super.initState();
    amount.text = widget.outstandingBalance.toStringAsFixed(2);
    load();
  }
  @override
  void dispose() { amount.dispose(); email.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { loading = true; loadFailed = false; message = null; });
    try {
      final saved = await storage.read(key: storageKey);
      final savedRequest = saved == null ? null : Map<String, dynamic>.from(jsonDecode(saved) as Map);
      final response = await ref.read(apiClientProvider).dio.get<Json>('/customer/rent/payments/active',
        queryParameters: {'invoiceId': widget.invoiceId});
      if (response.data == null && savedRequest?['orderId'] is String) {
        final status = await ref.read(apiClientProvider).dio.post<Json>(
          '/customer/rent/payments/${savedRequest!['orderId']}/reconcile');
        if (status.data?['status'] == 'PAID' || status.data?['status'] == 'CANCELLED') {
          await storage.delete(key: storageKey);
          ref.invalidate(invoicesProvider);
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        pending = savedRequest;
        active = response.data;
        if (active != null) {
          amount.text = (active!['amount'] as num).toStringAsFixed(2);
        } else if (pending != null) {
          amount.text = pending!['amount'] as String;
          email.text = pending!['email'] as String;
        }
      });
    } catch (e) {
      if (mounted) setState(() { loadFailed = true; message = apiError(e); });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String newKey() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> pay() async {
    if (busy) return;
    if (active == null && !form.currentState!.validate()) return;
    setState(() { busy = true; message = null; });
    try {
      if (active == null) {
        final request = pending ?? {'key': newKey(), 'amount': amount.text.trim(), 'email': email.text.trim()};
        if (pending == null) {
          await storage.write(key: storageKey, value: jsonEncode(request));
          pending = request;
        }
        final response = await ref.read(apiClientProvider).dio.post<Json>('/customer/rent/payments',
          options: Options(headers: {'Idempotency-Key': request['key']}),
          data: {'invoiceId': widget.invoiceId, 'amount': request['amount'], 'customerEmail': request['email']});
        final data = response.data;
        if (data == null || data['paymentOrderId'] is! String || data['paymentSessionId'] is! String) {
          throw const FormatException('Invalid payment session response.');
        }
        if (data['status'] == 'PAID' || data['status'] == 'CANCELLED') {
          await storage.delete(key: storageKey);
          ref.invalidate(invoicesProvider);
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
        request['orderId'] = data['paymentOrderId'];
        await storage.write(key: storageKey, value: jsonEncode(request));
        pending = request;
        active = data;
      }
      Stripe.publishableKey = stripePublishableKey;
      Stripe.urlScheme = 'pgconnectstripe';
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'PG Connect',
        paymentIntentClientSecret: active!['paymentSessionId'] as String,
        returnURL: 'pgconnectstripe://redirect',
        allowsDelayedPaymentMethods: true,
      ));
      await Stripe.instance.presentPaymentSheet();
      await reconcile();
    } on StripeException catch (e) {
      if (mounted) {
        setState(() => message = e.error.code == FailureCode.Canceled
          ? 'Checkout cancelled. Your payment is still open; resume or cancel it below.'
          : 'Stripe checkout did not complete. Check payment status before retrying.');
      }
    } catch (e) {
      if (mounted) setState(() => message = '${apiError(e)} Your request is saved; retry with the same details.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reconcile() async {
    final id = active?['paymentOrderId'];
    if (id is! String) throw const FormatException('Missing payment order ID.');
    final response = await ref.read(apiClientProvider).dio.post<Json>('/customer/rent/payments/$id/reconcile');
    final status = response.data?['status'];
    if (status == 'PAID') {
      await storage.delete(key: storageKey);
      ref.invalidate(invoicesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } else {
      if (mounted) {
        setState(() => message = 'Payment is not confirmed yet. Check status again later.');
      }
    }
  }

  Future<void> check() async {
    setState(() { busy = true; message = null; });
    try { await reconcile(); } catch (e) {
      if (mounted) setState(() => message = apiError(e));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> cancel() async {
    final id = active?['paymentOrderId'];
    if (id is! String) return;
    setState(() { busy = true; message = null; });
    try {
      await ref.read(apiClientProvider).dio.post<void>('/customer/rent/payments/$id/cancel');
      await storage.delete(key: storageKey);
      if (mounted) setState(() { active = null; pending = null; message = 'Payment cancelled.'; });
    } catch (e) {
      if (mounted) setState(() => message = '${apiError(e)} Check payment status before trying again.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Test rent payment')),
    body: !enabled ? const Center(child: Text('Stripe test checkout is not configured.')) :
      loading ? const Center(child: CircularProgressIndicator()) :
      Form(key: form, child: ListView(padding: const EdgeInsets.all(20), children: [
        DesignPanel(color: AppTheme.paleGreen, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OUTSTANDING BALANCE', style: TextStyle(color: AppTheme.muted, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('₹${widget.outstandingBalance.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Test mode only. Payments go to the platform account, not to the owner.', style: TextStyle(color: AppTheme.muted)),
        ])),
        const SizedBox(height: 18),
        TextFormField(controller: amount, enabled: !busy && active == null && pending == null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount (INR)'),
          validator: (value) {
            final invalid = validAmount(value);
            if (invalid != null) return invalid;
            if (double.parse(value!.trim()) > widget.outstandingBalance) return 'Amount exceeds the invoice balance.';
            return null;
          }),
        if (active == null) const SizedBox(height: 12),
        if (active == null) TextFormField(controller: email, enabled: !busy && pending == null,
          keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'),
          validator: (value) => value == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
            ? 'Enter a valid email address.' : null),
        if (message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(message!)),
        if (loadFailed)
          TextButton(onPressed: busy ? null : load, child: const Text('Retry loading payment status')),
        const SizedBox(height: 16),
        FilledButton(onPressed: busy || loadFailed ? null : pay, child: Text(busy ? 'Please wait...' : active == null ? 'Continue to Stripe' : 'Resume checkout')),
        if (active != null) ...[
          TextButton(onPressed: busy ? null : check, child: const Text('Check payment status')),
          TextButton(onPressed: busy ? null : cancel, child: const Text('Cancel open payment')),
        ],
      ])));
}
