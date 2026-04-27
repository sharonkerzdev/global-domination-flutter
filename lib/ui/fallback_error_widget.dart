import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:global_domination/ui/theme/app_theme.dart';
import 'package:global_domination/ui/theme/spacing.dart';

class FallbackErrorWidget extends StatelessWidget {
  const FallbackErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme(),
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          return Scaffold(
            backgroundColor: cs.surface,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Something went wrong',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  SizedBox(height: Spacing.md),
                  FilledButton(
                    onPressed: SystemNavigator.pop,
                    child: const Text('Restart'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
