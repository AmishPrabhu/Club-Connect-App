import 'package:flutter/material.dart';
import 'dart:async';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';
import '../widgets/animated_otp_input.dart';

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
  final _scrollController = ScrollController();

  late int _step;
  GoogleSignupData? _googleData;
  bool _submitting = false;
  bool _googleSigningIn = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _otpSuccess = false;
  int _otpAttempts = 0;
  static const int _maxOtpAttempts = 3;
  String? _error;

  Timer? _resendTimer;
  int _resendSeconds = 15;
  int _resendCount = 0;
  static const int _maxResends = 5;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    void doScroll() {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
    Future.delayed(const Duration(milliseconds: 150), doScroll);
    Future.delayed(const Duration(milliseconds: 350), doScroll);
    Future.delayed(const Duration(milliseconds: 600), doScroll);
  }

  void _startResendTimer() {
    setState(() => _resendSeconds = 30);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_resendCount >= _maxResends) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum resend limit reached (5/5). Please try again in 15 minutes.')),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.appState.sendOtp(_emailController.text.trim());
      _otpController.clear();
      setState(() => _resendCount++);
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent successfully! (${_resendCount}/$_maxResends)')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Create Account')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            36 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 10),
                Text(
                  isGoogleSignup
                      ? 'Set a password to complete your Club Connect account.'
                      : [
                          'Enter your @walchandsangli.ac.in email to get started.',
                          'Enter the 6-digit OTP sent to your email.',
                          'Set your name and a secure password.',
                        ][_step],
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        AnimatedOtpInput(
                          controller: _otpController,
                          length: 6,
                          isVerifying: _submitting,
                          isError: _error != null,
                          isSuccess: _otpSuccess,
                          onFocus: _scrollToBottom,
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          onCompleted: (_) {
                            if (!_submitting) _handleStep();
                          },
                        ),
                        if (_error != null && _otpAttempts > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFB91C1C)),
                                const SizedBox(width: 4),
                                Text(
                                  _maxOtpAttempts - _otpAttempts == 1
                                      ? '1 more try remaining'
                                      : '${_maxOtpAttempts - _otpAttempts} more tries remaining',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB91C1C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton(
                            onPressed: _resendSeconds == 0 && !_submitting && !_otpSuccess && _resendCount < _maxResends
                                ? _resendOtp
                                : null,
                            child: Text(
                              _resendCount >= _maxResends
                                  ? 'Resend limit reached (5/5)'
                                  : _resendSeconds > 0
                                      ? 'Resend OTP in ${_resendSeconds}s'
                                      : 'Resend OTP',
                              style: TextStyle(
                                color: _resendSeconds > 0 || _submitting || _otpSuccess || _resendCount >= _maxResends
                                    ? AppTheme.mutedColor(context)
                                    : Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_step == 2) ...[
                  TextField(
                    controller: _nameController,
                    maxLength: 50,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  PasswordStrengthIndicator(
                    password: _passwordController.text,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                  if (_confirmController.text.isNotEmpty &&
                      _passwordController.text != _confirmController.text)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 14, color: Color(0xFFB91C1C)),
                          const SizedBox(width: 4),
                          const Text(
                            'Passwords do not match',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
                      icon: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4285F4),
                          ),
                        ),
                      ),
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
                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.cardBg(context) : Colors.white,
                        side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Theme.of(context).dividerColor,
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
        _startResendTimer();
      } else if (_step == 1) {
        await widget.appState.verifyOtp(
          _emailController.text.trim(),
          _otpController.text.trim(),
        );
        setState(() {
          _otpAttempts = 0;
          _otpSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 1800));
        setState(() => _step = 2);
      } else {
        if (_nameController.text.trim().isEmpty) {
          throw Exception('Please enter your full name.');
        }
        if (_passwordController.text.length < 8) {
          throw Exception('Password must be at least 8 characters.');
        }
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
      final msg = error.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('ApiException: ', '');
      if (_step == 1) {
        final newAttempts = _otpAttempts + 1;
        if (newAttempts >= _maxOtpAttempts) {
          setState(() {
            _otpAttempts = 0;
            _step = 0;
            _otpController.clear();
            _error = 'Too many incorrect attempts. Please request a new OTP.';
          });
        } else {
          setState(() {
            _otpAttempts = newAttempts;
            _error = msg;
          });
        }
      } else {
        setState(() => _error = msg);
      }
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
