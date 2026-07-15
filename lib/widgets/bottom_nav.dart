import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '首頁'),
        BottomNavigationBarItem(icon: Icon(Icons.timeline), label: '時間軸'),
        BottomNavigationBarItem(icon: Icon(Icons.book), label: '日記'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '提醒'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
      ],
    );
  }
}
