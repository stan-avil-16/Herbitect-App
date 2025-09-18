import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'admin/admin_login.dart';
import 'user/user_home.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleSelection extends StatefulWidget {
  const RoleSelection({super.key});

  @override
  RoleSelectionState createState() => RoleSelectionState();
}

class RoleSelectionState extends State<RoleSelection> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _reflectionAnimation;

  @override
  void initState() {
    super.initState();
    print('RoleSelection: initState called'); // Debug print

    // Animation Controller setup for continuous reflection movement
    _animationController = AnimationController(
      duration: const Duration(seconds: 3), // Duration of animation cycle
      vsync: this,
    )..repeat(reverse: true); // Continuous repeating animation

    // Animation for moving the reflection over the buttons
    _reflectionAnimation = Tween<Offset>(
      begin: Offset(0.0, -0.2),
      end: Offset(0.0, 0.2), // Reflection moves vertically
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    print('RoleSelection: dispose called'); // Debug print
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('RoleSelection: build called'); // Debug print
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/role.jpg',
            fit: BoxFit.cover,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    // Black stroke
                    Text(
                      'Choose Your Role',
                      style: GoogleFonts.montserrat(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.black,
                      ),
                    ),
                    // White fill with shadow
                    Text(
                      'Choose Your Role',
                      style: GoogleFonts.montserrat(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFAF9F6),
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black.withOpacity(0.4),
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRoleCard(
                      context: context,
                      icon: Icons.person,
                      label: 'User',
                      onTap: () {
                        print('RoleSelection: User button tapped'); // Debug print
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const UserHome()),
                        );
                      },
                      color: Colors.green.shade100,
                    ),
                    _buildRoleCard(
                      context: context,
                      icon: Icons.admin_panel_settings,
                      label: 'Admin',
                      onTap: () {
                        print('RoleSelection: Admin button tapped'); // Debug print
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
                        );
                      },
                      color: Colors.green.shade200,
                    ),
                  ],
                ),
                // Glass reflection animation over both buttons
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Positioned(
                      top: 200,
                      child: Opacity(
                        opacity: 0.3,  // Semi-transparent effect
                        child: Container(
                          width: 300,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),  // Glassy appearance
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.center,
                            child: Transform.translate(
                              offset: _reflectionAnimation.value,
                              child: Container(
                                width: 300,
                                height: 80,
                                color: Colors.white.withAlpha(15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(27, 94, 32, 0.3),  // Using RGBA values
              blurRadius: 12,
              spreadRadius: 2,
              offset: Offset(4, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Color(0xFF1B5E20)),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
      ).animate().scale(begin: const Offset(0.95, 0.95), end: Offset(1, 1), duration: 300.ms).shimmer(duration: 1.5.seconds),
    );
  }
}
