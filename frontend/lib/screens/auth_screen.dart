import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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
  bool _hidePassword = true; 
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
      backgroundColor: AppTheme.darkBackground,
      body: Stack(
        children: [
          // Professional Subtle Background Elements
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBlue.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentTeal.withOpacity(0.1),
              ),
            ),
          ),
          
          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450), // Cap width for tablets/web
                child: Card( // Uses the new AppTheme card style
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Branding
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_city_rounded, size: 56, color: AppTheme.accentTeal),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _isLogin ? 'Welcome Back' : 'Create Account',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin ? 'Sign in to access your dashboard' : 'Join Civic AI to report and track issues',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        
                        // Form Fields
                        if (!_isLogin) ...[
                          _buildPremiumField(_nameController, Icons.person_outline, 'Full Name'),
                          const SizedBox(height: 16),
                          _buildPremiumField(_phoneController, Icons.phone_android_outlined, 'Phone Number'),
                          const SizedBox(height: 16),
                        ],
                        
                        _buildPremiumField(
                          _isLogin ? _nameController : _emailController, 
                          _isLogin ? Icons.person_rounded : Icons.email_outlined, 
                          _isLogin ? 'Username / Email' : 'Email Address',
                          keyboardType: _isLogin ? null : TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildPremiumField(
                          _passwordController, 
                          Icons.lock_outline_rounded, 
                          'Password', 
                          isPassword: _hidePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _hidePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppTheme.textMediumContrast,
                            ),
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Error Message
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.dangerRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.dangerRed.withOpacity(0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _error!, 
                                      style: const TextStyle(color: AppTheme.dangerRed, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500)
                                    )
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading 
                              ? const SizedBox(
                                  width: 24, height: 24, 
                                  child: CircularProgressIndicator(color: AppTheme.darkBackground, strokeWidth: 3)
                                )
                              : Text(_isLogin ? 'SIGN IN' : 'GET STARTED'),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _isLogin ? "Don't have an account? " : "Already have an account? ",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: () => setState(() { _isLogin = !_isLogin; _error = null; }),
                              child: Text(_isLogin ? "Create one." : "Sign In."),
                            ),
                          ],
                        ),

                        if (_isLogin)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton(
                              onPressed: () => _showForgotPasswordDialog(context),
                              child: const Text('Forgot your password?', style: TextStyle(fontWeight: FontWeight.normal)),
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
    );
  }

  Widget _buildPremiumField(TextEditingController controller, IconData icon, String hint, {bool isPassword = false, TextInputType? keyboardType, Widget? suffixIcon}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Icon(icon, color: AppTheme.textMediumContrast, size: 24),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        title: Text('Reset Password', style: Theme.of(context).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your registered email address and we will send you a secure reset link.', style: TextStyle(color: AppTheme.textMediumContrast, fontSize: 15, height: 1.4)),
            const SizedBox(height: 24),
            _buildPremiumField(emailController, Icons.email_outlined, 'Email Address'),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textMediumContrast)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _api.requestPasswordReset(emailController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset link sent to your email'), backgroundColor: AppTheme.successGreen)
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.dangerRed));
                }
              }
            },
            child: const Text('SEND LINK'),
          ),
        ],
      ),
    );
  }
}
