import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/data_providers.dart';
import '../../shared/widgets/async_view.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Owner dashboard')),
    body: AsyncView<Json>(value: ref.watch(dashboardProvider), retry: () => ref.invalidate(dashboardProvider),
      builder: (data) => ListView(padding: const EdgeInsets.all(20), children: [
        for (final entry in {
          'Total beds': data['totalBeds'], 'Occupied': data['occupied'],
          'Vacant beds': data['vacantBeds'], 'Rent due': '₹${data['rentDue']}',
        }.entries) Card(child: ListTile(title: Text(entry.key), trailing: Text('${entry.value}'))),
      ])));
}
