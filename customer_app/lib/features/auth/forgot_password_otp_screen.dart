import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import 'auth_error_handler.dart';
import 'email_service.dart';

class ForgotPasswordOtpScreen extends StatefulWidget {
  final String email;
  final String otp;

  const ForgotPasswordOtpScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  late String _currentOtp;
  bool _isLoading = false;
  int _timerSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.otp;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timerSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        if (mounted) setState(() => _timerSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendCode() async {
    if (_timerSeconds > 0 || _isLoading) return;

    final newOtp = (100000 + Random().nextInt(900000)).toString();
    setState(() {
      _currentOtp = newOtp;
      _isLoading = true;
    });

    try {
      final normEmail = widget.email.trim().toLowerCase();
      await FirebaseFirestore.instance
          .collection('password_resets')
          .doc(normEmail)
          .set({
        'otp': newOtp,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(seconds: 30)),
        ),
      }).timeout(const Duration(seconds: 5));

      await EmailService.sendPasswordResetOtp(widget.email, newOtp);

      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();

      _startTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New verification code sent to ${widget.email}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AuthErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _verifyOtp() {
    if (_isLoading) return;

    if (_timerSeconds <= 0) {
      AuthErrorHandler.showError(
        context,
        'The recovery code has expired. Please request a new code.',
      );
      return;
    }

    setState(() => _isLoading = true);

    final enteredOtp = _controllers.map((c) => c.text).join();
    if (enteredOtp == _currentOtp) {
      context.push('/reset-forgotten-password', extra: {
        'email': widget.email,
        'otp': enteredOtp,
      });
    } else {
      AuthErrorHandler.showError(context, 'Invalid code. Please try again.');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final fieldBg = isDark ? AppTheme.darkSurface : Colors.white;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subtextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: purpleColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),

              Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.authHeader),
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8.h),

              Text(
                'Enter the code sent to recover your account.',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  color: subtextColor,
                ),
              ),
              SizedBox(height: 32.h),

              Text(
                'Code',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 12.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: fieldBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: fieldBorder, width: 1.0),
                    ),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      autofocus: index == 0,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      enabled: !_isLoading,
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (_controllers.map((c) => c.text).join().length == 6) {
                          _verifyOtp();
                        }
                      },
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        hintText: '*',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: purpleColor),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28.r),
                          ),
                        ),
                        child: Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.titleMedium),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

              SizedBox(height: 24.h),

              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive code? ",
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodySmall),
                        color: subtextColor,
                      ),
                    ),
                    GestureDetector(
                      onTap: _resendCode,
                      child: Text(
                        _timerSeconds > 0
                            ? 'Resend in 00:${_timerSeconds.toString().padLeft(2, '0')}'
                            : 'Resend Code',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          fontWeight: FontWeight.bold,
                          color: _timerSeconds > 0
                              ? subtextColor
                              : purpleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
