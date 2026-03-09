import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onLoginSuccess});
  final Function(Map<String, dynamic>) onLoginSuccess;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _api = ApiService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  bool _hidePassword = true; // Added visibility toggle state
  String? _error;

  Future<void> _submit() async {
    if (_passwordController.text.length < 6) {
      setState(() => _error = "Password must be at least 6 characters");
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      Map<String, dynamic> data;
      if (_isLogin) {
        data = await _api.login(_nameController.text.trim(), _passwordController.text);
      } else {
        data = await _api.register(
          username: _nameController.text.trim().replaceAll(' ', '_').toLowerCase(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phone: _phoneController.text.trim(),
        );
      }
      widget.onLoginSuccess(data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo.shade900, Colors.teal.shade800, Colors.black],
          ),
        ),
        child: Stack(
          children: [
            // Decorative background elements
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.indigo.withOpacity(0.2),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.teal.withOpacity(0.2),
                ),
              ),
            ),
            
            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App Branding
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_city_rounded, size: 48, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isLogin ? 'Hello Again!' : 'Join Us',
                            style: const TextStyle(
                              fontSize: 32, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            _isLogin ? 'Login to your account' : 'Enter your details below',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                          ),
                          const SizedBox(height: 32),
                          
                          // Form Fields
                          if (!_isLogin) ...[
                            _buildPremiumField(_nameController, Icons.person_outline, 'Full Name'),
                            const SizedBox(height: 16),
                            _buildPremiumField(_phoneController, Icons.phone_android_outlined, 'Phone Number'),
                            const SizedBox(height: 16),
                          ],
                          
                          _buildPremiumField(
                            _isLogin ? _nameController : _emailController, 
                            _isLogin ? Icons.alternate_email_rounded : Icons.email_outlined, 
                            _isLogin ? 'Username' : 'Email Address',
                            keyboardType: _isLogin ? null : TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildPremiumField(
                            _passwordController, 
                            Icons.lock_open_rounded, 
                            'Password', 
                            isPassword: _hidePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _hidePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: Colors.teal.shade200,
                              ),
                              onPressed: () => setState(() => _hidePassword = !_hidePassword),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Error Message
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.4))),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade400,
                                foregroundColor: Colors.white,
                                elevation: 10,
                                shadowColor: Colors.teal.withOpacity(0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: _loading ? null : _submit,
                              child: _loading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    _isLogin ? 'SIGN IN' : 'GET STARTED', 
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                  ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isLogin ? "New here? " : "Already joined? ",
                                style: TextStyle(color: Colors.white.withOpacity(0.6)),
                              ),
                              GestureDetector(
                                onTap: () => setState(() { _isLogin = !_isLogin; _error = null; }),
                                child: Text(
                                  _isLogin ? "Create Account" : "Sign In",
                                  style: TextStyle(
                                    color: Colors.teal.shade200, 
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (_isLogin)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: TextButton(
                                onPressed: () => _showForgotPasswordDialog(context),
                                child: Text(
                                  'Forgot your password?', 
                                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumField(TextEditingController controller, IconData icon, String hint, {bool isPassword = false, TextInputType? keyboardType, Widget? suffixIcon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: Colors.teal.shade200, size: 22),
          suffixIcon: suffixIcon, // Handle trailing eye icon
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.indigo.shade900.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white24),
          ),
          title: const Text('Reset Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('We will send a reset link to your email.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 20),
              _buildPremiumField(emailController, Icons.email_outlined, 'Your Email'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('CANCEL', style: TextStyle(color: Colors.white.withOpacity(0.6))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                try {
                  await _api.requestPasswordReset(emailController.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset link sent to your email')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('SEND'),
            ),
          ],
        ),
      ),
    );
  }
}
