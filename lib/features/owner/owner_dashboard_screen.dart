import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/data_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/design_widgets.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Owner dashboard')),
    body: AsyncView<Json>(value: ref.watch(dashboardProvider), retry: () => ref.invalidate(dashboardProvider),
      builder: (data) => ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Your space, at a glance', style: TextStyle(color: AppTheme.muted)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: AppTheme.forest, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('RENT DUE', style: TextStyle(color: Color(0xFFBCD9C7), letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('₹${data['rentDue']}', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Outstanding across your properties', style: TextStyle(color: Color(0xFFD4E5D8))),
          ]),
        ),
        const SizedBox(height: 24),
        Text('Your spaces', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        for (final entry in {
          'Total beds': data['totalBeds'], 'Occupied': data['occupied'], 'Vacant beds': data['vacantBeds'],
        }.entries) Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DesignPanel(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(entry.key, style: const TextStyle(color: AppTheme.muted)),
            Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          ])),
        ),
      ])));
}
