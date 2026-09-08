import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import 'auth_error_handler.dart';
import 'email_service.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String password;
  final String otp;
  final String fullName;
  final String phoneNumber;
  final String profilePicPath;

  const OtpScreen({
    super.key,
    required this.email,
    required this.password,
    required this.otp,
    this.fullName = '',
    this.phoneNumber = '',
    this.profilePicPath = '',
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  bool _isLoading = false;
  late String _currentOtp;

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

    final newOtp = (1000 + Random().nextInt(9000)).toString();
    setState(() {
      _currentOtp = newOtp;
    });

    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();

    _startTimer();
    EmailService.sendOtpEmail(widget.email, newOtp);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code resent to ${widget.email}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;

    if (_timerSeconds <= 0) {
      AuthErrorHandler.showError(
        context,
        'The verification code has expired. Please request a new code.',
      );
      return;
    }

    final enteredOtp = _controllers.map((c) => c.text).join();
    if (enteredOtp == _currentOtp) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 1. Create firebase user
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: widget.email,
              password: widget.password,
            )
            .timeout(const Duration(seconds: 5));

        final uid = userCredential.user?.uid;
        if (uid != null) {
          String profilePicUrl = '';

          // 2. Upload profile pic if selected
          if (widget.profilePicPath.isNotEmpty) {
            final file = File(widget.profilePicPath);
            if (await file.exists()) {
              final storageRef = FirebaseStorage.instance
                  .ref()
                  .child('profile_pics')
                  .child('$uid.jpg');
              await storageRef
                  .putFile(file)
                  .timeout(const Duration(seconds: 5));
              profilePicUrl = await storageRef
                  .getDownloadURL()
                  .timeout(const Duration(seconds: 5));
            }
          }

          // 3. Store customer in Firestore
          await FirebaseFirestore.instance
              .collection('customers')
              .doc(uid)
              .set({
            'uid': uid,
            'email': widget.email,
            'fullName': widget.fullName,
            'phoneNumber': widget.phoneNumber,
            'profilePic': profilePicUrl,
            'balance': 0.0,
            'createdAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 5));

          // 4. Send welcome email in the background
          EmailService.sendWelcomeEmail(widget.email, widget.fullName);
        }

        if (mounted) {
          context.go('/success');
        }
      } catch (e) {
        if (mounted) {
          AuthErrorHandler.showError(context, e);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      AuthErrorHandler.showError(context, 'Invalid OTP code. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

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
              Text(
                'Verify Email',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.authHeader),
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Enter the 4-digit code sent to ${widget.email}.',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  color: mutedTextColor,
                ),
              ),
              SizedBox(height: 36.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  4,
                  (index) => Container(
                    width: 60.w,
                    height: 60.w,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 1),
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
                        if (value.isNotEmpty && index < 3) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (_controllers
                                .map((c) => c.text)
                                .join()
                                .length ==
                            4) {
                          _verifyOtp();
                        }
                      },
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.displaySmall),
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 28.h),

              // ── Dynamic Resend Timer ─────────────────────────────────────
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive code? ",
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodySmall),
                        color: mutedTextColor,
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
                              ? mutedTextColor
                              : purpleColor,
                        ),
                      ),
                    ),
                  ],
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
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
