import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/glass_card.dart';

class SetupAdminScreen extends StatefulWidget {
  const SetupAdminScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<SetupAdminScreen> createState() => _SetupAdminScreenState();
}

class _SetupAdminScreenState extends State<SetupAdminScreen> {
  final _nameController = TextEditingController(text: 'Super Admin');
  final _emailController = TextEditingController(text: 'admin@wce.ac.in');
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _requireOtp = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final otp = _otpController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Please complete all required fields.';
        _isError = true;
      });
      return;
    }

    if (_requireOtp && otp.isEmpty) {
      setState(() {
        _message =
            'Please enter the verification code sent to the existing admin.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
      _isError = false;
    });

    try {
      final result = await widget.appState.setupAdmin(
        email: email,
        password: password,
        name: name,
        otp: _requireOtp ? otp : null,
      );

      if (!mounted) return;

      if (result.requireOtp) {
        setState(() {
          _requireOtp = true;
          _isError = true;
          _message = result.message;
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Super admin created successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString().replaceFirst('Exception: ', '');
          _isError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Initial Admin Setup')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6F9FE), Color(0xFFEAF1FB)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create the first admin account',
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This matches the website’s protected setup flow and supports OTP handoff when an admin already exists.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_message != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isError
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isError
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFF86EFAC),
                          ),
                        ),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _isError
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF166534),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Admin Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Admin Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    if (_requireOtp) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'OTP',
                          prefixIcon: Icon(Icons.verified_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            _isLoading
                                ? (_requireOtp
                                      ? 'Verifying...'
                                      : 'Creating Admin...')
                                : (_requireOtp
                                      ? 'Verify & Claim Admin'
                                      : 'Create Super Admin'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Important: once the first admin is set up, you can keep this flow for recovery or hide it from public navigation.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
