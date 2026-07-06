import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _googleSigningIn = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (MediaQuery.of(context).size.width > 900)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.navy, Color(0xFF0F3B73)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Text(
                        'Welcome to Club Connect',
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sign in against the same backend your website uses.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome Back',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Use your existing Club Connect account.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppTheme.mutedColor(context)),
                        ),
                        const SizedBox(height: 26),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Official Email ID',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(
                                      appState: widget.appState),
                                ),
                              );
                            },
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                _submitting ? 'Signing In...' : 'Sign In',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR', style: TextStyle(color: AppTheme.mutedColor(context), fontWeight: FontWeight.bold, fontSize: 12)),
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
                                    : 'Sign in with Google',
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

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.appState.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
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
        Navigator.of(context).pop();
        return;
      }

      if (result.needsSignup && result.googleData != null) {
        final created = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => SignupScreen(
              appState: widget.appState,
              googleData: result.googleData,
            ),
          ),
        );
        if (!mounted) return;
        if (created == true || widget.appState.session != null) {
          Navigator.of(context).pop();
        }
        return;
      }

      setState(() {
        _error = result.error ?? 'Google sign-in failed. Please try again.';
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
