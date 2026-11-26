import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/api/data_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/design_widgets.dart';

final photoPickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

class PropertyPhotosScreen extends ConsumerStatefulWidget {
  const PropertyPhotosScreen({super.key, required this.propertyId});
  final String propertyId;
  @override
  ConsumerState<PropertyPhotosScreen> createState() => _PropertyPhotosScreenState();
}

class _PropertyPhotosScreenState extends ConsumerState<PropertyPhotosScreen> {
  bool busy = false;
  String get path => '/owner/properties/${widget.propertyId}/photos';

  void refresh() {
    ref.invalidate(ownerPhotosProvider(widget.propertyId));
    ref.invalidate(ownerPropertiesProvider);
    ref.invalidate(propertiesProvider);
  }

  Future<void> upload(int count) async {
    setState(() => busy = true);
    int uploaded = 0;
    try {
      final selected = await ref.read(photoPickerProvider).pickMultiImage(limit: 10 - count);
      if (selected.isEmpty) return;
      if (selected.length > 10 - count) {
        throw const FormatException('Choose no more than 10 photos per property.');
      }
      for (final image in selected) {
        final size = await image.length();
        if (size == 0 || size > 5 * 1024 * 1024) {
          throw const FormatException('Each photo must be between 1 byte and 5 MB.');
        }
      }
      for (final image in selected) {
        final bytes = await image.readAsBytes();
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: image.name),
        });
        await ref.read(apiClientProvider).dio.post<Json>(path, data: form);
        uploaded++;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$uploaded ${uploaded == 1 ? 'photo' : 'photos'} uploaded.')));
    } on FormatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      final message = error is DioException && error.response?.statusCode == 400
        ? 'The server rejected a photo. Use a valid JPEG or PNG up to 5 MB and 16 megapixels.'
        : apiError(error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$message $uploaded photos uploaded; check the list before retrying.')));
      }
    } finally {
      if (mounted) { refresh(); setState(() => busy = false); }
    }
  }

  Future<void> change(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(error))));
    } finally {
      if (mounted) { refresh(); setState(() => busy = false); }
    }
  }

  Future<void> remove(String photoId) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete photo?'),
      content: const Text('This photo will be removed from the property.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ));
    if (confirmed == true && mounted) {
      await change(() async { await ref.read(apiClientProvider).dio.delete<void>('$path/$photoId'); });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Property photos')),
    body: AsyncView<List<Json>>(value: ref.watch(ownerPhotosProvider(widget.propertyId)),
      retry: () => ref.invalidate(ownerPhotosProvider(widget.propertyId)),
      builder: (photos) => ListView(padding: const EdgeInsets.all(20), children: [
        Text('${photos.length} of 10 photos · JPEG or PNG, up to 5 MB and 16 megapixels each'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy || photos.length >= 10 ? null : () => upload(photos.length),
          icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Add photos'),
        ),
        const SizedBox(height: 12),
        if (photos.isEmpty) const Text('No photos yet. The first photo will be the cover.'),
        for (var index = 0; index < photos.length; index++)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Card(clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PropertyPhoto(path: '$path/${photos[index]['id']}', height: 180),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
                  if (photos[index]['cover'] == true) const StatusBadge('COVER')
                  else TextButton(onPressed: busy ? null : () => change(() async {
                    await ref.read(apiClientProvider).dio.put<void>('$path/${photos[index]['id']}/cover');
                  }), child: const Text('Set cover')),
                  IconButton(tooltip: 'Move photo up', icon: const Icon(Icons.arrow_upward),
                    onPressed: busy || index == 0 ? null : () => move(photos, index, index - 1)),
                  IconButton(tooltip: 'Move photo down', icon: const Icon(Icons.arrow_downward),
                    onPressed: busy || index == photos.length - 1 ? null : () => move(photos, index, index + 1)),
                  IconButton(tooltip: 'Delete photo', icon: const Icon(Icons.delete_outline),
                    onPressed: busy ? null : () => remove(photos[index]['id'] as String)),
                ],
              )),
            ]),
          )),
      ]),
    ),
  );

  Future<void> move(List<Json> photos, int from, int to) async {
    final ids = photos.map((photo) => photo['id'] as String).toList();
    final id = ids.removeAt(from);
    ids.insert(to, id);
    await change(() async {
      await ref.read(apiClientProvider).dio.put<void>('$path/order', data: {'photoIds': ids});
    });
  }
}
