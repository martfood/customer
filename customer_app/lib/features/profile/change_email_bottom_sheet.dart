import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import '../auth/auth_error_handler.dart';
import '../auth/email_service.dart';

/// Shows the Dual Email OTP Verification bottom sheet for changing customer email.
Future<bool?> showChangeEmailBottomSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) => const ChangeEmailBottomSheet(),
  );
}

class ChangeEmailBottomSheet extends StatefulWidget {
  const ChangeEmailBottomSheet({super.key});

  @override
  State<ChangeEmailBottomSheet> createState() => _ChangeEmailBottomSheetState();
}

enum _EmailChangeStep {
  verifyCurrentEmail,
  enterNewEmail,
  verifyNewEmail,
  success,
}

class _ChangeEmailBottomSheetState extends State<ChangeEmailBottomSheet> {
  _EmailChangeStep _currentStep = _EmailChangeStep.verifyCurrentEmail;

  final TextEditingController _currentOtpController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _newOtpController = TextEditingController();

  String _currentEmail = '';
  String _generatedCurrentOtp = '';
  String _generatedNewOtp = '';
  String _newEmail = '';

  bool _isLoading = false;
  String? _errorMessage;

  // Resend Timer State (Rule 7 Invariant)
  int _currentOtpCountdown = 30;
  Timer? _currentOtpTimer;
  bool _canResendCurrentOtp = false;

  int _newOtpCountdown = 30;
  Timer? _newOtpTimer;
  bool _canResendNewOtp = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _currentEmail = user?.email ?? '';
    _initiateCurrentEmailOtp();
  }

  @override
  void dispose() {
    _currentOtpTimer?.cancel();
    _newOtpTimer?.cancel();
    _currentOtpController.dispose();
    _newEmailController.dispose();
    _newOtpController.dispose();
    super.dispose();
  }

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    }
    return '${name[0]}***${name[name.length - 1]}@$domain';
  }

  void _startCurrentOtpTimer() {
    _currentOtpTimer?.cancel();
    setState(() {
      _currentOtpCountdown = 30;
      _canResendCurrentOtp = false;
    });
    _currentOtpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_currentOtpCountdown <= 1) {
        timer.cancel();
        setState(() {
          _currentOtpCountdown = 0;
          _canResendCurrentOtp = true;
        });
      } else {
        setState(() {
          _currentOtpCountdown--;
        });
      }
    });
  }

  void _startNewOtpTimer() {
    _newOtpTimer?.cancel();
    setState(() {
      _newOtpCountdown = 30;
      _canResendNewOtp = false;
    });
    _newOtpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_newOtpCountdown <= 1) {
        timer.cancel();
        setState(() {
          _newOtpCountdown = 0;
          _canResendNewOtp = true;
        });
      } else {
        setState(() {
          _newOtpCountdown--;
        });
      }
    });
  }

  Future<void> _initiateCurrentEmailOtp() async {
    if (_currentEmail.isEmpty) {
      setState(() {
        _errorMessage = 'Unable to identify current registered email.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _generatedCurrentOtp = _generateOtp();
    debugPrint('Current Email OTP generated: $_generatedCurrentOtp');

    try {
      final sent = await EmailService.sendOtpEmail(_currentEmail, _generatedCurrentOtp);
      if (!sent) {
        debugPrint('Resend sandbox notice: verification code is $_generatedCurrentOtp');
      }
      _startCurrentOtpTimer();
    } catch (e) {
      debugPrint('Error sending OTP to current email: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyCurrentOtp() async {
    final code = _currentOtpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit verification code.';
      });
      return;
    }

    if (code != _generatedCurrentOtp) {
      setState(() {
        _errorMessage = 'Invalid verification code. Please check your email or resend code.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _currentStep = _EmailChangeStep.enterNewEmail;
    });
  }

  Future<void> _sendNewEmailOtp() async {
    final newEmail = _newEmailController.text.trim().toLowerCase();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (newEmail.isEmpty || !emailRegex.hasMatch(newEmail)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return;
    }

    if (newEmail == _currentEmail.toLowerCase()) {
      setState(() {
        _errorMessage = 'New email cannot be the same as your current email.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _newEmail = newEmail;
    });

    try {
      // Check if new email is already registered in customers collection
      final existingDocs = await FirebaseFirestore.instance
          .collection('customers')
          .where('email', isEqualTo: _newEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));

      if (existingDocs.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'This email address is already registered to another account. Please use a different email.';
          });
        }
        return;
      }

      _generatedNewOtp = _generateOtp();
      debugPrint('New Email OTP generated: $_generatedNewOtp');

      final sent = await EmailService.sendOtpEmail(_newEmail, _generatedNewOtp);
      if (!sent) {
        debugPrint('Resend sandbox notice: verification code is $_generatedNewOtp');
      }
      _startNewOtpTimer();
      if (mounted) {
        setState(() {
          _currentStep = _EmailChangeStep.verifyNewEmail;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to verify email address. Please check your connection and try again.';
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

  Future<void> _verifyNewOtpAndCommit() async {
    final code = _newOtpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit verification code.';
      });
      return;
    }

    if (code != _generatedNewOtp) {
      setState(() {
        _errorMessage = 'Invalid verification code. Please check your new email or resend code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update in Firebase Auth
        try {
          await user.verifyBeforeUpdateEmail(_newEmail);
        } catch (authError) {
          debugPrint('Note on verifyBeforeUpdateEmail: $authError');
        }

        // Update in Firestore customers collection
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .update({
          'email': _newEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        setState(() {
          _currentStep = _EmailChangeStep.success;
        });
      }
    } catch (e) {
      if (mounted) {
        AuthErrorHandler.showError(context, e);
        setState(() {
          _errorMessage = 'Failed to update email address. Please try again.';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final fieldBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.only(
        left: 24.w,
        right: 24.w,
        top: 14.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag Handle
            Container(
              width: 38.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : const Color(0xFFDCDCE0),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),

            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertCircle, color: Colors.red, size: 18.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: AppTypography.font(12),
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── STEP 1: VERIFY CURRENT EMAIL ─────────────────────────────────
            if (_currentStep == _EmailChangeStep.verifyCurrentEmail) ...[
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: purpleColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.mail, size: 30.sp, color: purpleColor),
              ),
              SizedBox(height: 16.h),
              Text(
                'Verify Current Email',
                style: TextStyle(
                  fontSize: AppTypography.font(20),
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                'Enter the 6-digit code sent to ${_maskEmail(_currentEmail)} to verify your identity.',
                style: TextStyle(
                  fontSize: AppTypography.font(13),
                  color: mutedTextColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),

              // OTP Input
              _buildOtpTextField(
                controller: _currentOtpController,
                fieldBg: fieldBg,
                fieldBorder: fieldBorder,
                textColor: primaryTextColor,
              ),
              SizedBox(height: 16.h),

              // Resend Countdown
              _buildResendRow(
                canResend: _canResendCurrentOtp,
                countdown: _currentOtpCountdown,
                onResend: _initiateCurrentEmailOtp,
                purpleColor: purpleColor,
                mutedTextColor: mutedTextColor,
              ),
              SizedBox(height: 24.h),

              _buildActionButton(
                label: 'Verify Current Email',
                isLoading: _isLoading,
                onTap: _verifyCurrentOtp,
                purpleColor: purpleColor,
              ),
            ]

            // ── STEP 2: ENTER NEW EMAIL ──────────────────────────────────────
            else if (_currentStep == _EmailChangeStep.enterNewEmail) ...[
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: purpleColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.mailCheck, size: 30.sp, color: purpleColor),
              ),
              SizedBox(height: 16.h),
              Text(
                'Enter New Email',
                style: TextStyle(
                  fontSize: AppTypography.font(20),
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                'Please enter the new email address you want to link to your MartFood account.',
                style: TextStyle(
                  fontSize: AppTypography.font(13),
                  color: mutedTextColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),

              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: fieldBorder, width: 1.0),
                ),
                child: TextField(
                  controller: _newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: AppTypography.font(14),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(LucideIcons.mail, color: purpleColor, size: 20.sp),
                    hintText: 'Enter new email address',
                    hintStyle: TextStyle(
                      color: mutedTextColor,
                      fontSize: AppTypography.font(14),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              _buildActionButton(
                label: 'Send Verification Code',
                isLoading: _isLoading,
                onTap: _sendNewEmailOtp,
                purpleColor: purpleColor,
              ),
            ]

            // ── STEP 3: VERIFY NEW EMAIL ─────────────────────────────────────
            else if (_currentStep == _EmailChangeStep.verifyNewEmail) ...[
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: purpleColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.keyRound, size: 30.sp, color: purpleColor),
              ),
              SizedBox(height: 16.h),
              Text(
                'Verify New Email',
                style: TextStyle(
                  fontSize: AppTypography.font(20),
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                'We sent a 6-digit confirmation code to $_newEmail. Enter it below to complete the change.',
                style: TextStyle(
                  fontSize: AppTypography.font(13),
                  color: mutedTextColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),

              // OTP Input
              _buildOtpTextField(
                controller: _newOtpController,
                fieldBg: fieldBg,
                fieldBorder: fieldBorder,
                textColor: primaryTextColor,
              ),
              SizedBox(height: 16.h),

              // Resend Countdown
              _buildResendRow(
                canResend: _canResendNewOtp,
                countdown: _newOtpCountdown,
                onResend: _sendNewEmailOtp,
                purpleColor: purpleColor,
                mutedTextColor: mutedTextColor,
              ),
              SizedBox(height: 24.h),

              _buildActionButton(
                label: 'Confirm & Update Email',
                isLoading: _isLoading,
                onTap: _verifyNewOtpAndCommit,
                purpleColor: purpleColor,
              ),
            ]

            // ── STEP 4: SUCCESS ──────────────────────────────────────────────
            else if (_currentStep == _EmailChangeStep.success) ...[
              Container(
                width: 70.w,
                height: 70.w,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.circleCheck, size: 38.sp, color: Colors.green),
              ),
              SizedBox(height: 18.h),
              Text(
                'Email Address Updated!',
                style: TextStyle(
                  fontSize: AppTypography.font(20),
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.h),
              Text(
                'Your MartFood account email has been successfully changed to $_newEmail.',
                style: TextStyle(
                  fontSize: AppTypography.font(13),
                  color: mutedTextColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 28.h),

              _buildActionButton(
                label: 'Done',
                isLoading: false,
                onTap: () => Navigator.pop(context, true),
                purpleColor: purpleColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOtpTextField({
    required TextEditingController controller,
    required Color fieldBg,
    required Color fieldBorder,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: fieldBorder, width: 1.0),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: AppTypography.font(24),
          fontWeight: FontWeight.w800,
          letterSpacing: 10.w,
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: '••••••',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: AppTypography.font(24),
            letterSpacing: 10.w,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        ),
      ),
    );
  }

  Widget _buildResendRow({
    required bool canResend,
    required int countdown,
    required VoidCallback onResend,
    required Color purpleColor,
    required Color mutedTextColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (canResend) ...[
          TextButton(
            onPressed: onResend,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Resend Code',
              style: TextStyle(
                fontSize: AppTypography.font(13),
                fontWeight: FontWeight.bold,
                color: purpleColor,
              ),
            ),
          ),
        ] else ...[
          Text(
            'Resend code in 00:${countdown.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: AppTypography.font(13),
              color: mutedTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
    required Color purpleColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: purpleColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26.r),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.font(15),
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
