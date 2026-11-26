import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/data_providers.dart';
import '../../shared/widgets/async_view.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Explore PGs')),
    body: AsyncView<List<Json>>(value: ref.watch(propertiesProvider),
      retry: () => ref.invalidate(propertiesProvider),
      builder: (properties) => properties.isEmpty
        ? const Center(child: Text('No properties available yet.'))
        : RefreshIndicator(onRefresh: () async { ref.invalidate(propertiesProvider); await ref.read(propertiesProvider.future); },
          child: ListView.builder(itemCount: properties.length, itemBuilder: (context, index) {
            final item = properties[index];
            return ListTile(title: Text(item['name'] as String),
              subtitle: Text('${item['area']}, ${item['city']} · ${item['availableBeds']} beds available'),
              trailing: Text(item['startingRent'] == null ? 'No rooms' : '₹${item['startingRent']}/mo'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PropertyDetails(id: item['id'] as String))));
          }))),
  );
}

class PropertyDetails extends ConsumerStatefulWidget {
  const PropertyDetails({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends ConsumerState<PropertyDetails> {
  late Future<Json> details;
  bool busy = false;
  @override
  void initState() { super.initState(); details = load(); }
  Future<Json> load() async {
    final response = await ref.read(apiClientProvider).dio.get<Json>('/properties/${widget.id}');
    if (response.data == null) throw const FormatException('Missing property response.');
    return response.data!;
  }
  Future<void> book(String id) async {
    setState(() => busy = true);
    try {
      await ref.read(apiClientProvider).dio.post<Json>('/customer/bookings', data: {'bedId': id});
      ref.invalidate(bookingsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking requested; awaiting owner approval.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Property details')),
    body: FutureBuilder<Json>(future: details, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) {
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(apiError(snapshot.error!)),
          TextButton(onPressed: () => setState(() => details = load()), child: const Text('Retry')),
        ]));
      }
      final item = snapshot.requireData;
      final beds = (item['availableBeds'] as List<dynamic>).cast<Map<String, dynamic>>();
      final rooms = (item['rooms'] as List<dynamic>).cast<Map<String, dynamic>>();
      final roomNames = {for (final room in rooms) room['id']: room['name']};
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text(item['name'] as String, style: Theme.of(context).textTheme.headlineSmall),
        Text('${item['address']}, ${item['area']}, ${item['city']}'),
        const SizedBox(height: 12), Text(item['description'] as String),
        const SizedBox(height: 20), Text('Available beds', style: Theme.of(context).textTheme.titleLarge),
        if (beds.isEmpty) const Text('No beds available.'),
        for (final bed in beds) ListTile(title: Text('Room ${roomNames[bed['roomId']] ?? bed['roomId']} · Bed ${bed['label']}'),
          trailing: FilledButton(onPressed: busy ? null : () => book(bed['id'] as String), child: const Text('Request'))),
      ]);
    }));
}
