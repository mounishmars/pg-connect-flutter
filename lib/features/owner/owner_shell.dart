import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/data_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../customer/customer_shell.dart';
import 'owner_dashboard_screen.dart';
import 'owner_inventory_screen.dart';
import 'owner_invoices.dart';

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});
  @override
  State<OwnerShell> createState() => _OwnerShellState();
}
class _OwnerShellState extends State<OwnerShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: [const OwnerDashboardScreen(), const OwnerProperties(), const OwnerBookings(), const AccountScreen()][index],
    bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (value) => setState(() => index = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.apartment), label: 'My PGs'),
        NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Bookings'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
      ]));
}

class OwnerProperties extends ConsumerWidget {
  const OwnerProperties({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('My PG properties')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => const PropertyForm())),
      icon: const Icon(Icons.add), label: const Text('Add property')),
    body: AsyncView<List<Json>>(value: ref.watch(ownerPropertiesProvider), retry: () => ref.invalidate(ownerPropertiesProvider),
      builder: (items) => items.isEmpty ? const Center(child: Text('No properties yet. Add one to get started.')) :
        ListView(children: [for (final item in items) ListTile(title: Text(item['name'] as String),
          subtitle: Text('${item['area']}, ${item['city']} · ${item['active'] == true ? 'Active' : 'Inactive'}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => InventoryScreen(property: item))))])));
}

class OwnerBookings extends ConsumerStatefulWidget {
  const OwnerBookings({super.key});
  @override
  ConsumerState<OwnerBookings> createState() => _OwnerBookingsState();
}
class _OwnerBookingsState extends ConsumerState<OwnerBookings> {
  String? busy;
  Future<void> change(Json item, String action) async {
    setState(() => busy = item['id'] as String);
    try {
      await ref.read(apiClientProvider).dio.post<void>('/owner/bookings/${item['id']}/$action');
      ref.invalidate(ownerBookingsProvider);
      ref.invalidate(dashboardProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally { if (mounted) setState(() => busy = null); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Tenant bookings'), actions: [
      IconButton(tooltip: 'View invoices', icon: const Icon(Icons.receipt_long),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const OwnerInvoices()))),
    ]),
    body: AsyncView<List<Json>>(value: ref.watch(ownerBookingsProvider), retry: () => ref.invalidate(ownerBookingsProvider),
      builder: (items) => items.isEmpty ? const Center(child: Text('No booking requests yet.')) :
        ListView(children: [for (final item in items) Card(child: ListTile(
          title: Text(item['tenantName'] as String),
          subtitle: Text('${item['propertyName']} · Room ${item['roomName']} · Bed ${item['bedLabel']}\n${item['status']}'),
          isThreeLine: true,
          trailing: item['status'] == 'APPROVED' ? IconButton(
            tooltip: 'Create invoice', icon: const Icon(Icons.add_card),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => CreateInvoice(booking: item))))
            : item['status'] == 'PENDING' ? PopupMenuButton<String>(
              enabled: busy == null, onSelected: (action) => change(item, action),
              itemBuilder: (_) => const [PopupMenuItem(value: 'approve', child: Text('Approve')),
                PopupMenuItem(value: 'reject', child: Text('Reject'))]) : null,
        ))])));
}
