import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_home.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  final int? redirectToPlantId;
  final double? confidence;
  final String? label;
  final String? pendingAction;
  const LoginPage({super.key, this.redirectToPlantId, this.confidence, this.label, this.pendingAction});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (widget.redirectToPlantId != null) {
          Navigator.pop(context, {
            'redirectToPlantId': widget.redirectToPlantId,
            'confidence': widget.confidence,
            'label': widget.label,
            'pendingAction': widget.pendingAction,
          });
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserHome()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email. Please check or sign up.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid. Please check and try again.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        default:
          message = 'Login failed. Please check your credentials and try again.';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPasswordDialog() async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController otpController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool emailChecked = false;
    bool emailExists = false;
    bool otpSent = false;
    bool isLoading = false;
    String? errorText;
    String? successText;
    String remoteServer = "https://herbitect.onrender.com";

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> checkEmail() async {
              setState(() { isLoading = true; errorText = null; successText = null; });
              final response = await http.post(
                Uri.parse('$remoteServer/check-email'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'email': emailController.text.trim()}),
              );
              final body = jsonDecode(response.body);
              if (response.statusCode == 200 && body['exists'] == true) {
                setState(() { emailChecked = true; emailExists = true; errorText = null; });
              } else {
                setState(() { emailChecked = true; emailExists = false; errorText = 'Email does not exist.'; });
              }
              setState(() { isLoading = false; });
            }

            Future<void> sendOtp() async {
              setState(() { isLoading = true; errorText = null; successText = null; });
              final response = await http.post(
                Uri.parse('$remoteServer/send-otp'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'email': emailController.text.trim()}),
              );
              if (response.statusCode == 200) {
                setState(() { otpSent = true; errorText = null; successText = 'OTP sent to your email.'; });
              } else {
                setState(() { errorText = 'Failed to send OTP.'; });
              }
              setState(() { isLoading = false; });
            }

            Future<void> resetPassword() async {
              setState(() { isLoading = true; errorText = null; successText = null; });
              try {
                final response = await http.post(
                  Uri.parse('$remoteServer/reset-password'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'email': emailController.text.trim(),
                    'otp': otpController.text.trim(),
                    'new_password': newPasswordController.text.trim(),
                  }),
                );
                final body = jsonDecode(response.body);
                if (response.statusCode == 200 && body['success'] == true) {
                  setState(() { successText = 'Password reset successful!'; });
                  await Future.delayed(const Duration(seconds: 1));
                  Navigator.of(context).pop();
                } else {
                  setState(() { errorText = body['error'] ?? 'Failed to reset password. Try again.'; });
      }
    } catch (e) {
                setState(() { errorText = 'Failed to reset password. Try again.'; });
              }
              setState(() { isLoading = false; });
            }

            bool isPasswordValid = newPasswordController.text.length >= 6;
            bool doPasswordsMatch = newPasswordController.text == confirmPasswordController.text && confirmPasswordController.text.isNotEmpty;
            bool canSendOtp = emailChecked && emailExists && !otpSent;
            bool canReset = otpSent && otpController.text.length == 6 && isPasswordValid && doPasswordsMatch;

            OutlineInputBorder greenBorder = OutlineInputBorder(borderSide: BorderSide(color: Colors.green, width: 2));
            OutlineInputBorder redBorder = OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2));
            OutlineInputBorder defaultBorder = const OutlineInputBorder();

            return AlertDialog(
              title: const Text('Forgot Password'),
              content: SizedBox(
                width: 350,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: emailController,
                        enabled: !emailChecked,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: const OutlineInputBorder(),
                          suffixIcon: emailChecked
                            ? (emailExists ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.error, color: Colors.red))
                            : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!emailChecked)
                        ElevatedButton(
                          onPressed: isLoading ? null : checkEmail,
                          child: isLoading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Check Email'),
                        ),
                      if (emailChecked && emailExists && !otpSent)
                        ElevatedButton(
                          onPressed: isLoading ? null : sendOtp,
                          child: isLoading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send OTP'),
                        ),
                      if (otpSent) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Enter OTP',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: newPasswordController,
                          obscureText: true,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            border: defaultBorder,
                            enabledBorder: isPasswordValid ? greenBorder : (newPasswordController.text.isNotEmpty ? redBorder : defaultBorder),
                            focusedBorder: isPasswordValid ? greenBorder : (newPasswordController.text.isNotEmpty ? redBorder : defaultBorder),
                            suffixIcon: isPasswordValid ? const Icon(Icons.check, color: Colors.green) : (newPasswordController.text.isNotEmpty ? const Icon(Icons.error, color: Colors.red) : null),
                          ),
                        ),
                        if (newPasswordController.text.isNotEmpty && !isPasswordValid)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Password must be at least 6 characters.', style: TextStyle(color: Colors.red)),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            border: defaultBorder,
                            enabledBorder: doPasswordsMatch && isPasswordValid ? greenBorder : (confirmPasswordController.text.isNotEmpty ? redBorder : defaultBorder),
                            focusedBorder: doPasswordsMatch && isPasswordValid ? greenBorder : (confirmPasswordController.text.isNotEmpty ? redBorder : defaultBorder),
                            suffixIcon: doPasswordsMatch && isPasswordValid ? const Icon(Icons.check, color: Colors.green) : (confirmPasswordController.text.isNotEmpty ? const Icon(Icons.error, color: Colors.red) : null),
                          ),
                        ),
                        if (confirmPasswordController.text.isNotEmpty && !doPasswordsMatch)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Passwords do not match.', style: TextStyle(color: Colors.red)),
                          ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: canReset && !isLoading ? resetPassword : null,
                          child: isLoading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Reset Password'),
                        ),
                      ],
                      if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(errorText!, style: const TextStyle(color: Colors.red)),
                        ),
                      if (successText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(successText!, style: const TextStyle(color: Colors.green)),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserHome()),
        );
        return false;
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
          title: const Text(
            "Login",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        centerTitle: true,
        backgroundColor: const Color(0xFF66BB6A),
          iconTheme: const IconThemeData(color: Colors.white),
      ),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
        padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                      labelText: 'Email',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPasswordDialog,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _login,
                      icon: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                          : const Icon(Icons.login),
                      label: const Text('Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/signup_pg'),
                      child: const Text("New User? Sign Up"),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
