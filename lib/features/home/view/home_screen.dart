import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        title: 'Home',
        note: 'Today’s Review, Continue Learning and Weak Areas land here.',
      );
}
