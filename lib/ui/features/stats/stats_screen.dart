import 'package:flutter/material.dart';

/// Placeholder route surface; Story 7.5 replaces body with real stats.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: const SizedBox.shrink(),
    );
  }
}
