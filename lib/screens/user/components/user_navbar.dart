import 'package:flutter/material.dart';

class UserNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const UserNavBar({
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
          icon: Icon(Icons.home_outlined, color: selectedIndex == 0 ? Colors.green : Colors.grey),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_outlined, color: selectedIndex == 1 ? Colors.green : Colors.grey),
          label: 'Search',
        ),
        NavigationDestination(
          icon: selectedIndex == 2
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.camera_alt_outlined, color: Colors.green, size: 32),
                )
              : Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 28),
          label: 'Detect',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_border, color: selectedIndex == 3 ? Colors.green : Colors.grey),
          label: 'Bookmarks',
        ),
        NavigationDestination(
          icon: Icon(Icons.photo_album_outlined, color: selectedIndex == 4 ? Colors.green : Colors.grey),
          label: 'Gallery',
        ),
      ],
    );
  }
}
