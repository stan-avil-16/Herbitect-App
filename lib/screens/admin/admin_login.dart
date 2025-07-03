import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_home.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = _auth.currentUser!.uid;
      final snapshot = await FirebaseDatabase.instance.ref('users/$uid').get();
      final role = snapshot.child('role').value;
      if (role == 'admin') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Successful!')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminHomePage()),
        );
      } else {
        await _auth.signOut();
        setState(() {
          _errorMessage = 'You are not authorized as admin.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),  // Light and neat
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user,
                size: 80,
                color: Color(0xFF2E7D32),  // Deep green
              ),
              const SizedBox(height: 20),
              const Text(
                'Admin Login',
                style: TextStyle(
                  fontSize: 26,
                  color: Color(0xFF1B5E20),  // Natural green
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: Colors.white,  // Lightest green hint
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _loading
                  ? const CircularProgressIndicator(color: Color(0xFF1B5E20))
                  : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF66BB6A),  // Fresh light green
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                  ),
                  onPressed: _login,
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
