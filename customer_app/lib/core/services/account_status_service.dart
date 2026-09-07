import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountSuspensionInfo {
  final bool isSuspended;
  final String reason;
  final String? suspendedUntil;
  final String? suspendedAt;

  const AccountSuspensionInfo({
    required this.isSuspended,
    this.reason = 'Account suspended by platform administration',
    this.suspendedUntil,
    this.suspendedAt,
  });
}

class AccountStatusService {
  /// Evaluates whether the customer account is actively suspended
  static bool isSuspended(Map<String, dynamic>? data) {
    if (data == null) return false;
    final status = data['status'] as String?;
    if (status != 'suspended') return false;

    final untilStr = data['suspendedUntil'] as String?;
    if (untilStr == null || untilStr.isEmpty) {
      return true; // Indefinite suspension
    }

    try {
      final untilDate = DateTime.parse(untilStr);
      // If current time is before the suspension end, it's still suspended
      return DateTime.now().isBefore(untilDate);
    } catch (_) {
      return true;
    }
  }

  /// Parses suspension metadata
  static AccountSuspensionInfo parseSuspension(Map<String, dynamic>? data) {
    if (data == null) return const AccountSuspensionInfo(isSuspended: false);
    final active = isSuspended(data);
    return AccountSuspensionInfo(
      isSuspended: active,
      reason: (data['suspensionReason'] ?? 'Violation of Terms of Service')
          .toString(),
      suspendedUntil: data['suspendedUntil'] as String?,
      suspendedAt: data['suspendedAt'] as String?,
    );
  }

  /// Formats the suspended until date nicely
  static String formatSuspensionExpiry(String? isoString) {
    if (isoString == null || isoString.isEmpty) {
      return 'Indefinite (Subject to Admin Review)';
    }
    try {
      final d = DateTime.parse(isoString).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final month = months[d.month - 1];
      final hour = d.hour.toString().padLeft(2, '0');
      final minute = d.minute.toString().padLeft(2, '0');
      return '$month ${d.day}, ${d.year} at $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }

  /// Displays the Account Suspended Bottom Sheet strictly adhering to AGENTS.md
  static Future<void> showSuspensionSheet(
    BuildContext context, {
    required String reason,
    String? suspendedUntil,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF64748B);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final expiryFormatted = formatSuspensionExpiry(suspendedUntil);

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        return Responsive.maxContainer(
          context: context,
          maxWidth: 520,
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              border: Border.all(color: borderColor, width: 1),
            ),
            padding: EdgeInsets.only(
              left: 24.w,
              right: 24.w,
              top: 14.h,
              bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  (MediaQuery.of(ctx).padding.bottom > 0
                      ? MediaQuery.of(ctx).padding.bottom + 12.h
                      : 24.h),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Drag handle
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 18.h),

                  // Alert Badge
                  Container(
                    width: 64.w,
                    height: 64.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                      border: Border.all(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.shieldAlert,
                        size: 30.sp,
                        color: const Color(0xFFE11D48),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Title
                  Text(
                    'Account Suspended',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 8.h),

                  // Subtitle
                  Text(
                    'Your MartFood account has been suspended by platform administration.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                      color: mutedTextColor,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Suspension Details Box
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF27272A).withValues(alpha: 0.6)
                          : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.info,
                              size: 15.sp,
                              color: const Color(0xFFE11D48),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Suspension Reason',
                              style: TextStyle(
                                fontSize:
                                    AppTypography.font(AppFontSizes.caption),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFE11D48),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          reason,
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodySmall),
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Divider(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                          height: 1,
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.clock,
                              size: 14.sp,
                              color: mutedTextColor,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Duration: ',
                              style: TextStyle(
                                fontSize:
                                    AppTypography.font(AppFontSizes.caption),
                                fontWeight: FontWeight.bold,
                                color: mutedTextColor,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                expiryFormatted,
                                style: TextStyle(
                                  fontSize:
                                      AppTypography.font(AppFontSizes.caption),
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Contact Support Button
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () async {
                        final uri = Uri.parse(
                            'mailto:support@martfooddelivery.com?subject=Appeal%20Account%20Suspension');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
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
                          Icon(LucideIcons.mail,
                              size: 16.sp, color: Colors.white),
                          SizedBox(width: 8.w),
                          Text(
                            'Appeal / Contact Support',
                            style: TextStyle(
                              fontSize:
                                  AppTypography.font(AppFontSizes.bodyMedium),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    height: 44.h,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: mutedTextColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22.r),
                          side: BorderSide(color: borderColor, width: 1),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          fontWeight: FontWeight.w600,
                          color: mutedTextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
