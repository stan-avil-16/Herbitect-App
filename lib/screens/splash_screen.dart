import 'package:flutter/material.dart';
import 'role_selection.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    print('SplashScreen: initState called'); // Debug print

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    print('SplashScreen: Starting splash sequence'); // Debug print
    await Future.delayed(const Duration(seconds: 2)); // Show splash animation first

    if (!mounted) {
      print('SplashScreen: Widget not mounted, returning'); // Debug print
      return;
    }

    print('SplashScreen: Navigating to RoleSelection'); // Debug print
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelection()),
    );
  }

  @override
  void dispose() {
    print('SplashScreen: dispose called'); // Debug print
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('SplashScreen: build called'); // Debug print
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: 200 * _animation.value,
              height: 200 * _animation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0x80A5D6A7),
                    Color(0xFFE8F5E9),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withAlpha(77),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset('assets/logo.png', fit: BoxFit.cover),
              ),
            );
          },
        ),
      ),
    );
  }
}
