import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/skeleton_loader.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
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
    final monthStr = months[date.month - 1];
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minStr = date.minute.toString().padLeft(2, '0');
    return '$monthStr ${date.day}, ${date.year} | $hour:$minStr $ampm';
  }

  String _formatCurrency(num value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Please login to view transaction history',
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
        centerTitle: true,
        leading: Padding(
          padding: EdgeInsets.all(8.w),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
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
        title: Text(
          'Transaction History',
          style: TextStyle(
            color: purpleColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Responsive.maxContainer(
        context: context,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('customers')
              .doc(user.uid)
              .collection('transactions')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 28.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48.w,
                          height: 48.w,
                          decoration: BoxDecoration(
                            color: purpleColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Icon(
                            LucideIcons.receiptText,
                            color: purpleColor,
                            size: 22.sp,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'All transactions',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Browse your wallet activity from latest to oldest.',
                                style: TextStyle(
                                  color: mutedTextColor,
                                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(18.w),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: null,
                    ),
                    child: _buildTransactionList(
                      context: context,
                      snapshot: snapshot,
                      primaryTextColor: primaryTextColor,
                      mutedTextColor: mutedTextColor,
                      purpleColor: purpleColor,
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

  Widget _buildTransactionList({
    required BuildContext context,
    required AsyncSnapshot<QuerySnapshot> snapshot,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required Color purpleColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFEFF1F6);

    if (!snapshot.hasData) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (context, index) => SizedBox(height: 12.h),
        itemBuilder: (context, index) =>
            SkeletonLoader.transactionItem(context: context),
      );
    }

    final docs = snapshot.data!.docs;
    if (docs.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 34.h, horizontal: 12.w),
        child: Column(
          children: [
            Container(
              width: 58.w,
              height: 58.w,
              decoration: BoxDecoration(
                color: purpleColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.receipt,
                color: purpleColor,
                size: 26.sp,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'No transactions yet',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Your completed top ups and order charges will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (context, index) => Divider(
        color: borderColor,
        height: 22.h,
      ),
      itemBuilder: (context, index) {
        final tx = docs[index].data() as Map<String, dynamic>;
        final amountVal = (tx['amount'] as num?) ?? 0;
        final isExpense = tx['isExpense'] as bool? ?? true;
        final imageUrl = tx['imageUrl']?.toString();

        return _buildTransactionItem(
          context: context,
          title: (tx['title'] ?? 'Transaction').toString(),
          time: _formatTimestamp(tx['createdAt'] as Timestamp?),
          amount: '₦${_formatCurrency(amountVal)}',
          type: (tx['type'] ?? (isExpense ? 'Orders' : 'Top up')).toString(),
          isExpense: isExpense,
          imageUrl: imageUrl,
          icon: isExpense ? LucideIcons.shoppingBag : LucideIcons.wallet,
          iconColor: isExpense ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
          purpleColor: purpleColor,
        );
      },
    );
  }

  Widget _buildTransactionItem({
    required BuildContext context,
    required String title,
    required String time,
    required String amount,
    required String type,
    required bool isExpense,
    String? imageUrl,
    IconData? icon,
    Color? iconColor,
    required Color purpleColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final chipBackground =
        (iconColor ?? purpleColor).withValues(alpha: 0.12);

    return Row(
      children: [
        Container(
          width: 54.w,
          height: 54.w,
          decoration: BoxDecoration(
            color: chipBackground,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Icon(
                      icon,
                      color: iconColor,
                      size: 22.sp,
                    ),
                  )
                : Icon(
                    icon,
                    color: iconColor,
                    size: 22.sp,
                  ),
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                time,
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: AppTypography.font(AppFontSizes.caption),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: chipBackground,
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpense
                        ? LucideIcons.arrowUpRight
                        : LucideIcons.arrowDownLeft,
                    size: 12.sp,
                    color: iconColor,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    type,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: AppTypography.font(AppFontSizes.caption),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
