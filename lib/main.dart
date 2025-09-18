import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/user/login_page.dart';
import 'screens/user/signup_pg.dart';
import 'screens/user/user_home.dart';
import 'screens/user/pages/dashboard.dart';
import 'screens/user/pages/detect.dart';
import 'screens/user/pages/search.dart';
import 'screens/user/pages/bookmarks.dart';
import 'screens/admin/admin_login.dart';
import 'screens/admin/admin_home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  print('App: Starting main function'); // Debug print
  WidgetsFlutterBinding.ensureInitialized();
  print('App: Flutter binding initialized'); // Debug print
  
  // Set system UI overlay style immediately to prevent black screen
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  
  // Initialize Firebase
  print('App: Initializing Firebase'); // Debug print
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('App: Firebase initialized successfully'); // Debug print
  } catch (e) {
    print('App: Firebase already initialized or error: $e'); // Debug print
    // If Firebase is already initialized, we can continue
  }
  
  // Force logout on every app start
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('App: User detected on start, signing out...');
      await FirebaseAuth.instance.signOut();
      print('App: User signed out on start.');
    }
  } catch (e) {
    print('App: Error during forced sign out: $e');
  }
  
  print('App: Running HerbalIApp'); // Debug print
  runApp(const HerbalIApp());
}

class HerbalIApp extends StatelessWidget {
  const HerbalIApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('App: HerbalIApp build called'); // Debug print
    return MaterialApp(
      title: 'Herbitect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFE8F5E9), // Light green background
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/signup_pg': (context) => SignupPage(),
        '/home': (context) => const UserHome(),
        '/dashboard': (context) => const DashboardPage(),
        '/detect': (context) => const DetectPage(),
        '/search': (context) => const SearchPage(),
        '/bookmarks': (context) => const BookmarksPage(),
        '/adminLogin': (context) => AdminLoginScreen(),
        '/adminHome': (context) => AdminHomePage(),
      },
    );
  }
}
