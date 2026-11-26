import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/data_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/design_widgets.dart';
import 'customer_home_screen.dart';

class SavedPropertiesScreen extends ConsumerWidget {
  const SavedPropertiesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Saved PGs')),
    body: AsyncView<List<Json>>(value: ref.watch(savedPropertiesProvider),
      retry: () => ref.invalidate(savedPropertiesProvider),
      builder: (properties) => properties.isEmpty
        ? const EmptyPanel(icon: Icons.favorite_border, title: 'No saved PGs yet.',
            message: 'Save a property from its details to find it here later.')
        : ListView(padding: const EdgeInsets.all(20), children: [
          for (final item in properties) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(clipBehavior: Clip.antiAlias, child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (_) => PropertyDetails(id: item['id'] as String))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PropertyPhoto(path: item['coverPhotoId'] == null ? null :
                  '/properties/${item['id']}/photos/${item['coverPhotoId']}'),
                ListTile(title: Text(item['name'] as String),
                  subtitle: Text('${item['area']}, ${item['city']}'),
                  trailing: const Icon(Icons.chevron_right)),
              ]),
            )),
          ),
        ])));
}
