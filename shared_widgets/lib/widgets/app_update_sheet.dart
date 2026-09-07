import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';

class AppUpdateSheet extends StatelessWidget {
  final String latestVersion;
  final String title;
  final String message;
  final List<String> releaseNotes;
  final bool isMandatory;
  final VoidCallback onUpdateNow;
  final VoidCallback? onRemindLater;

  const AppUpdateSheet({
    super.key,
    required this.latestVersion,
    required this.title,
    required this.message,
    this.releaseNotes = const [],
    this.isMandatory = false,
    required this.onUpdateNow,
    this.onRemindLater,
  });

  /// Displays the update prompt as a centered popup dialog with blurred background
  static Future<void> show(
    BuildContext context, {
    required String latestVersion,
    required String title,
    required String message,
    List<String> releaseNotes = const [],
    bool isMandatory = false,
    required VoidCallback onUpdateNow,
    VoidCallback? onRemindLater,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        return PopScope(
          canPop: !isMandatory,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding:
                  EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
              child: AppUpdateSheet(
                latestVersion: latestVersion,
                title: title,
                message: message,
                releaseNotes: releaseNotes,
                isMandatory: isMandatory,
                onUpdateNow: onUpdateNow,
                onRemindLater: onRemindLater,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF64748B);

    return Responsive.maxContainer(
      context: context,
      maxWidth: 420,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: borderColor, width: 1),
        ),
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 22.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Close Icon Row (only if not mandatory)
              if (!isMandatory) ...[
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onRemindLater?.call();
                    },
                    child: Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppTheme.lightInputFill,
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Center(
                        child: Icon(
                          LucideIcons.x,
                          size: 16.sp,
                          color: mutedTextColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(height: 4.h),
              ],

              // Header Rocket Badge
              Container(
                width: 62.w,
                height: 62.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: purpleColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: purpleColor.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.sparkles,
                    size: 28.sp,
                    color: purpleColor,
                  ),
                ),
              ),
              SizedBox(height: 14.h),

              // Title
              Text(
                title.isNotEmpty ? title : 'New Update Available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 8.h),

              // Version Badges Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppTheme.lightInputFill,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Text(
                      'v$latestVersion',
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.caption),
                        fontWeight: FontWeight.w700,
                        color: purpleColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // Update description text
              if (message.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                      color: mutedTextColor,
                      height: 1.45,
                    ),
                  ),
                ),

              // Release Notes List (if provided)
              if (releaseNotes.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's New",
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      ...releaseNotes.map(
                        (note) => Padding(
                          padding: EdgeInsets.only(bottom: 6.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: EdgeInsets.only(top: 3.h, right: 8.w),
                                width: 14.w,
                                height: 14.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: purpleColor.withValues(alpha: 0.15),
                                ),
                                child: Center(
                                  child: Icon(
                                    LucideIcons.check,
                                    size: 9.sp,
                                    color: purpleColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  note,
                                  style: TextStyle(
                                    fontSize: AppTypography.font(
                                        AppFontSizes.caption),
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : const Color(0xFF334155),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 22.h),

              // Action Buttons
              // Primary "Update Now"
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: onUpdateNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Update Now',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Icon(
                        LucideIcons.arrowUpRight,
                        size: 16.sp,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),

              // Optional "Remind me Later" (only if isMandatory == false)
              if (!isMandatory) ...[
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRemindLater?.call();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: mutedTextColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22.r),
                        side: BorderSide(color: borderColor, width: 1),
                      ),
                    ),
                    child: Text(
                      'Remind me Later',
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodySmall),
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
