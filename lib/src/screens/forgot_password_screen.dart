import 'dart:async';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';
import '../widgets/animated_otp_input.dart';
import '../widgets/glass_card.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.appState, this.initialEmail});

  final AppState appState;
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _scrollController = ScrollController();

  // 0 = enter email, 1 = enter OTP, 2 = enter new password, 3 = success
  int _step = 0;
  bool _isLoading = false;
  bool _otpSuccess = false;
  bool _otpError = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _otpAttempts = 0;
  static const int _maxOtpAttempts = 3;
  String? _error;

  Timer? _resendTimer;
  int _resendSeconds = 15;
  int _resendCount = 0;
  static const int _maxResends = 5;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.appState.requestPasswordReset(_emailController.text.trim());
      _tokenController.clear();
      setState(() => _resendCount++);
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent successfully! (${_resendCount}/$_maxResends)')),
        );
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
      final isRateLimited = msg.toLowerCase().contains('too many') || msg.toLowerCase().contains('limit');
      setState(() {
        _error = msg;
        if (isRateLimited) {
          _resendCount = _maxResends;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStep() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_step == 0) {
        // ── Step 0: send OTP to email ──────────────────────────────
        final email = _emailController.text.trim();
        if (email.isEmpty) throw Exception('Please enter your email');
        final emailRegex = RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$');
        if (!emailRegex.hasMatch(email)) {
          throw Exception('Please enter a valid email address');
        }
        await widget.appState.requestPasswordReset(email);
        setState(() {
          _step = 1;
          _tokenController.clear();
          _otpError = false;
          _otpSuccess = false;
        });
        _startResendTimer();
        _scrollToBottom();

      } else if (_step == 1) {
        // ── Step 1: verify OTP on server ──────────────────────────
        final token = _tokenController.text.trim();
        if (token.length < 6) {
          setState(() => _otpError = true);
          throw Exception('Please enter the complete 6-digit OTP code');
        }
        // Real server validation — throws ApiException on wrong/expired OTP
        await widget.appState.verifyResetToken(
          token: token,
          email: _emailController.text.trim(),
        );
        // OTP correct — reset attempts, show green success animation, then reveal password step
        setState(() {
          _otpAttempts = 0;
          _otpSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 1600));
        if (mounted) {
          setState(() {
            _step = 2;
            _otpSuccess = false;
            _passwordController.clear();
            _confirmController.clear();
          });
        }

      } else if (_step == 2) {
        // ── Step 2: set new password ──────────────────────────────
        final password = _passwordController.text;
        final confirm = _confirmController.text;
        if (password.length < 8) {
          throw Exception('New password must be at least 8 characters');
        }
        if (password != confirm) throw Exception('Passwords do not match');
        await widget.appState.resetPassword(
          token: _tokenController.text.trim(),
          email: _emailController.text.trim(),
          password: password,
        );
        setState(() => _step = 3);
      }
    } catch (e) {
      final msg = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('ApiException: ', '');
      if (_step == 1) {
        final newAttempts = _otpAttempts + 1;
        if (newAttempts >= _maxOtpAttempts) {
          // Locked — go back to email step for a fresh OTP
          setState(() {
            _otpAttempts = 0;
            _otpError = false;
            _step = 0;
            _tokenController.clear();
            _error = 'Too many incorrect attempts. Please request a new code.';
          });
        } else {
          setState(() {
            _otpAttempts = newAttempts;
            _otpError = true;
            _error = msg;
          });
        }
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titles = ['Verify Email', 'Confirm OTP', 'New Password', 'Password Reset!'];
    final descriptions = [
      'Enter your email to receive a 6-digit reset code.',
      'Enter the code sent to your email.',
      'Set your new secure password.',
      'Your password has been updated successfully.',
    ];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_step == 1 || _step == 2) {
              setState(() {
                _step--;
                _error = null;
                _otpError = false;
                _otpSuccess = false;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            24.0,
            24.0,
            24.0,
            36 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: GlassCard(
            child: _step == 3
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        titles[3],
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        descriptions[3],
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(context).popUntil((route) => route.isFirst),
                          child: const Text('Back to Login'),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(
                            _step == 0
                                ? Icons.mail_outline_rounded
                                : _step == 1
                                    ? Icons.vpn_key_outlined
                                    : Icons.lock_reset_rounded,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              titles[_step],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(descriptions[_step], style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),

                      // ── Step 0: Email input ──────────────────────────
                      if (_step == 0)
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),

                      // ── Step 1: Animated OTP ─────────────────────────
                      if (_step == 1) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reset code sent to:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                _emailController.text,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedOtpInput(
                          controller: _tokenController,
                          length: 6,
                          isVerifying: _isLoading,
                          isError: _otpError,
                          isSuccess: _otpSuccess,
                          onFocus: _scrollToBottom,
                          onChanged: (_) {
                            if (_otpError) setState(() => _otpError = false);
                            if (_error != null) setState(() => _error = null);
                          },
                          onCompleted: (_) {
                            if (!_isLoading) _handleStep();
                          },
                        ),
                        if (_otpError && _otpAttempts > 0)
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
                            onPressed: _resendSeconds == 0 && !_isLoading && !_otpSuccess && _resendCount < _maxResends
                                ? _resendOtp
                                : null,
                            child: Text(
                              _resendCount >= _maxResends
                                  ? 'Resend limit reached (5/5)'
                                  : _resendSeconds > 0
                                      ? 'Resend OTP in ${_resendSeconds}s'
                                      : 'Resend OTP',
                              style: TextStyle(
                                color: _resendSeconds > 0 || _isLoading || _otpSuccess || _resendCount >= _maxResends
                                    ? AppTheme.mutedColor(context)
                                    : Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // ── Step 2: New password ─────────────────────────
                      if (_step == 2) ...[
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        PasswordStrengthIndicator(password: _passwordController.text),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                        ),
                      ],

                      // ── Error ────────────────────────────────────────
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

                      // ── Primary action button (hidden during OTP success animation) ──
                      if (!_otpSuccess) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _handleStep,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _step == 0
                                        ? 'Send OTP'
                                        : _step == 1
                                            ? 'Verify OTP'
                                            : 'Reset Password',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
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
}
