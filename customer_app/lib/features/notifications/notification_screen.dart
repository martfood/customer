import 'package:flutter/material.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notification',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.headlineMedium),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz,
                color: isDark ? Colors.white : Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        children: [
          _buildNotificationItem(
            context: context,
            icon: Icons.cancel_outlined,
            iconColor: Colors.red,
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            title: 'Orders Cancelled!',
            time: '19 Dec, 2022 | 20:50 PM',
            description:
                'You have canceled an order at Burger Hut. We apologize for your inconvenience. We will try to improve our service next time 🥲',
            isNew: true,
          ),
          _buildNotificationItem(
            context: context,
            icon: LucideIcons.shoppingBag,
            iconColor: Colors.green,
            backgroundColor: Colors.green.withValues(alpha: 0.1),
            title: 'Orders Successful!',
            time: '19 Dec, 2022 | 20:49 PM',
            description:
                'You have placed an order at Burger Hut and paid ₦24,000. Your food will arrive soon. Enjoy our services 😋',
            isNew: true,
          ),
          _buildNotificationItem(
            context: context,
            icon: LucideIcons.box,
            iconColor: Colors.orange,
            backgroundColor: Colors.orange.withValues(alpha: 0.1),
            title: 'New Services Available!',
            time: '14 Dec, 2022 | 10:52 AM',
            description:
                'You can now make multiple food orders at one time. You can also cancel your orders.',
            isNew: false,
          ),
          _buildNotificationItem(
            context: context,
            icon: LucideIcons.creditCard,
            iconColor: Colors.blue,
            backgroundColor: Colors.blue.withValues(alpha: 0.1),
            title: 'Credit Card Connected!',
            time: '12 Dec, 2022 | 15:38 PM',
            description:
                'Your credit card has been successfully linked with MartFood. Enjoy our services.',
            isNew: false,
          ),
          _buildNotificationItem(
            context: context,
            icon: Icons.person_outline,
            iconColor: Colors.green,
            backgroundColor: Colors.green.withValues(alpha: 0.1),
            title: 'Account Setup Successful!',
            time: '12 Dec, 2022 | 14:27 PM',
            description:
                'Your account creation is successful, you can now experience our services.',
            isNew: false,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String time,
    required String description,
    required bool isNew,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        if (isNew)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              'New',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            description,
            style: TextStyle(
              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
