import 'package:flutter/material.dart';

class AdminNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const AdminNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onItemTapped,
      backgroundColor: Colors.white,
      indicatorColor: Colors.green.shade100,
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined, color: selectedIndex == 0 ? Colors.green : Colors.grey),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_florist_outlined, color: selectedIndex == 1 ? Colors.green : Colors.grey),
          label: 'Manage Plants',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_alt_outlined, color: selectedIndex == 2 ? Colors.green : Colors.grey),
          label: 'Manage Users',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined, color: selectedIndex == 3 ? Colors.green : Colors.grey),
          label: 'Explore Content',
        ),
        NavigationDestination(
          icon: Icon(Icons.feedback_outlined, color: selectedIndex == 4 ? Colors.green : Colors.grey),
          label: 'Feedback',
        ),
      ],
    );
  }
}
