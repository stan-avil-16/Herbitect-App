import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../user_home.dart';

typedef VoidCallback = void Function();

typedef LogoutCallback = void Function();

class UserProfilePopupContent extends StatelessWidget {
  final VoidCallback? onClose;
  final LogoutCallback? onRequestLogout;
  const UserProfilePopupContent({super.key, this.onClose, this.onRequestLogout});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              user != null
                  ? Column(
                      children: [
                        const Icon(Icons.person, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          user.displayName?.isNotEmpty == true
                              ? user.displayName!
                              : (user.phoneNumber ?? user.email ?? 'User'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green.shade700,
                            minimumSize: const Size(140, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (onRequestLogout != null) onRequestLogout!();
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const Text(
                          "Welcome!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Please login or sign up to personalize your Herbal-i experience.",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green.shade700,
                            minimumSize: const Size(140, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (onClose != null) onClose!();
                            Navigator.pushNamed(context, '/login');
                          },
                          icon: const Icon(Icons.login),
                          label: const Text("Login / Sign Up"),
                        ),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }
} 