import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// ─── Persistent OTP Lock Manager ─────────────────────────────────────────────

class OtpLockManager {
  static const int maxResends = 5;
  static const int cooldownMinutes = 15;

  /// Gets the remaining lock duration in seconds (0 if not locked/expired).
  static Future<int> getRemainingLockSeconds(String flowKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryMs = prefs.getInt('otp_lock_expiry_$flowKey') ?? 0;
      if (expiryMs == 0) return 0;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final remainingMs = expiryMs - nowMs;
      if (remainingMs <= 0) {
        await prefs.remove('otp_lock_expiry_$flowKey');
        await prefs.remove('otp_resend_count_$flowKey');
        return 0;
      }
      return (remainingMs / 1000).ceil();
    } catch (_) {
      return 0;
    }
  }

  /// Gets the saved resend count for a flow (resets to 0 if lock expired).
  static Future<int> getResendCount(String flowKey) async {
    try {
      final remainingSecs = await getRemainingLockSeconds(flowKey);
      if (remainingSecs == 0) {
        return 0;
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('otp_resend_count_$flowKey') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Increments the resend count for a flow and saves it to SharedPreferences.
  /// If count reaches max (5), automatically triggers a 15-minute lock.
  static Future<int> incrementResendCount(String flowKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int current = prefs.getInt('otp_resend_count_$flowKey') ?? 0;
      current++;
      await prefs.setInt('otp_resend_count_$flowKey', current);
      if (current >= maxResends) {
        await lockFlow(flowKey, minutes: cooldownMinutes);
      }
      return current;
    } catch (_) {
      return 1;
    }
  }

  /// Locks a flow for [minutes] in SharedPreferences.
  static Future<void> lockFlow(String flowKey, {int minutes = cooldownMinutes}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryMs = DateTime.now().add(Duration(minutes: minutes)).millisecondsSinceEpoch;
      await prefs.setInt('otp_lock_expiry_$flowKey', expiryMs);
      await prefs.setInt('otp_resend_count_$flowKey', maxResends);
    } catch (_) {}
  }
}
