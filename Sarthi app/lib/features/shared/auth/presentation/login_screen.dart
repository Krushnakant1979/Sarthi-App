import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_providers.dart';
import '../domain/app_user.dart';
import '../../../../app/app_config.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim();
      final cred = await repo.signInWithEmail(
        email: email,
        password: _passwordController.text.trim(),
      );

      if (cred.user != null) {
        final existingUser = await ref.read(userRepositoryProvider).getUser(cred.user!.uid);
        final appType = ref.read(appConfigProvider).appType;

        if (existingUser == null) {
          await repo.signOut();
          setState(() => _errorMessage = 'Account not found. Please create an account.');
          return;
        }

        if (appType == AppType.user && existingUser.role != 'user') {
          await repo.signOut();
          setState(() => _errorMessage = 'This email is registered as a Captain/Admin. Please use the correct app.');
          return;
        }

        if (appType == AppType.captain && existingUser.role != 'captain') {
          await repo.signOut();
          setState(() => _errorMessage = 'This email is registered as a User. Please use the User app or create a Captain account.');
          return;
        }

        if (appType == AppType.admin && existingUser.role != 'admin') {
          await repo.signOut();
          setState(() => _errorMessage = 'Access denied. Admin only.');
          return;
        }
      }

      if (mounted) {
        final currentApp = ref.read(appConfigProvider).appType;
        if (currentApp == AppType.admin) {
          context.go('/admin');
        } else if (currentApp == AppType.captain) {
          context.go('/captain');
        } else {
          context.go('/');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
            _errorMessage = 'incorrect password';
          } else {
            _errorMessage = e.message ?? e.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appType = ref.watch(appConfigProvider).appType;
    final isSpecialApp = appType != AppType.user;
    final appRole = appType == AppType.admin ? 'Admin' : 'Captain';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                Text(
                  isSpecialApp ? 'Log in - $appRole' : 'Log in',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 60),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    filled: false,
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                    if (!v.contains('@')) return 'Enter a valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    filled: false,
                    labelText: 'password',
                    labelStyle: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your password';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Forgot Password
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),

                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],

                // Log In Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2144), // Navy Blue
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Log in',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),

                const SizedBox(height: 60),

                // Social Logins
                _SocialLoginButton(
                  text: 'Log in with Google',
                  iconWidget: _buildGoogleIcon(),
                  onTap: () {},
                ),
                const SizedBox(height: 16),
                _SocialLoginButton(
                  text: 'Create Account',
                  iconWidget: const Icon(Icons.phone_android_rounded, color: Color(0xFF1E293B), size: 24),
                  onTap: () => context.push('/signup'),
                ),

                const SizedBox(height: 40),

                const Text(
                  'Ready to ride? Book your Sarthi in seconds and travel safely.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Image.asset(
      'assets/images/google_logo.png',
      height: 22,
      width: 22,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.blue),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final String text;
  final Widget iconWidget;
  final VoidCallback onTap;

  const _SocialLoginButton({
    required this.text,
    required this.iconWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7), // Light green-ish background from screenshot
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Positioned(
              right: 0,
              child: iconWidget,
            ),
          ],
        ),
      ),
    );
  }
}
