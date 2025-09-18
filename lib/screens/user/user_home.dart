import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'components/user_navbar.dart';
import 'pages/dashboard.dart';
import 'pages/detect.dart';
import 'pages/search.dart';
import 'pages/bookmarks.dart';
import 'pages/gallery.dart';  // Add gallery if you plan to include it
import 'components/user_profile_popup_content.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  List<Widget> get _pages => [
    DashboardPage(onGoToBookmarks: () => _onItemTapped(3)),
    const SearchPage(),
    const DetectPage(),
    const BookmarksPage(),
    const GalleryPage(),
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    // No sign out on pause or detach. Let Firebase handle session persistence.
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> _onWillPop() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // User is logged in, ask confirmation
      bool shouldLogout = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Exit'),
          content: const Text('You are logged in. Do you want to logout and exit Herbitect?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Stay
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Logout and exit
              child: const Text('Yes'),
            ),
          ],
        ),
      );

      if (shouldLogout) {
        await FirebaseAuth.instance.signOut();
        return true; // Exit
      } else {
        return false; // Stay
      }
    } else {
      return true; // No login, just exit
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          bool shouldExit = await _onWillPop();
          if (!mounted) return; // ⬅️ immediately after await
          if (shouldExit) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2E7D32),
                  const Color(0xFF388E3C),
                  const Color(0xFF4CAF50),
                  const Color(0xFF66BB6A),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // App Logo and Title
                    Expanded(
                      child: Row(
                        children: [
                          // Animated Logo Container
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.eco,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // App Title with enhanced styling
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Herbitect',
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Discover Nature\'s Medicine',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Profile Button with enhanced design
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            showUserProfilePopup(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: UserNavBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }

  void showUserProfilePopup(BuildContext rootContext) {
    final overlay = Overlay.of(rootContext);
    final double topPadding = MediaQuery.of(rootContext).padding.top;

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            entry?.remove();
          },
          child: Stack(
            children: [
              Positioned(
                top: 100 + topPadding + 8,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: UserProfilePopupContent(
                    onClose: () {
                      entry?.remove();
                    },
                    onRequestLogout: () async {
                      entry?.remove();
                      await Future.delayed(const Duration(milliseconds: 100));
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        bool shouldLogout = await showDialog(
                          context: rootContext,
                          useRootNavigator: true,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Exit'),
                            content: const Text('You are logged in. Do you want to logout and exit Herbitect?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
                                child: const Text('No'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
                                child: const Text('Yes'),
                              ),
                            ],
                          ),
                        );
                        if (shouldLogout == true) {
                          showDialog(
                            context: rootContext,
                            useRootNavigator: true,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                          await FirebaseAuth.instance.signOut();
                          await Future.delayed(const Duration(milliseconds: 700));
                          Navigator.of(rootContext, rootNavigator: true).pop(); // Remove loading
                          Navigator.of(rootContext, rootNavigator: true).popUntil((route) => route.isFirst);
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    overlay.insert(entry);
  }
}
