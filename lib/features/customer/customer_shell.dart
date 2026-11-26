import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/data_providers.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/async_view.dart';
import 'customer_home_screen.dart';
import '../payments/rent_payment_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}
class _CustomerShellState extends State<CustomerShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: [const CustomerHomeScreen(), const CustomerBookings(), const CustomerInvoices(), const AccountScreen()][index],
    bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (value) => setState(() => index = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.search), label: 'Explore'),
        NavigationDestination(icon: Icon(Icons.bed_outlined), label: 'Bookings'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Invoices'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
      ]),
  );
}

class CustomerBookings extends ConsumerWidget {
  const CustomerBookings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('My bookings')),
    body: AsyncView<List<Json>>(value: ref.watch(bookingsProvider), retry: () => ref.invalidate(bookingsProvider),
      builder: (items) => items.isEmpty ? const Center(child: Text('No bookings yet.')) :
        ListView(children: [for (final item in items) ListTile(
          title: Text(item['propertyName'] as String),
          subtitle: Text('Room ${item['roomName']} · Bed ${item['bedLabel']} · ${item['status']}'),
          trailing: item['status'] != 'PENDING' ? null : TextButton(child: const Text('Cancel'), onPressed: () async {
            try {
              await ref.read(apiClientProvider).dio.post<void>('/customer/bookings/${item['id']}/cancel');
              ref.invalidate(bookingsProvider);
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
            }
          }),
        )])));
}

class CustomerInvoices extends ConsumerWidget {
  const CustomerInvoices({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('Rent invoices')),
    body: AsyncView<List<Json>>(value: ref.watch(invoicesProvider), retry: () => ref.invalidate(invoicesProvider),
      builder: (items) => items.isEmpty ? const Center(child: Text('No invoices yet.')) :
        ListView(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Stripe test checkout requires local test configuration.')),
          for (final item in items) ListTile(title: Text(item['invoiceNumber'] as String),
            subtitle: Text('Due ${item['dueDate']} · ${item['status']}'), trailing: Text('₹${item['balance']}'),
            onTap: item['status'] == 'UNPAID' || item['status'] == 'PARTIALLY_PAID'
              ? () async {
                  final updated = await Navigator.of(context).push<bool>(MaterialPageRoute(
                    builder: (_) => RentPaymentScreen(invoiceId: item['id'] as String, outstandingBalance: item['balance'] as num)));
                  if (updated == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment status refreshed.')));
                  }
                } : null),
        ])));
}

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}
class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool busy = false;
  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try { await action(); } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    return Scaffold(appBar: AppBar(title: const Text('Account')), body: ListView(padding: const EdgeInsets.all(20), children: [
      Text(auth.displayName, style: Theme.of(context).textTheme.headlineSmall),
      if (auth.ownerApplicationStatus != null) Text('Owner application: ${auth.ownerApplicationStatus}'),
      if (auth.ownerId == null && auth.ownerApplicationStatus != 'PENDING')
        TextButton(onPressed: busy ? null : () => run(() async {
          await ref.read(apiClientProvider).dio.post<Json>('/owner-applications', data: {'displayName': auth.displayName});
          await controller.refreshProfile();
        }), child: const Text('Apply for owner access')),
      if (auth.ownerId != null)
        TextButton(onPressed: busy ? null : () => controller.switchRole(auth.role == UserRole.owner ? UserRole.customer : UserRole.owner),
          child: Text(auth.role == UserRole.owner ? 'Switch to customer' : 'Switch to owner')),
      TextButton(onPressed: busy ? null : () => run(controller.refreshProfile), child: const Text('Refresh account status')),
      TextButton(onPressed: busy ? null : () => run(controller.signOut), child: const Text('Sign out')),
    ]));
  }
}
