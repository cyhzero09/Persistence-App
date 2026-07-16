import 'package:flutter/material.dart';

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
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.today), label: '首頁'),
        NavigationDestination(icon: Icon(Icons.dashboard), label: '內容'),
        NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
      ],
    );
  }
}
