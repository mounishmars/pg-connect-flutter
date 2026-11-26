import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/data_providers.dart';
import '../../shared/widgets/async_view.dart';
import 'owner_inventory_screen.dart';

class OwnerInvoices extends ConsumerWidget {
  const OwnerInvoices({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Rent invoices')),
    body: AsyncView<List<Json>>(value: ref.watch(ownerInvoicesProvider),
      retry: () => ref.invalidate(ownerInvoicesProvider),
      builder: (items) => items.isEmpty ? const Center(child: Text('No invoices yet.')) :
        ListView(children: [for (final item in items) ListTile(
          title: Text(item['invoiceNumber'] as String),
          subtitle: Text('Due ${item['dueDate']} · ${item['status']}'),
          trailing: Text('₹${item['balance']}'))])));
}

class CreateInvoice extends ConsumerStatefulWidget {
  const CreateInvoice({super.key, required this.booking});
  final Json booking;
  @override
  ConsumerState<CreateInvoice> createState() => _CreateInvoiceState();
}

class _CreateInvoiceState extends ConsumerState<CreateInvoice> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController();
  DateTime? dueDate;
  bool busy = false;
  String? error;

  @override
  void dispose() { amount.dispose(); super.dispose(); }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (dueDate == null) {
      setState(() => error = 'Select a due date.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await ref.read(apiClientProvider).dio.post<Json>('/owner/invoices', data: {
        'bookingId': widget.booking['id'],
        'amount': amount.text.trim(),
        'dueDate': DateFormat('yyyy-MM-dd').format(dueDate!),
      });
      ref.invalidate(ownerInvoicesProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = '${apiError(e)} Check the invoice list before retrying to avoid duplicates.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create rent invoice')),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.all(20), children: [
      Text('${widget.booking['tenantName']} · ${widget.booking['propertyName']}'),
      const SizedBox(height: 12),
      TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Amount (INR)'), validator: validAmount),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: busy ? null : () async {
        final today = DateTime.now();
        final date = await showDatePicker(context: context, initialDate: dueDate ?? today,
          firstDate: DateTime(today.year - 1), lastDate: DateTime(today.year + 10));
        if (date != null) setState(() { dueDate = date; error = null; });
      }, child: Text(dueDate == null ? 'Select due date' : 'Due ${DateFormat('yyyy-MM-dd').format(dueDate!)}')),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 12),
      FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Creating...' : 'Create invoice')),
    ])));
}
