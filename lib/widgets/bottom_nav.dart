import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: [
        NavigationDestination(icon: const Icon(Icons.today), label: l10n.navHome),
        NavigationDestination(icon: const Icon(Icons.dashboard), label: l10n.navContent),
        NavigationDestination(icon: const Icon(Icons.settings), label: l10n.navSettings),
      ],
    );
  }
}
