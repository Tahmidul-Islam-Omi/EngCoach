import 'package:flutter/material.dart';

void main() {
  runApp(const EngCoachApp());
}

/// Placeholder root widget.
///
/// Replaced in step 1 by `app/app.dart` (theme, router, ProviderScope).
class EngCoachApp extends StatelessWidget {
  const EngCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'EngCoach',
      home: Scaffold(
        body: Center(child: Text('EngCoach')),
      ),
    );
  }
}
