import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.appState, this.googleData});

  final AppState appState;
  final GoogleSignupData? googleData;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();

  late int _step;
  GoogleSignupData? _googleData;
  bool _submitting = false;
  bool _googleSigningIn = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _googleData = widget.googleData;
    final googleData = _googleData;
    if (googleData != null) {
      _step = 2;
      _nameController.text = googleData.name;
      _emailController.text = googleData.email;
    } else {
      _step = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGoogleSignup = _googleData != null;
    final title = isGoogleSignup
        ? 'Complete Registration'
        : ['Verify Email', 'Confirm OTP', 'Create Account'][_step];

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 10),
                Text(
                  'This is connected to the real signup and OTP routes from your backend.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppTheme.mutedColor(context)),
                ),
                const SizedBox(height: 24),
                if (_step == 0 && !isGoogleSignup)
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'WCE Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                if (_step == 1 && !isGoogleSignup)
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: '6-digit OTP',
                      prefixIcon: Icon(Icons.verified_outlined),
                    ),
                  ),
                if (_step == 2) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _handleStep,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(_buttonLabel),
                    ),
                  ),
                ),
                if (_step == 0 && !isGoogleSignup) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: AppTheme.mutedColor(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      onPressed: _googleSigningIn ? null : _handleGoogle,
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _googleSigningIn
                              ? 'Connecting...'
                              : 'Sign up with Google',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                        side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _buttonLabel {
    if (_submitting) return 'Please wait...';
    if (_step == 0) return 'Send OTP';
    if (_step == 1) return 'Verify OTP';
    return 'Create Account';
  }

  Future<void> _handleStep() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_step == 0) {
        final email = _emailController.text.trim();
        if (email.isEmpty) {
          throw Exception('Please enter your email');
        }
        if (!email.endsWith('@walchandsangli.ac.in')) {
          throw Exception('Only @walchandsangli.ac.in email addresses are allowed');
        }
        await widget.appState.sendOtp(email);
        setState(() => _step = 1);
      } else if (_step == 1) {
        await widget.appState.verifyOtp(
          _emailController.text.trim(),
          _otpController.text.trim(),
        );
        setState(() => _step = 2);
      } else {
        if (_passwordController.text != _confirmController.text) {
          throw Exception('Passwords do not match.');
        }
        if (_googleData != null) {
          await widget.appState.signUpWithGoogle(
            credential: _googleData!.credential,
            password: _passwordController.text,
            name: _nameController.text.trim(),
          );
        } else {
          await widget.appState.signUp(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            otp: _otpController.text.trim(),
          );
        }
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleGoogle() async {
    setState(() {
      _googleSigningIn = true;
      _error = null;
    });

    try {
      final result = await widget.appState.signInWithGoogle();
      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pop(true);
        return;
      }

      if (result.needsSignup && result.googleData != null) {
        if (!result.googleData!.email.endsWith('@walchandsangli.ac.in')) {
          setState(() {
            _error = 'Only @walchandsangli.ac.in email addresses are allowed';
          });
          return;
        }
        setState(() {
          _googleData = result.googleData;
          _nameController.text = result.googleData!.name;
          _emailController.text = result.googleData!.email;
          _step = 2;
        });
        return;
      }

      setState(() {
        _error = result.error ?? 'Google sign-up failed. Please try again.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _googleSigningIn = false;
        });
      }
    }
  }
}
