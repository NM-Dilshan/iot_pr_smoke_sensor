import 'package:flutter/material.dart';

enum MainDestination { home, history, settings }

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final MainDestination selected;
  final ValueChanged<MainDestination> onSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selected.index,
    onDestinationSelected: (index) => onSelected(MainDestination.values[index]),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(icon: Icon(Icons.history), label: 'History'),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        label: 'Settings',
      ),
    ],
  );
}
