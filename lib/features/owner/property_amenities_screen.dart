import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/data_providers.dart';

class PropertyAmenitiesScreen extends ConsumerStatefulWidget {
  const PropertyAmenitiesScreen({super.key, required this.propertyId});
  final String propertyId;
  @override
  ConsumerState<PropertyAmenitiesScreen> createState() => _PropertyAmenitiesScreenState();
}

class _PropertyAmenitiesScreenState extends ConsumerState<PropertyAmenitiesScreen> {
  List<Json> amenities = [];
  Set<String> selected = {};
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final dio = ref.read(apiClientProvider).dio;
      final responses = await Future.wait([
        dio.get<List<dynamic>>('/amenities'),
        dio.get<List<dynamic>>('/owner/properties/${widget.propertyId}/amenities'),
      ]);
      if (responses.any((response) => response.data == null)) throw const FormatException('Missing amenities.');
      if (mounted) setState(() {
        amenities = responses[0].data!.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        selected = responses[1].data!.cast<String>().toSet();
      });
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    setState(() { busy = true; error = null; });
    try {
      await ref.read(apiClientProvider).dio.put<void>(
        '/owner/properties/${widget.propertyId}/amenities', data: {'codes': selected.toList()});
      ref.invalidate(propertiesProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Property amenities')),
    body: loading ? const Center(child: CircularProgressIndicator()) :
      error != null && amenities.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error!), TextButton(onPressed: load, child: const Text('Retry')),
      ])) : ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Select the amenities available at this property.'),
        for (final item in amenities) CheckboxListTile(
          title: Text(item['name'] as String),
          value: selected.contains(item['code']),
          onChanged: busy ? null : (value) => setState(() {
            if (value == true) { selected.add(item['code'] as String); }
            else { selected.remove(item['code']); }
          }),
        ),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Saving...' : 'Save amenities')),
      ]),
  );
}
