import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Stand-in for a screen that hasn't been built yet.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, required this.note, super.key});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(note, style: text.bodySmall, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
