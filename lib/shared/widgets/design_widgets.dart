import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/data_providers.dart';
import '../../core/theme/app_theme.dart';

class DesignPanel extends StatelessWidget {
  const DesignPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = Colors.white});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.border),
    ),
    child: child,
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final positive = status == 'PAID' || status == 'APPROVED' || status == 'ACTIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: positive ? AppTheme.paleGreen : const Color(0xFFFFF1E5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(
        color: positive ? AppTheme.green : const Color(0xFF95633D),
        fontSize: 10, fontWeight: FontWeight.w800,
      )),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: DesignPanel(color: AppTheme.paleGreen, child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 36, color: AppTheme.green),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted)),
      ],
    )),
  ));
}

class PropertyIllustration extends StatelessWidget {
  const PropertyIllustration({super.key, this.height = 140});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: const BoxDecoration(
      color: Color(0xFFDFEBDD),
      borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
    ),
    child: Center(child: Icon(Icons.home_work_rounded, size: height * .48, color: const Color(0xFF8DAE98))),
  );
}

class PropertyPhoto extends ConsumerWidget {
  const PropertyPhoto({super.key, required this.path, this.height = 140});
  final String? path;
  final double height;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (path == null) return PropertyIllustration(height: height);
    final photo = ref.watch(photoBytesProvider(path!));
    return SizedBox(height: height, width: double.infinity, child: photo.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.broken_image_outlined), Text('Photo unavailable'),
      ])),
      data: (bytes) => Image.memory(bytes, fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => const Center(child: Text('Photo unavailable'))),
    ));
  }
}
