import 'package:flutter/material.dart';

// ─── Error message helper ─────────────────────────────────────────────────────

/// Strips internal exception prefixes so users never see raw exception text.
String cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('ApiException: ', '')
      .replaceFirst('FormatException: ', '')
      .trim();
}

// ─── Password strength widget ─────────────────────────────────────────────────

enum _PasswordStrength { empty, weak, medium, strong }

_PasswordStrength _evaluate(String password) {
  if (password.isEmpty) return _PasswordStrength.empty;
  int score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
  if (score <= 1) return _PasswordStrength.weak;
  if (score <= 3) return _PasswordStrength.medium;
  return _PasswordStrength.strong;
}

/// Shows a color-coded strength bar + label below a password field.
/// Pass [password] reactively from a StatefulWidget's state.
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = _evaluate(password);

    final (label, color, filled) = switch (strength) {
      _PasswordStrength.weak => ('Weak', const Color(0xFFDC2626), 1),
      _PasswordStrength.medium => ('Medium', const Color(0xFFF59E0B), 2),
      _PasswordStrength.strong => ('Strong', const Color(0xFF10B981), 3),
      _ => ('', Colors.grey, 0),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i < filled ? color : Colors.grey.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            'Password strength: $label',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
