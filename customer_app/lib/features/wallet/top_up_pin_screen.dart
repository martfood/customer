import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'paystack_service.dart';

class TopUpPinScreen extends StatefulWidget {
  final double amount;
  final String email;
  final String authorizationCode;
  final String cardDescription;

  const TopUpPinScreen({
    super.key,
    required this.amount,
    required this.email,
    required this.authorizationCode,
    required this.cardDescription,
  });

  @override
  State<TopUpPinScreen> createState() => _TopUpPinScreenState();
}

class _TopUpPinScreenState extends State<TopUpPinScreen> {
  String _pin = '';
  bool _isLoading = false;
  late final FocusNode _focusNode;
  late final TextEditingController _pinController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _pinController = TextEditingController();

    // Auto-focus the PIN field on screen load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_pin.length != 4) return;

    setState(() {
      _focusNode.unfocus();
      _isLoading = true;
    });

    // 1. Charge card via Paystack
    final success = await PaystackService.chargeSavedCard(
      email: widget.email,
      amountInNaira: widget.amount,
      authorizationCode: widget.authorizationCode,
    );

    if (!success) {
      setState(() {
        _isLoading = false;
        _pin = '';
        _pinController.clear();
      });
      if (mounted) {
        _focusNode.requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Card charge failed. Please try again or use another payment method.',
            ),
          ),
        );
      }
      return;
    }

    // 2. Credit Firestore wallet & log transaction
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef =
          FirebaseFirestore.instance.collection('customers').doc(user.uid);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          final currentBalance = (snapshot.data()?['balance'] ?? 0.0) as double;
          transaction.update(
            docRef,
            {'balance': currentBalance + widget.amount},
          );
        }
      });

      await docRef.collection('transactions').add({
        'title': 'Top Up E-Wallet',
        'amount': widget.amount,
        'type': 'Top up',
        'isExpense': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      context.go('/wallet?showSuccess=true&amount=${widget.amount}');
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
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

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
          'Enter PIN',
          style: TextStyle(
            color: purpleColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: purpleColor))
          : Responsive.maxContainer(
              context: context,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirm your payment',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'Enter your 4-digit PIN to complete the wallet top up.',
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: AppTypography.font(AppFontSizes.bodySmall),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 18.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20.w),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(24.r),
                              border: Border.all(color: borderColor, width: 1),
                              boxShadow: null,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Tap the boxes below to enter your PIN',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: mutedTextColor,
                                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 22.h),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Opacity(
                                      opacity: 0,
                                      child: SizedBox(
                                        height: 60.w,
                                        child: TextField(
                                          controller: _pinController,
                                          focusNode: _focusNode,
                                          keyboardType: TextInputType.number,
                                          maxLength: 4,
                                          showCursor: false,
                                          enableInteractiveSelection: false,
                                          decoration: const InputDecoration(
                                            counterText: '',
                                            border: InputBorder.none,
                                          ),
                                          onChanged: (val) {
                                            setState(() {
                                              _pin = val;
                                            });
                                            if (val.length == 4) {
                                              _processPayment();
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _focusNode.requestFocus,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(4, (index) {
                                          final hasDigit = _pin.length > index;
                                          final isActive = _pin.length == index;
                                          return Container(
                                            width: 62.w,
                                            height: 64.w,
                                            margin: EdgeInsets.symmetric(horizontal: 6.w),
                                            decoration: BoxDecoration(
                                              color: hasDigit
                                                  ? purpleColor.withValues(alpha: 0.12)
                                                  : (isDark
                                                      ? AppTheme.darkSurface
                                                      : const Color(0xFFF8F8FC)),
                                              border: Border.all(
                                                color: hasDigit || isActive
                                                    ? purpleColor
                                                    : borderColor,
                                                width: 1.8,
                                              ),
                                              borderRadius: BorderRadius.circular(18.r),
                                            ),
                                            child: Center(
                                              child: hasDigit
                                                  ? Container(
                                                      width: 14.w,
                                                      height: 14.w,
                                                      decoration: BoxDecoration(
                                                        color: primaryTextColor,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16.h),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _pin = '';
                                      _pinController.clear();
                                    });
                                    _focusNode.requestFocus();
                                  },
                                  child: Text(
                                    'Clear PIN',
                                    style: TextStyle(
                                      color: purpleColor,
                                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
                      child: Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(color: borderColor, width: 1),
                          boxShadow: null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Payment method',
                                  style: TextStyle(
                                    color: mutedTextColor,
                                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Flexible(
                                  child: Text(
                                    widget.cardDescription,
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: primaryTextColor,
                                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 14.h),
                            ElevatedButton(
                              onPressed: _pin.length == 4 ? _processPayment : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: purpleColor,
                                disabledBackgroundColor:
                                    purpleColor.withValues(alpha: 0.35),
                                foregroundColor: Colors.white,
                                minimumSize: Size(double.infinity, 56.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18.r),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
