import 'package:flutter/material.dart';
import 'admin_navbar.dart';
import 'pages/dashboard.dart';
import 'pages/manage_plants.dart';
import 'pages/manage_users.dart';
import 'pages/manage_explore.dart';
import 'pages/manage_feedback.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class _AdminHomePageState extends State<AdminHomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    DashboardPage(
      onTileTap: (int index) {
        // This will be replaced in build with the correct setState
      },
    ),
    ManagePlantsPage(),
    ManageUsersPage(),
    ManageExplorePage(),
    ManageFeedbackPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check if user is admin
        final ref = FirebaseDatabase.instance.ref('users/${user.uid}/role');
        final snap = await ref.get();
        final role = snap.value?.toString();
        if (role == 'admin') {
          await FirebaseAuth.instance.signOut();
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Fix: Adjusted to return Future<bool> to match PopInvokedWithResultCallback
  Future<bool> _onPopInvokedWithResult(dynamic result) async {
    if (result == true) {
      bool shouldLogout = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout Confirmation'),
          content: const Text('Do you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );

      if (!mounted) return false;  // Ensure widget is still mounted

      if (shouldLogout == true) {
        await FirebaseAuth.instance.signOut();
        Navigator.popUntil(context, (route) => route.isFirst);
      }

      return false;  // Prevent closing the screen unless confirmed
    }
    return true; // Default to allow pop
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the _pages list to inject the correct callback
    final List<Widget> pages = <Widget>[
      DashboardPage(
        onTileTap: (int index) {
          setState(() {
            if (index == 3 || index == 4) {
              _selectedIndex = 3; // ManageExplorePage index
              // Use a global or static variable to communicate tab type if needed
              ManageExplorePage.initialTab = (index == 3) ? 'spotlight' : 'explore';
            } else {
              _selectedIndex = index;
            }
          });
        },
      ),
      ManagePlantsPage(),
      ManageUsersPage(),
      ManageExplorePage(),
      ManageFeedbackPage(),
    ];
    return WillPopScope(
      onWillPop: () async {
        bool result = await _onPopInvokedWithResult(true);
        return result;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFE8F5E9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF66BB6A),
          title: Stack(
            children: [
              Text(
                'Admin Panel',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..color = Colors.black,
                ),
              ),
              Text(
                'Admin Panel',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          centerTitle: true,
          elevation: 2,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: Icon(Icons.logout, color: Colors.green.shade800),
                onPressed: () async {
                  bool shouldLogout = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout Confirmation'),
                      content: const Text('Do you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Yes'),
                        ),
                      ],
                    ),
                  );

                  if (!mounted) return;
                  if (shouldLogout == true) {
                    await FirebaseAuth.instance.signOut();
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                },
              ),
            )
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: AdminNavBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}
