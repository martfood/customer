import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import '../checkout/add_card_bottom_sheet.dart';

class ProfilePaymentMethodsScreen extends StatefulWidget {
  const ProfilePaymentMethodsScreen({super.key});

  @override
  State<ProfilePaymentMethodsScreen> createState() => _ProfilePaymentMethodsScreenState();
}

class _ProfilePaymentMethodsScreenState extends State<ProfilePaymentMethodsScreen> {
  bool _isLoading = false;

  String _formatCurrency(double amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final decimal = parts.last;
    final chars = whole.split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(',');
      buffer.write(chars[i]);
    }
    return '${buffer.toString().split('').reversed.join()}.$decimal';
  }

  String _displayBrand(Map<String, dynamic> card) {
    final brand = (card['brand'] ?? card['cardType'] ?? 'Card').toString();
    if (brand.isEmpty) return 'Card';
    return brand[0].toUpperCase() + brand.substring(1);
  }

  Future<void> _addNewCard(String email) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (email.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('User email not found. Please log in again.')),
      );
      return;
    }

    final result = await showAddCardBottomSheet(
      context: context,
      email: email,
      amountInNaira: 50.0,
    );

    if (!mounted || result == null) return;

    final auth = result['authorization'] as Map<String, dynamic>?;
    if (auth != null) {
      final newCard = {
        'authorizationCode': auth['authorization_code'],
        'cardType': auth['card_type'],
        'last4': auth['last4'],
        'expMonth': auth['exp_month']?.toString(),
        'expYear': auth['exp_year']?.toString(),
        'brand': auth['brand'],
      };

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .update({
          'savedCards': FieldValue.arrayUnion([newCard]),
        });
      }

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Card added successfully!')),
        );
      }
    } else {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Card verification incomplete. Please try again.')),
        );
      }
    }
  }

  Future<void> _removeCard(Map<String, dynamic> card) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
      final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
      final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

      final confirm = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: sheetBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        builder: (context) => Padding(
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
                'Remove Saved Card',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                'Are you sure you want to remove this card (${_displayBrand(card)} ending in ${card['last4'] ?? '••••'}) from your account?',
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
                      onPressed: () => Navigator.pop(context, false),
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
                          fontSize:
                              AppTypography.font(AppFontSizes.bodyMedium),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 54.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Remove',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize:
                              AppTypography.font(AppFontSizes.bodyMedium),
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

      if (confirm == true) {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .update({
          'savedCards': FieldValue.arrayRemove([card]),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Card removed successfully.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Please log in to view payment methods',
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextColor),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Payment Methods',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: purpleColor))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('customers').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: purpleColor));
                }

                final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final balance = (data['balance'] ?? 0.0) as double;
                final savedCards = List<Map<String, dynamic>>.from(
                  (data['savedCards'] as List<dynamic>? ?? [])
                      .map((c) => Map<String, dynamic>.from(c)),
                );
                final email = (data['email'] ?? '').toString();

                return SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
                          children: [
                            _buildSectionHeader(
                              context: context,
                              title: 'Available methods',
                              subtitle: 'Choose how you want to manage payments',
                            ),
                            SizedBox(height: 12.h),
                            _buildSurface(
                              context: context,
                              child: Column(
                                children: [
                                  _buildMethodItem(
                                    context: context,
                                    icon: LucideIcons.wallet,
                                    title: 'MartFood Wallet',
                                    subtitle:
                                        'Current balance: ₦${_formatCurrency(balance)}',
                                    badge: 'Wallet',
                                    purpleColor: purpleColor,
                                  ),
                                  SizedBox(height: 12.h),
                                  _buildMethodItem(
                                    context: context,
                                    icon: LucideIcons.building2,
                                    title: 'Bank Transfer',
                                    subtitle:
                                        'Direct transfer to your preferred bank account',
                                    badge: 'Transfer',
                                    purpleColor: purpleColor,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24.h),
                            _buildSectionHeader(
                              context: context,
                              title: 'Saved cards',
                              subtitle: savedCards.isEmpty
                                  ? 'You have not added any cards yet'
                                  : 'Manage the cards linked to your account',
                            ),
                            SizedBox(height: 12.h),
                            if (savedCards.isEmpty)
                              _buildEmptyCardsState(context, purpleColor)
                            else
                              _buildSurface(
                                context: context,
                                child: Column(
                                  children: [
                                    for (var i = 0; i < savedCards.length; i++) ...[
                                      _buildMethodItem(
                                        context: context,
                                        icon: LucideIcons.creditCard,
                                        title:
                                            '${_displayBrand(savedCards[i])} (•••• ${savedCards[i]['last4'] ?? '••••'})',
                                        subtitle:
                                            'Expires ${savedCards[i]['expMonth']}/${savedCards[i]['expYear']}',
                                        badge: 'Saved',
                                        purpleColor: purpleColor,
                                        trailing: IconButton(
                                          icon: const Icon(
                                            LucideIcons.trash2,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                          onPressed: () => _removeCard(savedCards[i]),
                                        ),
                                      ),
                                      if (i != savedCards.length - 1)
                                        Padding(
                                          padding: EdgeInsets.symmetric(vertical: 12.h),
                                          child: Divider(
                                            height: 1,
                                            color: borderColor,
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
                        decoration: BoxDecoration(
                          color: cardBg,
                          border: Border(
                            top: BorderSide(
                              color: borderColor,
                            ),
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: ElevatedButton(
                            onPressed: () => _addNewCard(email),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 58.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Add New Card',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }



  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: primaryTextColor,
            fontSize: AppTypography.font(AppFontSizes.headlineSmall),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          style: TextStyle(
            color: mutedTextColor,
            fontSize: AppTypography.font(AppFontSizes.bodySmall),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSurface({
    required BuildContext context,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: child,
    );
  }

  Widget _buildEmptyCardsState(BuildContext context, Color purpleColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

    return _buildSurface(
      context: context,
      child: Column(
        children: [
          Container(
            width: 58.w,
            height: 58.w,
            decoration: BoxDecoration(
              color: purpleColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(
              LucideIcons.creditCard,
              color: purpleColor,
              size: 26.sp,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'No saved cards yet',
            style: TextStyle(
              color: primaryTextColor,
              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Add a card to speed up top ups and future payments.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color purpleColor,
    String? badge,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

    return Container(
      padding: EdgeInsets.all(16.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: purpleColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: purpleColor, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: purpleColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: purpleColor,
                            fontSize: AppTypography.font(AppFontSizes.caption),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    color: mutedTextColor,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
