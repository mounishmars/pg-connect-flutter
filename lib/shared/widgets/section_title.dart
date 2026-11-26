import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final String? action;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
    if (action != null) Text(action!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
  ]);
}
