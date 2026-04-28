import 'package:flutter/material.dart';

import 'package:global_domination/ui/features/hud/global_hud.dart';
import 'package:global_domination/ui/features/achievements/achievements_screen.dart';
import 'package:global_domination/ui/features/leaders/leaders_screen.dart';
import 'package:global_domination/ui/features/map/map_screen.dart';
import 'package:global_domination/ui/features/minigames/minigames_screen.dart';
import 'package:global_domination/ui/features/upgrades/upgrades_screen.dart';

class _NavItem {
  const _NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

const List<_NavItem> _kBottomNavItems = [
  _NavItem(label: 'Map', icon: Icons.public),
  _NavItem(label: 'Upgrades', icon: Icons.trending_up),
  _NavItem(label: 'Leaders', icon: Icons.groups),
  _NavItem(label: 'Achievements', icon: Icons.emoji_events),
  _NavItem(label: 'Minigames', icon: Icons.sports_esports),
];

/// Primary game shell: fixed five-tab bottom navigation with [IndexedStack]
/// so tab bodies (including [MapScreen]) stay mounted.
class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const GlobalHud(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  MapScreen(),
                  UpgradesScreen(),
                  LeadersScreen(),
                  AchievementsScreen(),
                  MinigamesScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        items: [
          for (final item in _kBottomNavItems)
            BottomNavigationBarItem(icon: Icon(item.icon), label: item.label),
        ],
      ),
    );
  }
}
