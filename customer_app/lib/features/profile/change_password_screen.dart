import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  void _showResetSuccessBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: purpleColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mail_outline,
                color: purpleColor,
                size: 32.sp,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Reset Link Sent',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'A password reset link has been successfully delivered to your registered email address.',
              style: TextStyle(
                color: mutedTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 28.h),
            ElevatedButton(
              onPressed: () {
                context.pop(); // Close bottom sheet
                context.pop(); // Return to previous screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 56.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextColor),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Reset Password',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96.w,
                height: 96.w,
                decoration: BoxDecoration(
                  color: purpleColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_reset,
                  color: purpleColor,
                  size: 48.sp,
                ),
              ),
              SizedBox(height: 28.h),
              Text(
                'Send Password Reset Link?',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.headlineLarge),
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                'Click below to receive a secure link to reset your account password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  color: mutedTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 40.h),
              ElevatedButton(
                onPressed: () => _showResetSuccessBottomSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 56.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Send Reset Link',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
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
