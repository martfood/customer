import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  String _formatTimestamp(dynamic createdAt) {
    if (createdAt == null) return 'Just now';

    DateTime dt;
    if (createdAt is Timestamp) {
      dt = createdAt.toDate();
    } else if (createdAt is String) {
      dt = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else {
      return 'Just now';
    }

    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      final months = [
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
        'Dec',
      ];
      final monthStr = months[dt.month - 1];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minStr = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $monthStr, ${dt.year} | $hour:$minStr $ampm';
    }
  }

  Map<String, dynamic> _getNotificationStyle({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required bool isDark,
    required Color purpleColor,
  }) {
    final lowerTitle = title.toLowerCase();
    final lowerBody = body.toLowerCase();
    final type = (data['type'] ?? '').toString().toLowerCase();
    final action = (data['action'] ?? '').toString().toLowerCase();

    if (action == 'deduct' ||
        lowerTitle.contains('debited') ||
        lowerTitle.contains('deduct') ||
        lowerBody.contains('debited')) {
      return {
        'icon': LucideIcons.wallet,
        'iconColor': isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
        'bgColor': isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
      };
    } else if (type == 'wallet' ||
        lowerTitle.contains('wallet') ||
        lowerTitle.contains('credit') ||
        lowerTitle.contains('top up') ||
        lowerTitle.contains('top-up') ||
        lowerBody.contains('credited')) {
      return {
        'icon': LucideIcons.wallet,
        'iconColor': isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
        'bgColor': isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
      };
    } else if (lowerTitle.contains('cancel') || lowerBody.contains('cancel')) {
      return {
        'icon': Icons.cancel_outlined,
        'iconColor': isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
        'bgColor': isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
      };
    } else if (lowerTitle.contains('order') || type == 'order') {
      return {
        'icon': LucideIcons.shoppingBag,
        'iconColor': purpleColor,
        'bgColor': purpleColor.withValues(alpha: 0.12),
      };
    }

    return {
      'icon': LucideIcons.bell,
      'iconColor': purpleColor,
      'bgColor': purpleColor.withValues(alpha: 0.12),
    };
  }

  Future<void> _markAllAsRead(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
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
            'Notifications',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: AppTypography.font(AppFontSizes.headlineMedium),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Please log in to view notifications',
            style: TextStyle(
              color: primaryTextColor,
              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.headlineMedium),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert,
                color: isDark ? Colors.white : Colors.black),
            onSelected: (val) {
              if (val == 'read_all') {
                _markAllAsRead(user.uid);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'read_all',
                child: Row(
                  children: [
                    Icon(LucideIcons.checkCheck, size: 18.sp, color: purpleColor),
                    SizedBox(width: 8.w),
                    Text(
                      'Mark all as read',
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Responsive.maxContainer(
        context: context,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('customers')
              .doc(user.uid)
              .collection('notifications')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: purpleColor),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72.w,
                        height: 72.w,
                        decoration: BoxDecoration(
                          color: purpleColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.bellOff,
                          color: purpleColor,
                          size: 32.sp,
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'You have no notifications right now. Any wallet updates or order status alerts will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          color: mutedTextColor,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              itemCount: docs.length,
              separatorBuilder: (context, index) => SizedBox(height: 14.h),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final title = (data['title'] ?? 'Notification').toString();
                final body = (data['body'] ?? data['description'] ?? '').toString();
                final isRead = data['read'] as bool? ?? false;
                final notifData =
                    data['data'] as Map<String, dynamic>? ?? {};
                final createdAt = data['createdAt'];
                final time = _formatTimestamp(createdAt);

                final style = _getNotificationStyle(
                  title: title,
                  body: body,
                  data: notifData,
                  isDark: isDark,
                  purpleColor: purpleColor,
                );

                return InkWell(
                  onTap: () {
                    if (!isRead) {
                      doc.reference.update({'read': true}).catchError((_) {});
                    }
                  },
                  borderRadius: BorderRadius.circular(20.r),
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: !isRead
                            ? purpleColor.withValues(alpha: 0.4)
                            : borderColor,
                        width: !isRead ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48.w,
                              height: 48.w,
                              decoration: BoxDecoration(
                                color: style['bgColor'] as Color,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                style['icon'] as IconData,
                                color: style['iconColor'] as Color,
                                size: 22.sp,
                              ),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: AppTypography.font(
                                                AppFontSizes.bodyLarge),
                                            fontWeight: FontWeight.bold,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          margin: EdgeInsets.only(left: 8.w),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius:
                                                BorderRadius.circular(6.r),
                                          ),
                                          child: Text(
                                            'New',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: AppTypography.font(
                                                  AppFontSizes.caption),
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
                                      fontSize: AppTypography.font(
                                          AppFontSizes.caption),
                                      color: mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (body.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                              color: mutedTextColor,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
