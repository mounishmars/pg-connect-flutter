import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/data_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/design_widgets.dart';
import '../owner/owner_inventory_screen.dart' show validAmount;
import 'saved_properties_screen.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  final query = TextEditingController();
  String? appliedPath;
  final maxRent = TextEditingController();
  bool availableOnly = false;
  final selectedAmenities = <String>{};
  final moreProperties = <Json>[];
  bool loadingMore = false;
  bool morePageFull = true;
  int searchGeneration = 0;

  @override
  void dispose() { query.dispose(); maxRent.dispose(); super.dispose(); }

  void applyFilters() {
    final rent = maxRent.text.trim();
    if (rent.isNotEmpty && validAmount(rent) != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid maximum monthly rent.')));
      return;
    }
    final params = <String, dynamic>{
      if (query.text.trim().isNotEmpty) 'query': query.text.trim(),
      if (rent.isNotEmpty) 'maxRent': rent,
      if (availableOnly) 'availableOnly': 'true',
      if (selectedAmenities.isNotEmpty) 'amenity': selectedAmenities.toList(),
    };
    setState(() {
      appliedPath = Uri(path: '/properties', queryParameters: params).toString();
      moreProperties.clear();
      morePageFull = true;
      loadingMore = false;
      searchGeneration++;
    });
  }

  Future<void> loadMore(int offset) async {
    final generation = searchGeneration;
    final uri = Uri.parse(appliedPath ?? '/properties');
    final params = Map<String, List<String>>.from(uri.queryParametersAll);
    params['offset'] = ['$offset'];
    setState(() => loadingMore = true);
    try {
      final response = await ref.read(apiClientProvider).dio.get<List<dynamic>>(
        uri.replace(queryParameters: params).toString());
      if (response.data == null) throw const FormatException('Missing property response.');
      final page = response.data!.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      if (mounted && generation == searchGeneration) {
        setState(() {
          moreProperties.addAll(page);
          morePageFull = page.length == 50;
        });
      }
    } catch (e) {
      if (mounted && generation == searchGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted && generation == searchGeneration) setState(() => loadingMore = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Explore PGs'), actions: [
      IconButton(tooltip: 'Saved PGs', icon: const Icon(Icons.favorite_border),
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SavedPropertiesScreen()))),
    ]),
    body: AsyncView<List<Json>>(value: appliedPath == null ? ref.watch(propertiesProvider) : ref.watch(searchPropertiesProvider(appliedPath!)),
      retry: () { if (appliedPath == null) { ref.invalidate(propertiesProvider); } else { ref.invalidate(searchPropertiesProvider(appliedPath!)); } },
      builder: (properties) {
        final results = [...properties, ...moreProperties];
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              moreProperties.clear();
              morePageFull = true;
              loadingMore = false;
              searchGeneration++;
            });
            if (appliedPath == null) { ref.invalidate(propertiesProvider); await ref.read(propertiesProvider.future); }
            else { ref.invalidate(searchPropertiesProvider(appliedPath!)); await ref.read(searchPropertiesProvider(appliedPath!).future); }
          },
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppTheme.forest, borderRadius: BorderRadius.circular(22)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.wb_sunny_rounded, color: AppTheme.coral, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('MAKE YOURSELF AT HOME', style: TextStyle(color: Color(0xFFBCD9C7), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800))),
                ]),
                SizedBox(height: 12),
                Text('Find a place that\nfeels like you.', style: TextStyle(color: Colors.white, fontFamily: 'serif', fontSize: 29, height: 1.1)),
                SizedBox(height: 10),
                Text('Thoughtful spaces. Better living.', style: TextStyle(color: Color(0xFFD4E5D8))),
              ]),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: query,
              onSubmitted: (_) => applyFilters(),
              decoration: const InputDecoration(
                hintText: 'Search area, city or property', prefixIcon: Icon(Icons.search),
              ),
            ),
              ExpansionTile(title: const Text('Filters'), children: [
                TextField(controller: maxRent, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Maximum monthly rent (INR)')),
                SwitchListTile(title: const Text('Available beds only'), value: availableOnly,
                  onChanged: (value) => setState(() => availableOnly = value)),
                ref.watch(amenitiesProvider).when(
                  loading: () => const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
                  error: (error, stack) => TextButton(
                    onPressed: () => ref.invalidate(amenitiesProvider), child: const Text('Unable to load amenities. Retry')),
                  data: (items) => Column(children: [
                    for (final item in items) CheckboxListTile(
                      title: Text(item['name'] as String), value: selectedAmenities.contains(item['code']),
                      onChanged: (value) => setState(() {
                        if (value == true) { selectedAmenities.add(item['code'] as String); }
                        else { selectedAmenities.remove(item['code']); }
                      }),
                    ),
                  ]),
                ),
              ]),
              Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: applyFilters, child: const Text('Search'))),
            const SizedBox(height: 24),
            Text('Places to call home', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('Explore available spaces', style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 16),
            if (results.isEmpty)
              DesignPanel(color: AppTheme.paleGreen, child: Text(
                appliedPath == null ? 'No properties available yet.' : 'No places match your search.',
              )),
            for (final item in results) Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(clipBehavior: Clip.antiAlias, child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PropertyDetails(id: item['id'] as String))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PropertyPhoto(path: item['coverPhotoId'] == null ? null :
                    '/properties/${item['id']}/photos/${item['coverPhotoId']}'),
                  Padding(padding: const EdgeInsets.all(16), child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 5),
                      Text('${item['area']}, ${item['city']}', style: const TextStyle(color: AppTheme.muted)),
                      const SizedBox(height: 14),
                      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(item['startingRent'] == null ? 'No rooms' : '₹${item['startingRent']} / month',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        StatusBadge('${item['availableBeds']} beds available'),
                      ]),
                    ])),
                ]),
              )),
            ),
            if (properties.length == 50 && morePageFull && results.length <= 10000)
              TextButton(
                onPressed: loadingMore ? null : () => loadMore(results.length),
                child: Text(loadingMore ? 'Loading...' : 'Load more'),
              ),
          ]),
        );
      }),
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
  bool saving = false;
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
      final photos = (item['photos'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final amenities = (item['amenities'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final roomNames = {for (final room in rooms) room['id']: room['name']};
      return ListView(padding: const EdgeInsets.all(20), children: [
        if (photos.isEmpty)
          ClipRRect(borderRadius: BorderRadius.circular(20), child: const PropertyIllustration(height: 180))
        else
          SizedBox(height: 220, child: PageView.builder(
            itemCount: photos.length,
            itemBuilder: (_, index) => Padding(padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(borderRadius: BorderRadius.circular(20),
                child: PropertyPhoto(path: '/properties/${widget.id}/photos/${photos[index]['id']}', height: 220))),
          )),
        if (photos.length > 1)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Swipe to see ${photos.length} photos',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12))),
        const SizedBox(height: 20),
        Text(item['name'] as String, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('${item['address']}, ${item['area']}, ${item['city']}', style: const TextStyle(color: AppTheme.muted)),
        ref.watch(savedPropertiesProvider).when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => TextButton(
            onPressed: () => ref.invalidate(savedPropertiesProvider), child: const Text('Unable to load saved PGs. Retry')),
          data: (saved) {
            final isSaved = saved.any((property) => property['id'] == widget.id);
            return Align(alignment: Alignment.centerLeft, child: TextButton.icon(
              onPressed: saving ? null : () async {
                setState(() => saving = true);
                try {
                  final dio = ref.read(apiClientProvider).dio;
                  if (isSaved) { await dio.delete<void>('/customer/saved-properties/${widget.id}'); }
                  else { await dio.post<void>('/customer/saved-properties/${widget.id}'); }
                  ref.invalidate(savedPropertiesProvider);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
              icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border),
              label: Text(isSaved ? 'Remove from saved' : 'Save PG'),
            ));
          },
        ),
        const SizedBox(height: 20),
        Text('About this place', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), Text(item['description'] as String),
        if (amenities.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Amenities', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Wrap(spacing: 8, children: [for (final amenity in amenities) Chip(label: Text(amenity['name'] as String))]),
        ],
        const SizedBox(height: 24), Text('Available beds', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (beds.isEmpty) const Text('No beds available.'),
        for (final bed in beds) Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DesignPanel(padding: const EdgeInsets.all(12), child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Room ${roomNames[bed['roomId']] ?? bed['roomId']} · Bed ${bed['label']}'),
            trailing: FilledButton(onPressed: busy ? null : () => book(bed['id'] as String), child: const Text('Request')),
          )),
        ),
      ]);
    }));
}
