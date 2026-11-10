import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_theme.dart';
import '../services/secure_login_service.dart';

/// Flat bottom sheet shown when a login is refused by the lockout / IP limit.
/// Shows a live countdown, a password-reset hint, and (stage 4) Contact Support.
class LoginLockoutSheet {
  static Future<void> show(
    BuildContext context, {
    required LoginLockedException lock,
    required String email,
    required String accountType,
    VoidCallback? onResetPassword,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => _LockoutBody(
        lock: lock,
        email: email,
        accountType: accountType,
        onResetPassword: onResetPassword,
      ),
    );
  }

  /// Opens the user's mail app with a prefilled support request.
  static Future<bool> launchSupportEmail({
    required String supportEmail,
    required String email,
    required String accountType,
    required int stage,
  }) {
    final subject = 'Account locked - unlock request ($accountType)';
    final body = 'Hello MartFood Support,\n\n'
        'My account has been locked after repeated failed login attempts and I need help restoring access.\n\n'
        'Account email: $email\n'
        'Account type: $accountType\n'
        'Lockout stage: $stage (indefinite - admin unlock required)\n'
        'Date: ${DateTime.now().toUtc().toIso8601String()}\n'
        'Platform: ${defaultTargetPlatform.name}\n\n'
        'Please verify my identity and unlock my account.\n\nThank you.';
    final uri = Uri.parse(
        'mailto:$supportEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    return launchUrl(uri);
  }
}

class _LockoutBody extends StatefulWidget {
  final LoginLockedException lock;
  final String email;
  final String accountType;
  final VoidCallback? onResetPassword;

  const _LockoutBody({
    required this.lock,
    required this.email,
    required this.accountType,
    this.onResetPassword,
  });

  @override
  State<_LockoutBody> createState() => _LockoutBodyState();
}

class _LockoutBodyState extends State<_LockoutBody> {
  late int _remaining;
  Timer? _timer;

  bool get _permanent => widget.lock.indefinite;

  @override
  void initState() {
    super.initState();
    _remaining = widget.lock.remainingSec;
    if (!_permanent) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _remaining = _remaining > 0 ? _remaining - 1 : 0);
        if (_remaining == 0) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : Colors.white;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final fill = isDark ? AppTheme.darkBorder : AppTheme.lightInputFill;
    final purple = AppTheme.primaryPurpleFor(isDark);
    final text = isDark ? Colors.white : AppTheme.brandBlack;
    final muted = AppTheme.mutedTextColorFor(isDark);
    final error = Theme.of(context).colorScheme.error;
    final lock = widget.lock;

    final title = lock.ipBlocked
        ? 'Too many attempts'
        : (_permanent ? 'Account locked' : 'Login temporarily locked');

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 22),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: error.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: Icon(_permanent ? LucideIcons.lock : LucideIcons.timer,
                    color: error, size: 26),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: AppTypography.font(18),
                      fontWeight: FontWeight.w800,
                      color: text)),
              const SizedBox(height: 16),
              if (!_permanent)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border, width: 1),
                  ),
                  child: Column(
                    children: [
                      Text(_remaining > 0 ? _clock : 'You can try again now',
                          style: TextStyle(
                              fontSize:
                                  AppTypography.font(_remaining > 0 ? 28 : 15),
                              fontWeight: FontWeight.w800,
                              color: _remaining > 0 ? text : purple)),
                      if (_remaining > 0)
                        Text('remaining',
                            style: TextStyle(
                                fontSize: AppTypography.font(12),
                                color: muted)),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                _permanent
                    ? 'Your account was locked after repeated failed login attempts. It can only be unlocked by our support team.'
                    : (lock.ipBlocked
                        ? 'Too many failed attempts were made from this network. Please wait before trying again.'
                        : 'Too many failed login attempts. If you forgot your password, reset it now.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppTypography.font(13),
                    height: 1.45,
                    color: muted),
              ),
              const SizedBox(height: 20),
              if (_permanent)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final ok = await LoginLockoutSheet.launchSupportEmail(
                        supportEmail: lock.supportEmail,
                        email: widget.email,
                        accountType: widget.accountType,
                        stage: lock.stage,
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'No email app found. Please write to ${lock.supportEmail}.')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text('Contact Support',
                        style: TextStyle(
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              if (widget.onResetPassword != null && !_permanent) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onResetPassword!();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: purple,
                      side: BorderSide(color: border, width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text('Reset Password',
                        style: TextStyle(
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close',
                    style: TextStyle(
                        color: muted, fontSize: AppTypography.font(13))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
