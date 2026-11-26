import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/data_providers.dart';
import '../../shared/widgets/async_view.dart';

String? requiredText(String? value, int maxLength) {
  if (value == null || value.trim().isEmpty) return 'This field is required.';
  if (value.trim().length > maxLength) return 'Maximum $maxLength characters.';
  return null;
}

String? validAmount(String? value) {
  final text = value?.trim() ?? '';
  if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(text) ||
      (double.tryParse(text) ?? 0) <= 0) {
    return 'Enter a positive amount with up to 2 decimal places.';
  }
  return null;
}

class PropertyForm extends ConsumerStatefulWidget {
  const PropertyForm({super.key, this.property});
  final Json? property;
  @override
  ConsumerState<PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends ConsumerState<PropertyForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, description, address, area, city;
  late bool active;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final p = widget.property;
    name = TextEditingController(text: p?['name'] as String?);
    description = TextEditingController(text: p?['description'] as String?);
    address = TextEditingController(text: p?['address'] as String?);
    area = TextEditingController(text: p?['area'] as String?);
    city = TextEditingController(text: p?['city'] as String?);
    active = p?['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    for (final controller in [name, description, address, area, city]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() { busy = true; error = null; });
    final body = {'name': name.text.trim(), 'description': description.text.trim(),
      'address': address.text.trim(), 'area': area.text.trim(), 'city': city.text.trim(), 'active': active};
    try {
      final dio = ref.read(apiClientProvider).dio;
      if (widget.property == null) {
        await dio.post<Json>('/owner/properties', data: body);
      } else {
        await dio.put<void>('/owner/properties/${widget.property!['id']}', data: body);
      }
      ref.invalidate(ownerPropertiesProvider);
      ref.invalidate(propertiesProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = '${apiError(e)} Check your properties before retrying.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.property == null ? 'Add property' : 'Edit property')),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.all(20), children: [
      TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Property name'),
        validator: (v) => requiredText(v, 150)),
      TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Description'),
        maxLength: 5000, maxLines: 3),
      TextFormField(controller: address, decoration: const InputDecoration(labelText: 'Address'),
        validator: (v) => requiredText(v, 1000)),
      TextFormField(controller: area, decoration: const InputDecoration(labelText: 'Area'),
        validator: (v) => requiredText(v, 150)),
      TextFormField(controller: city, decoration: const InputDecoration(labelText: 'City'),
        validator: (v) => requiredText(v, 150)),
      SwitchListTile(title: const Text('Visible to customers'), value: active,
        onChanged: busy ? null : (value) => setState(() => active = value)),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Saving...' : 'Save property')),
    ])));
}

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key, required this.property});
  final Json property;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = property['id'] as String;
    final inventory = ref.watch(inventoryProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text(property['name'] as String), actions: [
        IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit property', onPressed: () async {
          final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => PropertyForm(property: property)));
          if (changed == true && context.mounted) Navigator.of(context).pop();
        }),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(context: context,
          builder: (_) => InventoryForm(propertyId: id)),
        icon: const Icon(Icons.add), label: const Text('Add room')),
      body: AsyncView<List<Json>>(value: inventory, retry: () => ref.invalidate(inventoryProvider(id)),
        builder: (rows) {
          final rooms = <String, List<Json>>{};
          for (final row in rows) {
            rooms.putIfAbsent(row['id'] as String, () => []).add(row);
          }
          if (rooms.isEmpty) return const Center(child: Text('No rooms yet. Add a room to get started.'));
          return ListView(padding: const EdgeInsets.only(bottom: 88), children: [
            for (final room in rooms.values) Card(child: Column(children: [
              ListTile(title: Text('Room ${room.first['name']}'),
                subtitle: Text('₹${room.first['monthlyRent']} / month · ${room.first['active'] == true ? 'Active' : 'Inactive'}'),
                trailing: IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit room',
                  onPressed: () => showDialog<void>(context: context,
                    builder: (_) => InventoryForm(propertyId: id, room: room.first)))),
              for (final bed in room.where((row) => row['bedId'] != null))
                ListTile(title: Text('Bed ${bed['bedLabel']}'),
                  subtitle: Text(bed['bedActive'] == true ? 'Active' : 'Inactive'),
                  trailing: IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit bed',
                    onPressed: () => showDialog<void>(context: context,
                      builder: (_) => InventoryForm(propertyId: id, room: room.first, bed: bed)))),
              TextButton.icon(icon: const Icon(Icons.add), label: const Text('Add bed'),
                onPressed: () => showDialog<void>(context: context,
                  builder: (_) => InventoryForm(propertyId: id, room: room.first, addingBed: true))),
            ])),
          ]);
        }),
    );
  }
}

class InventoryForm extends ConsumerStatefulWidget {
  const InventoryForm({super.key, required this.propertyId, this.room, this.bed, this.addingBed = false});
  final String propertyId;
  final Json? room;
  final Json? bed;
  final bool addingBed;
  @override
  ConsumerState<InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends ConsumerState<InventoryForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, amount;
  late bool active;
  bool busy = false;
  String? error;
  bool get isBed => widget.addingBed || widget.bed != null;
  bool get editing => isBed ? widget.bed != null : widget.room != null;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: (isBed ? (widget.bed?['bedLabel']) : (widget.room?['name'])) as String?);
    amount = TextEditingController(text: widget.room?['monthlyRent']?.toString());
    active = (isBed ? (widget.bed?['bedActive']) : (widget.room?['active'])) as bool? ?? true;
  }
  @override
  void dispose() { name.dispose(); amount.dispose(); super.dispose(); }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() { busy = true; error = null; });
    final dio = ref.read(apiClientProvider).dio;
    try {
      if (isBed) {
        if (editing) {
          await dio.put<void>('/owner/beds/${widget.bed!['bedId']}', data: {'label': name.text.trim(), 'active': active});
        } else {
          await dio.post<Json>('/owner/rooms/${widget.room!['id']}/beds', data: {'label': name.text.trim()});
        }
      } else if (editing) {
        await dio.put<void>('/owner/rooms/${widget.room!['id']}',
          data: {'name': name.text.trim(), 'monthlyRent': amount.text.trim(), 'active': active});
      } else {
        await dio.post<Json>('/owner/properties/${widget.propertyId}/rooms',
          data: {'name': name.text.trim(), 'monthlyRent': amount.text.trim()});
      }
      ref.invalidate(inventoryProvider(widget.propertyId));
      ref.invalidate(propertiesProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => error = '${apiError(e)} Check the inventory before retrying.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${editing ? 'Edit' : 'Add'} ${isBed ? 'bed' : 'room'}'),
    content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: name, decoration: InputDecoration(labelText: isBed ? 'Bed label' : 'Room name'),
        validator: (value) => requiredText(value, 100)),
      if (!isBed) TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Monthly rent (INR)'), validator: validAmount),
      if (editing) SwitchListTile(title: const Text('Active'), value: active,
        onChanged: busy ? null : (value) => setState(() => active = value)),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
    ]))),
    actions: [
      TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Saving...' : 'Save')),
    ]);
}
