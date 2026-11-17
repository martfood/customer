import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_theme.dart';

class VerificationBadgeContent {
  final String title;
  final String subtitle;
  final String description;

  const VerificationBadgeContent({
    required this.title,
    required this.subtitle,
    required this.description,
  });
}

class VerificationBadgesService {
  static Map<String, VerificationBadgeContent>? _cachedBadges;
  static DateTime? _lastFetchTime;

  static const Map<String, VerificationBadgeContent> defaultBadges = {
    'gold': VerificationBadgeContent(
      title: 'Gold Verification',
      subtitle: 'Official MartFood Partner',
      description:
          "This merchant is a fully verified, premier MartFood partner. We have completed a comprehensive verification suite, including in-person physical address audits, full regulatory corporate compliance checks, and signed operational excellence agreements. Shop with absolute confidence.",
    ),
    'standard': VerificationBadgeContent(
      title: 'Standard Verification',
      subtitle: 'Verified & Trusted Business',
      description:
          "This is a verified and highly trusted MartFood merchant. We have completed comprehensive checks on their official Corporate Affairs Commission (CAC) registrations and government-issued business identities. Verification of their physical storefront/address is currently in progress.",
    ),
    'basic': VerificationBadgeContent(
      title: 'Basic Verification',
      subtitle: 'Starter Business',
      description:
          "This merchant has completed our initial verification phase. We have successfully authenticated their contact details and banking information to ensure safe transactions. While CAC documentation is still pending, they are fully authorized to trade within standard operational limits.",
    ),
  };

  static Future<Map<String, VerificationBadgeContent>> getBadges() async {
    final now = DateTime.now();
    if (_cachedBadges != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 5) {
      return _cachedBadges!;
    }

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('settings')
          .doc('verification_badges')
          .get();

      if (docSnap.exists) {
        final data = docSnap.data() ?? {};
        final map = <String, VerificationBadgeContent>{};
        for (final tier in ['gold', 'standard', 'basic']) {
          final tierData = data[tier] as Map<String, dynamic>?;
          final def = defaultBadges[tier]!;
          map[tier] = VerificationBadgeContent(
            title: (tierData?['title'] as String?)?.trim().isNotEmpty == true
                ? tierData!['title'] as String
                : def.title,
            subtitle: (tierData?['subtitle'] as String?)?.trim().isNotEmpty == true
                ? tierData!['subtitle'] as String
                : def.subtitle,
            description: (tierData?['description'] as String?)?.trim().isNotEmpty == true
                ? tierData!['description'] as String
                : def.description,
          );
        }
        _cachedBadges = map;
        _lastFetchTime = now;
        return map;
      }
    } catch (_) {}

    return defaultBadges;
  }
}

Future<void> showVerificationBadgeBottomSheet(
  BuildContext context,
  Map<String, dynamic> vendorData,
) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final physicalVerification = vendorData['physicalVerification'];
  final physicalVerified = (physicalVerification is Map)
      ? physicalVerification['status']?.toString() == 'verified'
      : false;
  final docComplete =
      vendorData['verificationDocumentsComplete']?.toString() == 'true';
  final bpComplete =
      vendorData['businessProfileComplete']?.toString() == 'true';

  String tier = 'basic';
  Color tierColor = const Color(0xFF8E8E93); // Grey
  IconData icon = Icons.verified_rounded;

  if (physicalVerified) {
    tier = 'gold';
    tierColor = const Color(0xFFFFB300); // Gold
    icon = Icons.stars_rounded;
  } else if (docComplete) {
    tier = 'standard';
    tierColor = const Color(0xFF34C759); // Green
    icon = Icons.verified_user_rounded;
  } else if (bpComplete) {
    tier = 'basic';
    tierColor = const Color(0xFF8E8E93); // Grey
    icon = Icons.verified_rounded;
  }

  // Fetch customizable badges from Firestore or fallback
  final badgesMap = await VerificationBadgesService.getBadges();
  final badgeContent =
      badgesMap[tier] ?? VerificationBadgesService.defaultBadges[tier]!;

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
    elevation: 0,
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
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tierColor, size: 48.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            badgeContent.title,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            badgeContent.subtitle,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: tierColor,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            badgeContent.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5.sp,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(sheetContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: tierColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                'Got it',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
