import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/data_providers.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/design_widgets.dart';
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
      builder: (items) => items.isEmpty
        ? const EmptyPanel(icon: Icons.bed_outlined, title: 'No bookings yet.', message: 'Your booking requests will appear here.')
        : ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Everything about your stay, in one place.', style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 16),
          for (final item in items) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DesignPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(item['propertyName'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                StatusBadge(item['status'] as String),
              ]),
              const SizedBox(height: 8),
              Text('Room ${item['roomName']} · Bed ${item['bedLabel']}', style: const TextStyle(color: AppTheme.muted)),
              if (item['status'] == 'PENDING') TextButton(child: const Text('Cancel'), onPressed: () async {
                try {
                  await ref.read(apiClientProvider).dio.post<void>('/customer/bookings/${item['id']}/cancel');
                  ref.invalidate(bookingsProvider);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
                }
              }),
            ])),
          ),
        ])));
}

class CustomerInvoices extends ConsumerWidget {
  const CustomerInvoices({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('Rent invoices')),
    body: AsyncView<List<Json>>(value: ref.watch(invoicesProvider), retry: () => ref.invalidate(invoicesProvider),
      builder: (items) => items.isEmpty
        ? const EmptyPanel(icon: Icons.receipt_long_outlined, title: 'No invoices yet.', message: 'Your rent invoices will appear here.')
        : ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Stay on top of the little things.', style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 8),
          const Text('Stripe test checkout requires local test configuration.', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          const SizedBox(height: 16),
          for (final item in items) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              title: Text(item['invoiceNumber'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text('Due ${item['dueDate']} · ${item['status']}')),
              trailing: Text('₹${item['balance']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: item['status'] == 'UNPAID' || item['status'] == 'PARTIALLY_PAID'
              ? () async {
                  final updated = await Navigator.of(context).push<bool>(MaterialPageRoute(
                    builder: (_) => RentPaymentScreen(invoiceId: item['id'] as String, outstandingBalance: item['balance'] as num)));
                  if (updated == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment status refreshed.')));
                  }
                } : null),
            ),
          ),
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
      DesignPanel(color: AppTheme.paleGreen, child: Row(children: [
        CircleAvatar(backgroundColor: const Color(0xFFD4E7D7), foregroundColor: AppTheme.forest,
          child: Text(auth.displayName.isEmpty ? '?' : auth.displayName.characters.first.toUpperCase())),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(auth.displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(auth.role == UserRole.owner ? 'Owner' : 'Resident', style: const TextStyle(color: AppTheme.muted)),
        ])),
      ])),
      const SizedBox(height: 20),
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
