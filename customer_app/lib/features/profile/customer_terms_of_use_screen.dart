import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class CustomerTermsOfUseScreen extends StatelessWidget {
  const CustomerTermsOfUseScreen({super.key});

  static const String _fallbackContent = '''1. Acceptance of Terms
By downloading, creating an account, or using the MartFood customer application, you agree to be bound by these Terms of Use and our Privacy Policy.

2. User Accounts
You are responsible for maintaining the confidentiality of your login credentials. You must provide accurate and up-to-date contact and delivery information.

3. Ordering & Payment
All orders placed on MartFood are subject to vendor acceptance and product availability. Payments are processed securely via MartFood E-Wallet, card payments, or designated cash/card on delivery where supported.

4. Deliveries & Delivery PIN
Upon delivery arrival, you will verify the handover using your 4-digit Delivery PIN displayed in your active order screen. Providing this PIN to the rider signifies successful order receipt.

5. Cancellations & Refunds
Orders may be cancelled prior to vendor confirmation. Once food preparation or dispatch has commenced, cancellations may incur a standard fee. Refund requests are reviewed promptly by MartFood Customer Support.

6. Prohibited Activities
Users must not engage in fraudulent ordering, abusive conduct towards riders or vendor personnel, or unauthorized reverse-engineering of platform systems.''';

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
          'Terms of Use',
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
            String title = 'Customer Terms of Use';
            String lastUpdated = 'August 15, 2026';
            String content = _fallbackContent;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null && data['customerTermsOfUse'] != null) {
                final terms = data['customerTermsOfUse'] as Map<String, dynamic>;
                title = terms['title']?.toString() ?? title;
                lastUpdated = terms['lastUpdated']?.toString() ?? lastUpdated;
                content = terms['content']?.toString() ?? content;
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
                            fontWeight: FontWeight.w400,
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
