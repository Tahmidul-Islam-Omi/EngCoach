import 'package:flutter/material.dart';

/// Shown while the stored Firebase session is being restored.
///
/// Without it, a returning learner sees the sign-in screen flash before the
/// session resolves — which reads as "I've been signed out" every launch.
class StartingScreen extends StatelessWidget {
  const StartingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
