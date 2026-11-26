import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, required this.retry});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => value.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(apiError(error), textAlign: TextAlign.center),
      TextButton(onPressed: retry, child: const Text('Retry')),
    ])),
    data: builder,
  );
}
