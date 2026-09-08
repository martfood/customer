import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'auth_error_handler.dart';

class ResetForgottenPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;

  const ResetForgottenPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ResetForgottenPasswordScreen> createState() =>
      _ResetForgottenPasswordScreenState();
}

class _ResetForgottenPasswordScreenState
    extends State<ResetForgottenPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      AuthErrorHandler.showError(context, 'Please fill all fields');
      return;
    }

    if (password != confirmPassword) {
      AuthErrorHandler.showError(context, 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(
              'https://europe-west1-martfood-app.cloudfunctions.net/resetPasswordWithOtp',
            ),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': widget.email,
              'otp': widget.otp,
              'newPassword': password,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        if (mounted) {
          _showSuccessBottomSheet();
        }
      } else {
        throw Exception(responseData['error'] ?? 'Failed to reset password.');
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
  }

  void _showSuccessBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[400],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Icon(Icons.check_circle_outline, color: Colors.green, size: 64.sp),
              SizedBox(height: 16.h),
              Text(
                'Password Reset Success',
                style: TextStyle(
                  color: textColor,
                  fontSize: AppTypography.font(22),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                'Your password has been successfully reset. You can now log in with your new credentials.',
                style: TextStyle(
                  color: AppTheme.mutedTextColorFor(isDark),
                  fontSize: AppTypography.font(14),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () {
                    context.pop();
                    context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                  ),
                  child: Text(
                    'Back to Login',
                    style: TextStyle(
                      fontSize: AppTypography.font(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
    final subtextColor = AppTheme.mutedTextColorFor(isDark);

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
                'Reset Password',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.authHeader),
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8.h),

              Text(
                'Create a new strong password for your account.',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  color: subtextColor,
                ),
              ),
              SizedBox(height: 32.h),

              Text(
                'New Password',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(color: fieldBorder, width: 1.0),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(
                    color: textColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter new password',
                    hintStyle: TextStyle(
                      color: AppTheme.hintColorFor(isDark),
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 14.h,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              Text(
                'Confirm New Password',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(color: fieldBorder, width: 1.0),
                ),
                child: TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: TextStyle(
                    color: textColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Re-enter new password',
                    hintStyle: TextStyle(
                      color: AppTheme.hintColorFor(isDark),
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 14.h,
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
                        onPressed: _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28.r),
                          ),
                        ),
                        child: Text(
                          'Save Password',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.titleMedium),
                            fontWeight: FontWeight.bold,
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
