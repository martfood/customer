import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class CustomerPrivacyPolicyScreen extends StatelessWidget {
  const CustomerPrivacyPolicyScreen({super.key});

  static const String _fallbackContent = '''1. Information We Collect
MartFood collects information you provide directly, such as your full name, email address, phone number, delivery addresses, payment preferences, and order history. We also collect precise location data when you place an order to ensure accurate dispatch and real-time delivery tracking.

2. How We Use Your Information
We use your data to:
• Process and fulfill your food, grocery, and pharmacy orders.
• Connect you with nearby vendors and dispatch assigned delivery riders.
• Process payments securely through our authorized payment processors.
• Send essential order status notifications, receipts, and customer support messages.
• Improve platform recommendations and user experience.

3. Sharing of Information
We share relevant delivery details (such as your first name, delivery address, and contact number) strictly with the assigned vendor and delivery rider solely for fulfilling your order. We never sell your personal data to third parties.

4. Data Security & Storage
We implement industry-standard encryption protocols and secure database controls to safeguard your personal and transaction data.

5. Your Rights & Account Deletion
You can update your personal information at any time in your profile settings. You also have the right to permanently delete your MartFood account and associated data directly from the Settings screen.''';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFF0E6FF);
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
          'Privacy Policy',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('settings')
              .doc('legal')
              .snapshots(),
          builder: (context, snapshot) {
            String title = 'Customer Privacy Policy';
            String lastUpdated = 'August 15, 2026';
            String content = _fallbackContent;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null && data['customerPrivacyPolicy'] != null) {
                final policy = data['customerPrivacyPolicy'] as Map<String, dynamic>;
                title = policy['title']?.toString() ?? title;
                lastUpdated = policy['lastUpdated']?.toString() ?? lastUpdated;
                content = policy['content']?.toString() ?? content;
              }
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: purpleColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.calendar,
                                    size: 13.sp,
                                    color: purpleColor,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'Updated $lastUpdated',
                                    style: TextStyle(
                                      color: purpleColor,
                                      fontSize: AppTypography.font(AppFontSizes.caption),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 14.h),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          content,
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                            color: primaryTextColor.withValues(alpha: 0.90),
                            height: 1.65,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
