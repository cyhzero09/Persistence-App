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
        NavigationDestination(icon: Icon(Icons.timeline), label: '時間軸'),
        NavigationDestination(icon: Icon(Icons.book), label: '日記'),
        NavigationDestination(icon: Icon(Icons.notifications), label: '提醒'),
        NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
      ],
    );
  }
}
