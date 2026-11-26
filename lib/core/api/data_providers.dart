import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

typedef Json = Map<String, dynamic>;

final propertiesProvider = FutureProvider.autoDispose<List<Json>>((ref) => _list(ref, '/properties'));
final searchPropertiesProvider = FutureProvider.autoDispose.family<List<Json>, String>(
  (ref, path) => _list(ref, path));
final amenitiesProvider = FutureProvider.autoDispose<List<Json>>((ref) => _list(ref, '/amenities'));
final savedPropertiesProvider = FutureProvider.autoDispose<List<Json>>((ref) => _list(ref, '/customer/saved-properties'));
final bookingsProvider = FutureProvider.autoDispose<List<Json>>((ref) => _list(ref, '/customer/bookings'));
final invoicesProvider = FutureProvider.autoDispose<List<Json>>((ref) => _list(ref, '/customer/invoices'));
final ownerPropertiesProvider = FutureProvider.autoDispose<List<Json>>((ref) => _list(ref, '/owner/properties'));
final ownerBookingsProvider = FutureProvider.autoDispose<List<Json>>((ref) => _list(ref, '/owner/bookings'));
final ownerInvoicesProvider = FutureProvider.autoDispose<List<Json>>((ref) => _list(ref, '/owner/invoices'));
final inventoryProvider = FutureProvider.autoDispose.family<List<Json>, String>(
  (ref, propertyId) => _list(ref, '/owner/properties/$propertyId/rooms'));
final ownerPhotosProvider = FutureProvider.autoDispose.family<List<Json>, String>(
  (ref, propertyId) => _list(ref, '/owner/properties/$propertyId/photos'));
final photoBytesProvider = FutureProvider.autoDispose.family<Uint8List, String>((ref, path) async {
  final response = await ref.read(apiClientProvider).dio.get<List<int>>(path,
    options: Options(responseType: ResponseType.bytes));
  if (response.data == null) throw const FormatException('Missing photo data.');
  return Uint8List.fromList(response.data!);
});
final dashboardProvider = FutureProvider.autoDispose<Json>((ref) async {
  final response = await ref.read(apiClientProvider).dio.get<Json>('/owner/dashboard');
  if (response.data == null) throw const FormatException('Missing dashboard response.');
  return response.data!;
});

Future<List<Json>> _list(Ref ref, String path) async {
  final response = await ref.read(apiClientProvider).dio.get<List<dynamic>>(path);
  if (response.data == null) throw const FormatException('Missing list response.');
  return response.data!.map((item) => Map<String, dynamic>.from(item as Map)).toList();
}
