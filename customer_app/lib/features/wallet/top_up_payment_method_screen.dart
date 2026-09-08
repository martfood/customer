import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'paystack_service.dart';
import 'paystack_webview_screen.dart';

class TopUpPaymentMethodScreen extends StatefulWidget {
  final double amount;
  const TopUpPaymentMethodScreen({super.key, required this.amount});

  @override
  State<TopUpPaymentMethodScreen> createState() =>
      _TopUpPaymentMethodScreenState();
}

class _TopUpPaymentMethodScreenState extends State<TopUpPaymentMethodScreen> {
  int _selectedIndex = 0; // 0 for Bank Transfer, 1+ for Saved Cards
  bool _isLoading = false;
  List<Map<String, dynamic>> _savedCards = [];
  String _customerEmail = '';

  String _formatCurrency(num value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  String _formatBrand(String brand) {
    if (brand.trim().isEmpty) return 'Card';
    final lower = brand.toLowerCase();
    if (lower.contains('visa')) return 'VISA';
    if (lower.contains('mastercard')) return 'MasterCard';
    if (lower.contains('verve')) return 'Verve';
    return brand[0].toUpperCase() + brand.substring(1);
  }

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _customerEmail = user.email ?? '';
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final cards = data['savedCards'] as List<dynamic>? ?? [];
        setState(() {
          _savedCards = cards.map((c) => Map<String, dynamic>.from(c)).toList();
        });
      }
    }
  }

  Future<void> _addNewCard() async {
    if (_customerEmail.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    // Initialize a 50 Naira card verification payment
    final res = await PaystackService.initializeTransaction(
      email: _customerEmail,
      amountInNaira: 50.0,
    );

    setState(() {
      _isLoading = false;
    });

    if (res == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Failed to initialize card verification. Please try again.')),
        );
      }
      return;
    }

    final authUrl = res['authorization_url'];
    final reference = res['reference'];

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaystackWebViewScreen(
            authorizationUrl: authUrl,
            reference: reference,
            onSuccess: (verifyResponse) async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final auth = verifyResponse['authorization'];
              if (auth != null) {
                final newCard = {
                  'authorizationCode': auth['authorization_code'],
                  'cardType': auth['card_type'],
                  'last4': auth['last4'],
                  'expMonth': auth['exp_month'].toString(),
                  'expYear': auth['exp_year'].toString(),
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
                  await _loadCustomerData();
                }
              }
              if (mounted) {
                navigator.pop(); // Close webview
                messenger.showSnackBar(
                  const SnackBar(content: Text('Card added successfully!')),
                );
              }
            },
            onCancel: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Card verification cancelled/failed.')),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _handleContinue() async {
    if (_selectedIndex == 0) {
      // Bank Transfer Flow - direct bottom sheet without WebView
      setState(() {
        _isLoading = true;
      });

      final bankAcc = await PaystackService.createBankTransferAccount(
        email: _customerEmail.isNotEmpty ? _customerEmail : 'customer@martfood.com',
        amountInNaira: widget.amount,
      );

      setState(() {
        _isLoading = false;
      });

      if (bankAcc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not generate bank transfer account. Please try again or choose another payment method.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final String bankName = bankAcc['bank_name'] ?? 'N/A';
      final String accountName = bankAcc['account_name'] ?? 'N/A';
      final String accountNumber = bankAcc['account_number'] ?? 'N/A';
      final String reference = bankAcc['reference'] ?? '';

      if (mounted) {
        _showBankTransferBottomSheet(
          bankName: bankName,
          accountName: accountName,
          accountNumber: accountNumber,
          reference: reference,
        );
      }
    } else {
      // Saved Card Flow
      final selectedCard = _savedCards[_selectedIndex - 1];
      context.push('/wallet/top-up/pin', extra: {
        'amount': widget.amount,
        'email': _customerEmail,
        'authorizationCode': selectedCard['authorizationCode'],
        'cardDescription':
            "${selectedCard['brand']} (${selectedCard['last4']})",
      });
    }
  }

  void _showBankTransferBottomSheet({
    required String bankName,
    required String accountName,
    required String accountNumber,
    required String reference,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final cardBgColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    bool isAccountCopied = false;
    bool isVerifying = false;
    String? verificationError;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      elevation: 0,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isTablet = MediaQuery.of(context).size.width >= 600;

          return Padding(
            padding: isTablet
                ? EdgeInsets.symmetric(horizontal: 40.w, vertical: 24.h)
                : EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
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
                Text(
                  'Bank Transfer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(isTablet ? 26 : 24),
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Complete your top up by transferring the exact amount to the account below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    fontWeight: FontWeight.w500,
                    color: mutedTextColor,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 24.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Name',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.caption),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        bankName,
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Account Name',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.caption),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        accountName,
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Account Number',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.caption),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            accountNumber,
                            style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: accountNumber));
                              setSheetState(() {
                                isAccountCopied = true;
                              });
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Account number copied to clipboard!'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              Future.delayed(const Duration(seconds: 3), () {
                                if (sheetContext.mounted) {
                                  setSheetState(() {
                                    isAccountCopied = false;
                                  });
                                }
                              });
                            },
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                child: isAccountCopied
                                    ? Icon(
                                        Icons.check_circle_rounded,
                                        key: const ValueKey('check_icon'),
                                        size: 20.sp,
                                        color: Colors.green,
                                      )
                                    : Icon(
                                        LucideIcons.copy,
                                        key: const ValueKey('copy_icon'),
                                        size: 18.sp,
                                        color: purpleColor,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.caption),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '₦${_formatCurrency(widget.amount)}',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      if (reference.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        Text(
                          'Reference',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.caption),
                            fontWeight: FontWeight.w500,
                            color: mutedTextColor,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        SelectableText(
                          reference,
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodySmall),
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 14.h),

                // ── Verification Error Banner ─────────────────────────────
                if (verificationError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3B1515)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                            : const Color(0xFFFCA5A5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.alertTriangle,
                          size: 18.sp,
                          color: const Color(0xFFEF4444),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            verificationError!,
                            style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.caption),
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFB91C1C),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                ],

                Text(
                  'Payments are usually confirmed within a few minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    fontWeight: FontWeight.w500,
                    color: mutedTextColor,
                  ),
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            setSheetState(() {
                              isVerifying = true;
                              verificationError = null;
                            });

                            bool isSuccess = false;
                            try {
                              if (reference.isNotEmpty) {
                                final verifyRes = await PaystackService
                                    .verifyTransaction(reference);
                                if (verifyRes != null &&
                                    (verifyRes['status'] == 'success' ||
                                        verifyRes['status'] == true)) {
                                  isSuccess = true;
                                }
                              }
                            } catch (_) {}

                            if (!sheetContext.mounted) return;

                            if (isSuccess) {
                              Navigator.pop(sheetContext);
                              setState(() => _isLoading = true);
                              await _creditWalletAndLogTransaction();
                              if (mounted) {
                                setState(() => _isLoading = false);
                                _showTopUpSuccessBottomSheet();
                              }
                            } else {
                              setSheetState(() {
                                isVerifying = false;
                                verificationError =
                                    "We haven't received your transfer yet. Please make sure you completed the payment in your banking app. If you just sent it, please wait a minute and tap to retry.";
                              });
                            }
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
                    child: isVerifying
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Verifying Transfer...',
                                style: TextStyle(
                                  fontSize:
                                      AppTypography.font(AppFontSizes.bodyMedium),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            verificationError != null
                                ? 'Retry Verification'
                                : "I've Made the Transfer",
                            style: TextStyle(
                              fontSize:
                                  AppTypography.font(AppFontSizes.bodyMedium),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 12.h),
                TextButton.icon(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: Icon(
                    LucideIcons.xCircle,
                    size: 20.sp,
                    color: mutedTextColor,
                  ),
                  label: Text(
                    'Cancel Payment',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      fontWeight: FontWeight.w600,
                      color: mutedTextColor,
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

  Future<void> _creditWalletAndLogTransaction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('customers').doc(user.uid);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          final rawVal = snapshot.data()?['balance'] ?? snapshot.data()?['walletBalance'] ?? 0.0;
          final double currentBalance = (rawVal is num)
              ? rawVal.toDouble()
              : (double.tryParse(rawVal.toString()) ?? 0.0);
          transaction.update(docRef, {'balance': currentBalance + widget.amount});
        }
      });

      await docRef.collection('transactions').add({
        'title': 'Top Up E-Wallet',
        'amount': widget.amount,
        'type': 'Top up',
        'isExpense': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error crediting wallet: $e');
    }
  }

  void _showTopUpSuccessBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
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
                    context.go('/wallet');
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
                    'Go to E-Wallet',
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
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/wallet');
                }
              },
            ),
          ),
        ),
        title: Text(
          'Payment Methods',
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
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(22.w),
                            decoration: BoxDecoration(
                              color: purpleColor,
                              borderRadius: BorderRadius.circular(28.r),
                              boxShadow: null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 6.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999.r),
                                  ),
                                  child: Text(
                                    'Top up summary',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: AppTypography.font(AppFontSizes.caption),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 18.h),
                                Text(
                                  '₦${_formatCurrency(widget.amount)}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AppTypography.font(34),
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  'Choose how you want to fund your wallet securely.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'Select payment method',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'Pick bank transfer or use one of your saved cards.',
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: AppTypography.font(AppFontSizes.bodySmall),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          _buildMethodTile(
                            context: context,
                            title: 'Bank transfer',
                            subtitle: 'Pay directly from your banking app',
                            icon: Icons.account_balance_outlined,
                            selected: _selectedIndex == 0,
                            badge: 'Instant',
                            onTap: () => setState(() => _selectedIndex = 0),
                            purpleColor: purpleColor,
                            borderColor: borderColor,
                          ),
                          if (_savedCards.isNotEmpty) ...[
                            SizedBox(height: 24.h),
                            Text(
                              'Saved cards',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'Use a previously verified card for faster checkout.',
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 14.h),
                            ...List.generate(_savedCards.length, (index) {
                              final card = _savedCards[index];
                              final itemIndex = index + 1;
                              final last4 = (card['last4'] ?? '••••').toString();
                              final brand =
                                  _formatBrand((card['brand'] ?? 'Card').toString());
                              final expMonth = (card['expMonth'] ?? '').toString();
                              final expYear = (card['expYear'] ?? '').toString();

                              return Padding(
                                padding: EdgeInsets.only(bottom: 14.h),
                                child: _buildMethodTile(
                                  context: context,
                                  title: '$brand ending in $last4',
                                  subtitle: expMonth.isNotEmpty && expYear.isNotEmpty
                                      ? 'Expires $expMonth/$expYear'
                                      : 'Ready for payment',
                                  icon: LucideIcons.creditCard,
                                  selected: _selectedIndex == itemIndex,
                                  badge: brand,
                                  onTap: () =>
                                      setState(() => _selectedIndex = itemIndex),
                                  purpleColor: purpleColor,
                                  borderColor: borderColor,
                                ),
                              );
                            }),
                          ],
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
                                  'Amount',
                                  style: TextStyle(
                                    color: mutedTextColor,
                                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '₦${_formatCurrency(widget.amount)}',
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            ElevatedButton(
                              onPressed: _addNewCard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    purpleColor.withValues(alpha: 0.12),
                                foregroundColor: purpleColor,
                                minimumSize: Size(double.infinity, 52.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18.r),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Add New Card',
                                style: TextStyle(
                                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            ElevatedButton(
                              onPressed: _handleContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: purpleColor,
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

  Widget _buildMethodTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required String badge,
    required VoidCallback onTap,
    required Color purpleColor,
    required Color borderColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24.r),
        child: Ink(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: selected ? purpleColor : borderColor,
              width: selected ? 1.6 : 1,
            ),
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
                  icon,
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
                      title,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
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
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: selected
                          ? purpleColor.withValues(alpha: 0.12)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF4F5F8)),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: selected ? purpleColor : mutedTextColor,
                        fontSize: AppTypography.font(AppFontSizes.caption),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    width: 22.w,
                    height: 22.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? purpleColor
                            : mutedTextColor.withValues(alpha: 0.45),
                        width: 1.8,
                      ),
                      color: selected ? purpleColor : Colors.transparent,
                    ),
                    child: selected
                        ? Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 13.sp,
                          )
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
