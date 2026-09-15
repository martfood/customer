import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class GuestAuthPromptSheet extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const GuestAuthPromptSheet({
    super.key,
    this.title = 'Sign In Required',
    this.message = 'Please sign in or create an account to access this feature and continue.',
    this.icon = LucideIcons.lock,
  });

  static Future<void> show(
    BuildContext context, {
    String title = 'Sign In Required',
    String message = 'Please sign in or create an account to access this feature and continue.',
    IconData icon = LucideIcons.lock,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (ctx) => GuestAuthPromptSheet(
        title: title,
        message: message,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    return Responsive.maxContainer(
      context: context,
      maxWidth: 600,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 28.h),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBorder : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Icon Circle
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: purpleColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 30.sp,
                    color: purpleColor,
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 10.h),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 24.h),

              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/login');
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
                    'Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppTypography.font(AppFontSizes.titleMedium),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),

              // Create Account Button
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/signup');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: purpleColor,
                    elevation: 0,
                    side: BorderSide(color: purpleColor, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                  ),
                  child: Text(
                    'Create an Account',
                    style: TextStyle(
                      color: purpleColor,
                      fontSize: AppTypography.font(AppFontSizes.titleMedium),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),

              // Dismiss / Browse
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Continue Browsing',
                  style: TextStyle(
                    color: mutedTextColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w500,
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

/// Reusable empty/guest state widget to display on account-only screens
/// (Orders, Profile, Cart, Support) when the user is browsing as a guest.
class GuestPlaceholderView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryButtonText;
  final VoidCallback? onPrimaryPressed;

  const GuestPlaceholderView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.primaryButtonText = 'Sign In / Register',
    this.onPrimaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    return Responsive.maxContainer(
      context: context,
      maxWidth: 500,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 76.w,
                height: 76.w,
                decoration: BoxDecoration(
                  color: purpleColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 34.sp,
                    color: purpleColor,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 28.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: onPrimaryPressed ?? () => context.push('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                  ),
                  child: Text(
                    primaryButtonText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppTypography.font(AppFontSizes.titleMedium),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: OutlinedButton(
                  onPressed: () => context.push('/signup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: purpleColor,
                    elevation: 0,
                    side: BorderSide(color: purpleColor, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                  ),
                  child: Text(
                    'Create Account',
                    style: TextStyle(
                      color: purpleColor,
                      fontSize: AppTypography.font(AppFontSizes.titleMedium),
                      fontWeight: FontWeight.w700,
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
