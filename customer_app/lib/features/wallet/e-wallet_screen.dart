import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/skeleton_loader.dart';

class EWalletScreen extends StatefulWidget {
  final bool showSuccess;
  final double amount;
  const EWalletScreen({
    super.key,
    this.showSuccess = false,
    this.amount = 0.0,
  });

  @override
  State<EWalletScreen> createState() => _EWalletScreenState();
}

class _EWalletScreenState extends State<EWalletScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    if (widget.showSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTopUpSuccessBottomSheet();
      });
    }
  }

  void _showTopUpSuccessBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) {
        final isTablet = MediaQuery.of(context).size.width >= 600;

        return Padding(
          padding: isTablet
              ? EdgeInsets.symmetric(horizontal: 40.w, vertical: 24.h)
              : EdgeInsets.fromLTRB(28.w, 16.h, 28.w, 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 28.h),
              Icon(
                Icons.verified_rounded,
                size: isTablet ? 96.sp : 88.sp,
                color: purpleColor,
              ),
              SizedBox(height: 24.h),
              Text(
                'Topup successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(isTablet ? 28 : 26),
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Your wallet has been credited with ₦${_formatCurrency(widget.amount)}. You can now use your updated balance for instant orders.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  color: mutedTextColor,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 28.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 56.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Please login to view wallet',
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
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.all(8.w),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE9EAF0),
                width: 1,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back, color: purpleColor, size: 20.sp),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Wallet',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('customers').doc(user.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: purpleColor),
            );
          }

          final userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final fullName = (userData['fullName'] ?? 'User').toString();
          final balance = (userData['balance'] as num?) ?? 0;

          // Saved cards array from backend
          final savedCards = List<Map<String, dynamic>>.from(
            (userData['savedCards'] as List<dynamic>? ?? [])
                .map((c) => Map<String, dynamic>.from(c as Map)),
          );

          // Virtual bank details from backend if present
          final virtualAccount =
              userData['virtualAccount'] as Map<String, dynamic>?;
          final bankName = (userData['bankName'] ??
                  virtualAccount?['bankName'] ??
                  '')
              .toString();
          final accountNumber = (userData['accountNumber'] ??
                  virtualAccount?['accountNumber'] ??
                  '')
              .toString();

          return Responsive.maxContainer(
            context: context,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Redesigned Premium Wallet Balance Card with Decorative Circles & Card Display ──
                  _buildWalletHeroCard(
                    context: context,
                    fullName: fullName,
                    balance: balance,
                    bankName: bankName,
                    accountNumber: accountNumber,
                    savedCards: savedCards,
                    purpleColor: purpleColor,
                  ),
                  SizedBox(height: 24.h),

                  // ── Action Buttons Row: Add Money & Transaction History ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () => context.push('/wallet/top-up'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 32.w,
                            vertical: 14.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                        ),
                        child: Text(
                          'Add Money',
                          style: TextStyle(
                            fontSize:
                                AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.push('/transaction-history'),
                          borderRadius: BorderRadius.circular(20.r),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 10.h,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Transaction History',
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: AppTypography.font(
                                      AppFontSizes.bodyMedium,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Icon(
                                  LucideIcons.arrowRight,
                                  color: primaryTextColor,
                                  size: 18.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 28.h),

                  // ── Recent Transactions Header & List ──────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent transactions',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: AppTypography.font(
                                AppFontSizes.headlineSmall,
                              ),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Latest wallet movements',
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize:
                                  AppTypography.font(AppFontSizes.bodySmall),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  _buildTransactionsSection(
                    context: context,
                    userId: user.uid,
                    surfaceColor: surfaceColor,
                    mutedTextColor: mutedTextColor,
                    primaryTextColor: primaryTextColor,
                    purpleColor: purpleColor,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWalletHeroCard({
    required BuildContext context,
    required String fullName,
    required num balance,
    required String bankName,
    required String accountNumber,
    required List<Map<String, dynamic>> savedCards,
    required Color purpleColor,
  }) {
    final firstCard = savedCards.isNotEmpty ? savedCards.first : null;
    final last4 = (firstCard?['last4'] ?? '').toString();
    final cardBrand = (firstCard?['brand'] ?? 'Card').toString().toUpperCase();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: purpleColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: null,
      ),
      child: Stack(
        children: [
          // Decorative Circle Overlay 1 (Top Left)
          Positioned(
            top: -45.r,
            left: -45.r,
            child: Container(
              width: 140.r,
              height: 140.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),

          // Decorative Circle Overlay 2 (Bottom Right)
          Positioned(
            bottom: -55.r,
            right: -35.r,
            child: Container(
              width: 160.r,
              height: 160.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),

          // Card Content
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 22.h, 24.w, 22.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.wallet,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Wallet Balance',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Saved Card Pill inside Wallet Card if user added card
                    if (savedCards.isNotEmpty && last4.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.creditCard,
                              color: Colors.white,
                              size: 14.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              '$cardBrand •••• $last4',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AppTypography.font(AppFontSizes.caption),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  '₦${_formatCurrency(balance)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppTypography.font(32),
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Text(
                      bankName.isNotEmpty ? bankName : fullName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (accountNumber.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: Text(
                          '|',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        accountNumber,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSection({
    required BuildContext context,
    required String userId,
    required Color surfaceColor,
    required Color mutedTextColor,
    required Color primaryTextColor,
    required Color purpleColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: null,
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('customers')
            .doc(userId)
            .collection('transactions')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, txSnapshot) {
          if (!txSnapshot.hasData) {
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (context, index) => SizedBox(height: 12.h),
              itemBuilder: (context, index) =>
                  SkeletonLoader.transactionItem(context: context),
            );
          }

          final docs = txSnapshot.data!.docs;
          if (docs.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 30.h, horizontal: 12.w),
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
                    'Your wallet activity will appear here after your first top up or order.',
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
              color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF1F6),
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
        },
      ),
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
