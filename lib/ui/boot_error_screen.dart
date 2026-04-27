import 'package:flutter/material.dart';

import 'package:global_domination/ui/theme/app_theme.dart';
import 'package:global_domination/ui/theme/spacing.dart';

class BootErrorScreen extends StatelessWidget {
  final String message;

  const BootErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme(),
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          final tt = theme.textTheme;
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: cs.error),
                    SizedBox(height: Spacing.lg),
                    Text(
                      'Failed to Load Game Data',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: Spacing.md),
                    Text(
                      message,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: Spacing.lg),
                    Text(
                      'Please reinstall the app to restore game data.',
                      style: tt.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
