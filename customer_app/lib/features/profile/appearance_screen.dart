import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import '../../main.dart';
import '../auth/auth_error_handler.dart';
import '../auth/email_service.dart';
import 'change_email_bottom_sheet.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() {});
    ThemeManager.themeModeNotifier.value = mode;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final modeStr = mode == ThemeMode.dark
            ? 'dark'
            : (mode == ThemeMode.light ? 'light' : 'system');
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .update({'themeMode': modeStr});
      } catch (e) {
        debugPrint('Error updating theme setting in Firestore: $e');
      }
    }
  }

  void _showAppearanceBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final optionBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF7F8FC);
    final optionBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      elevation: 0,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) {
        final currentMode = ThemeManager.themeModeNotifier.value;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildOptionTile({
              required String title,
              required IconData icon,
              required ThemeMode mode,
            }) {
              final isSelected = currentMode == mode;

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      _setThemeMode(mode);
                      Navigator.pop(sheetContext);
                    },
                    borderRadius: BorderRadius.circular(18.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? purpleColor.withValues(alpha: 0.12)
                            : optionBg,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: isSelected ? purpleColor : optionBorder,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? purpleColor
                                  : (isDark
                                      ? Colors.grey[800]
                                      : const Color(0xFFEFEFF4)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              color: isSelected ? Colors.white : purpleColor,
                              size: 20.sp,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? purpleColor : primaryTextColor,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: purpleColor,
                              size: 22.sp,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24.w, 14.h, 24.w, 36.h),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : const Color(0xFFDCDCE0),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 28.h),
                  Icon(
                    Icons.palette_outlined,
                    size: 64.sp,
                    color: purpleColor,
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Appearance Mode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(22),
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Choose your preferred theme appearance for MartFood.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      fontWeight: FontWeight.w500,
                      color: mutedTextColor,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  buildOptionTile(
                    title: 'Light Mode',
                    icon: Icons.light_mode_outlined,
                    mode: ThemeMode.light,
                  ),
                  buildOptionTile(
                    title: 'Dark Mode',
                    icon: Icons.dark_mode_outlined,
                    mode: ThemeMode.dark,
                  ),
                  buildOptionTile(
                    title: 'System Default',
                    icon: Icons.settings_suggest_outlined,
                    mode: ThemeMode.system,
                  ),
                  SizedBox(height: 8.h),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showForgotPasswordBottomSheet(String initialEmail) {
    final emailController = TextEditingController(text: initialEmail);
    bool dialogLoading = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final fieldBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.w,
                right: 24.w,
                top: 16.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Enter your email address and we will send you a 6-digit OTP code to reset your password.',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
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
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(
                        color: textColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter email address',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
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
                  SizedBox(height: 24.h),
                  dialogLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: purpleColor,
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 52.h,
                          child: ElevatedButton(
                            onPressed: () async {
                              final email = emailController.text.trim();
                              if (email.isEmpty) {
                                AuthErrorHandler.showError(
                                  context,
                                  'Please enter your email address',
                                );
                                return;
                              }

                              setDialogState(() {
                                dialogLoading = true;
                              });

                              final otpCode =
                                  (100000 + Random().nextInt(900000)).toString();

                              try {
                                final normEmail = email.trim().toLowerCase();
                                final customerQuery = await FirebaseFirestore.instance
                                    .collection('customers')
                                    .where('email', isEqualTo: normEmail)
                                    .get()
                                    .timeout(const Duration(seconds: 5));

                                if (customerQuery.docs.isEmpty) {
                                  throw 'No customer account is registered with this email address.';
                                }

                                await FirebaseFirestore.instance
                                    .collection('password_resets')
                                    .doc(normEmail)
                                    .set({
                                  'otp': otpCode,
                                  'expiresAt': Timestamp.fromDate(
                                    DateTime.now().add(const Duration(minutes: 15)),
                                  ),
                                }).timeout(const Duration(seconds: 5));

                                final sent = await EmailService.sendPasswordResetOtp(
                                  email,
                                  otpCode,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (sent) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Verification code sent to $email',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    AuthErrorHandler.showError(
                                      context,
                                      'Failed to send email. Please try again.',
                                    );
                                  }
                                  context.push('/forgot-password-otp', extra: {
                                    'email': email,
                                    'otp': otpCode,
                                  });
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  AuthErrorHandler.showError(context, e);
                                }
                              } finally {
                                setDialogState(() {
                                  dialogLoading = false;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Send Code',
                              style: TextStyle(
                                fontSize: AppTypography.font(AppFontSizes.titleMedium),
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
      },
    );
  }

  void _showLogoutBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => Padding(
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
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: purpleColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.logOut,
                color: purpleColor,
                size: 28.sp,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Sign Out',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Are you sure you want to sign out of your account?',
              style: TextStyle(
                color: mutedTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 28.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF27272A)
                          : const Color(0xFFF3F4F7),
                      foregroundColor: primaryTextColor,
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final router = GoRouter.of(context);
                      Navigator.pop(sheetContext);
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        router.go('/login');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: dialogBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.trash2,
                  color: Colors.red,
                  size: 28.sp,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Delete Account',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.',
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 28.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF27272A)
                            : const Color(0xFFF3F4F7),
                        foregroundColor: primaryTextColor,
                        minimumSize: Size(double.infinity, 50.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final router = GoRouter.of(context);
                        Navigator.pop(dialogContext);
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('customers')
                                .doc(user.uid)
                                .delete();
                            await user.delete();
                          } catch (e) {
                            debugPrint('Error deleting account: $e');
                          }
                        }
                        if (mounted) {
                          router.go('/login');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFF0E6FF);
    final dividerColor = isDark ? AppTheme.darkBorder : const Color(0xFFF5EEFF);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.all(8.w),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.grey[800]! : const Color(0xFFE9EAF0),
                width: 1,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back, color: purpleColor, size: 20.sp),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Settings',
          style: TextStyle(
            color: purpleColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
          child: Column(
            children: [
              // ── Grouped Settings Card (Dark Mode, Help/FAQs, Sign out) ──
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  children: [
                    // Row 1: Appearance Mode
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showAppearanceBottomSheet(context),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24.r),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.palette_outlined,
                                  color: purpleColor,
                                  size: 20.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  'Appearance Mode',
                                  style: TextStyle(
                                    fontSize:
                                        AppTypography.font(AppFontSizes.bodyLarge),
                                    fontWeight: FontWeight.w800,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: purpleColor,
                                size: 22.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: dividerColor,
                      indent: 64.w,
                      endIndent: 16.w,
                    ),

                    // Row 2: Change Email Address
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          showChangeEmailBottomSheet(context);
                        },
                        borderRadius: BorderRadius.zero,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.alternate_email,
                                  color: purpleColor,
                                  size: 20.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  'Change Email Address',
                                  style: TextStyle(
                                    fontSize:
                                        AppTypography.font(AppFontSizes.bodyLarge),
                                    fontWeight: FontWeight.w800,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: purpleColor,
                                size: 22.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: dividerColor,
                      indent: 64.w,
                      endIndent: 16.w,
                    ),

                    // Row 3: Reset Password
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final user = FirebaseAuth.instance.currentUser;
                          _showForgotPasswordBottomSheet(user?.email ?? '');
                        },
                        borderRadius: BorderRadius.zero,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.key,
                                  color: purpleColor,
                                  size: 20.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  'Reset Password',
                                  style: TextStyle(
                                    fontSize:
                                        AppTypography.font(AppFontSizes.bodyLarge),
                                    fontWeight: FontWeight.w800,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: purpleColor,
                                size: 22.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: dividerColor,
                      indent: 64.w,
                      endIndent: 16.w,
                    ),

                    // Row 3: Sign out
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showLogoutBottomSheet(context),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(24.r),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.logout,
                                  color: purpleColor,
                                  size: 20.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  'Sign out',
                                  style: TextStyle(
                                    fontSize:
                                        AppTypography.font(AppFontSizes.bodyLarge),
                                    fontWeight: FontWeight.w800,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: purpleColor,
                                size: 22.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Standalone Bottom Action Row: Delete account ─────────────
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showDeleteAccountDialog(context),
                  borderRadius: BorderRadius.circular(24.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44.w,
                          height: 44.w,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20.sp,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Text(
                            'Delete account',
                            style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                              fontWeight: FontWeight.w800,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: purpleColor,
                          size: 22.sp,
                        ),
                      ],
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
