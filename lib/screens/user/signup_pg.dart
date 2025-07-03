import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pinput/pinput.dart';
import 'user_home.dart';

class SignupPage extends StatefulWidget {
  final int? redirectToPlantId;
  final double? confidence;
  final String? label;
  final String? pendingAction;

  const SignupPage({
    Key? key,
    this.redirectToPlantId,
    this.confidence,
    this.label,
    this.pendingAction,
  }) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _showOtpInput = false;
  bool _isSendingOtp = false;
  bool _isRegistering = false;
  
  final String _remoteServer = "https://herbitect.onrender.com";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  String? _errorMessage;

  bool get _isFormValid {
    return _nameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text.length >= 6 &&
        _passwordController.text == _confirmPasswordController.text;
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // 1. Check if email exists on our backend, then send OTP
  Future<void> _sendOTP() async {
    if (!_isFormValid) {
      _showSnackBar('Please fill all fields correctly.');
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      // Step 1: Check if email exists
      final checkEmailResponse = await http.post(
        Uri.parse('$_remoteServer/check-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      final checkEmailBody = jsonDecode(checkEmailResponse.body);
      if (checkEmailResponse.statusCode != 200 || checkEmailBody['exists'] == null) {
          throw Exception('Failed to check email. Server returned an error.');
      }

      if (checkEmailBody['exists']) {
        _showSnackBar('This email is already registered.');
        setState(() => _isSendingOtp = false);
        return;
      }

      // Step 2: Send OTP if email does not exist
      final sendOtpResponse = await http.post(
        Uri.parse('$_remoteServer/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      if (sendOtpResponse.statusCode == 200) {
        _showSnackBar('OTP sent to your email.');
        setState(() {
          _showOtpInput = true;
        });
      } else {
        throw Exception('Failed to send OTP.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: ${e.toString()}');
    } finally {
      setState(() {
        _isSendingOtp = false;
      });
    }
  }

  // 2. Verify OTP via backend, then create user in Firebase Auth & Realtime Database
  Future<void> _verifyOtpAndRegister() async {
    if (_otpController.text.trim().isEmpty || _otpController.text.trim().length != 6) {
      _showSnackBar('Please enter a valid 6-digit OTP.');
      return;
    }
    
    setState(() {
      _isRegistering = true;
    });

    try {
       // Step 1: Verify OTP with our backend
      final verifyResponse = await http.post(
        Uri.parse('$_remoteServer/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'otp': _otpController.text.trim(),
        }),
      );

      final verifyBody = jsonDecode(verifyResponse.body);
      if (verifyResponse.statusCode != 200 || !verifyBody['success']) {
        throw Exception('Invalid OTP. Please try again.');
      }

      // Step 2: Create user with email and password in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create user account.');
      }

      // Step 3: Save user's name and email to Realtime Database
      DatabaseReference ref = _database.ref('users/${user.uid}');
      await ref.set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'user',
        'timestamp': DateTime.now().toIso8601String(),
      });

      _showSnackBar('Registration Successful!');
      if (mounted) {
         Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserHome()),
        );
      }

    } on FirebaseAuthException catch (e) {
      _showSnackBar('Firebase Auth Error: ${e.message}');
    } 
    catch (e) {
      _showSnackBar('An error occurred: ${e.toString()}');
    } finally {
       if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  Future<void> _onSignupSuccess() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (widget.redirectToPlantId != null) {
      Navigator.pop(context, {
        'redirectToPlantId': widget.redirectToPlantId,
        'confidence': widget.confidence,
        'label': widget.label,
        'pendingAction': widget.pendingAction,
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFormFieldChanged);
    _emailController.addListener(_onFormFieldChanged);
    _passwordController.addListener(_onFormFieldChanged);
    _confirmPasswordController.addListener(_onFormFieldChanged);
  }

  void _onFormFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signupWithEmailPassword(String email, String password) async {
    setState(() {
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      await _onSignupSuccess();
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered. Please use another email or log in.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid. Please check and try again.';
          break;
        case 'weak-password':
          message = 'The password is too weak. Please use a stronger password.';
          break;
        default:
          message = 'Signup failed. Please check your details and try again.';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPasswordValid = _passwordController.text.length >= 6;
    final bool doPasswordsMatch = _passwordController.text == _confirmPasswordController.text && _confirmPasswordController.text.isNotEmpty;
    final bool showPasswordError = _passwordController.text.isNotEmpty && !isPasswordValid;
    final bool showConfirmError = _confirmPasswordController.text.isNotEmpty && !doPasswordsMatch;
    final bool showConfirmSuccess = _confirmPasswordController.text.isNotEmpty && doPasswordsMatch && isPasswordValid;

    OutlineInputBorder greenBorder = OutlineInputBorder(borderSide: BorderSide(color: Colors.green, width: 2));
    OutlineInputBorder redBorder = OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2));
    OutlineInputBorder defaultBorder = OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign Up',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF66BB6A),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: defaultBorder,
                    enabled: !_showOtpInput,
                  ),
                  readOnly: _showOtpInput,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: defaultBorder,
                     enabled: !_showOtpInput,
                  ),
                   readOnly: _showOtpInput,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password (min. 6 characters)',
                    border: defaultBorder,
                    enabled: !_showOtpInput,
                    suffixIcon: isPasswordValid ? const Icon(Icons.check, color: Colors.green) : null,
                    focusedBorder: isPasswordValid ? greenBorder : (showPasswordError ? redBorder : null),
                    enabledBorder: isPasswordValid ? greenBorder : (showPasswordError ? redBorder : defaultBorder),
                  ),
                  obscureText: true,
                  readOnly: _showOtpInput,
                ),
                if (showPasswordError)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 4, left: 4),
                      child: Text('Password should be at least 6 characters', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: defaultBorder,
                    enabled: !_showOtpInput,
                    suffixIcon: showConfirmSuccess ? const Icon(Icons.check, color: Colors.green) : (showConfirmError ? const Icon(Icons.error, color: Colors.red) : null),
                    focusedBorder: showConfirmSuccess ? greenBorder : (showConfirmError ? redBorder : null),
                    enabledBorder: showConfirmSuccess ? greenBorder: (showConfirmError ? redBorder : defaultBorder),
                  ),
                  obscureText: true,
                  readOnly: _showOtpInput,
                ),
                if (showConfirmError)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 4, left: 4),
                      child: Text('Passwords do not match', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ),
                if (showConfirmSuccess)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 4, left: 4),
                      child: Text('Passwords match', style: TextStyle(color: Colors.green, fontSize: 12)),
                    ),
                  ),
                const SizedBox(height: 24),
                if (!_showOtpInput)
                  ElevatedButton(
                    onPressed: _isFormValid && !_isSendingOtp ? _sendOTP : null,
                    child: _isSendingOtp
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send OTP'),
                  ),
                if (_showOtpInput) ...[
                  const Text("Enter OTP sent to your email", style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  Pinput(
                    length: 6,
                    controller: _otpController,
                    pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                    showCursor: true,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isRegistering ? null : _verifyOtpAndRegister,
                    child: _isRegistering
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Register'),
                  ),
                ],
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}