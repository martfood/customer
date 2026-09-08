import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import '../wallet/paystack_service.dart';
import '../wallet/paystack_webview_screen.dart'; // kept for _payWithCard
import '../checkout/add_card_bottom_sheet.dart';

class PayAwaitingOrderScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const PayAwaitingOrderScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<PayAwaitingOrderScreen> createState() => _PayAwaitingOrderScreenState();
}

class _PayAwaitingOrderScreenState extends State<PayAwaitingOrderScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String _selectedPaymentType = 'wallet'; // 'wallet', 'saved_card', 'card', 'bank'
  int _selectedCardIndex = 0;
  List<Map<String, dynamic>> _savedCards = [];

  bool _isProcessing = false;
  double _walletBalance = 0.0;
  bool _isLoadingWallet = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingWallet = false);
      return;
    }

    try {
      final doc = await _firestore.collection('customers').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final val = data['balance'] ?? data['walletBalance'];
        _walletBalance = (val is num) ? val.toDouble() : (double.tryParse(val?.toString() ?? '') ?? 0.0);

        final cardsRaw = data['savedCards'] as List<dynamic>? ?? [];
        _savedCards = cardsRaw.map((c) => Map<String, dynamic>.from(c as Map)).toList();
      }
    } catch (e) {
      debugPrint('Error loading customer data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    return double.tryParse(val?.toString() ?? '') ?? 0.0;
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '₦$whole.${parts[1]}';
  }

  Future<void> _addNewCard() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final email = user.email ?? 'customer@martfood.com';

    // Show the card input bottom sheet (₦50 tokenisation charge)
    final result = await showAddCardBottomSheet(
      context: context,
      email: email,
      amountInNaira: 50.0,
    );

    if (!mounted) return;
    if (result == null) return; // user cancelled or sheet already showed error

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

      await _firestore.collection('customers').doc(user.uid).update({
        'savedCards': FieldValue.arrayUnion([newCard]),
      });
      await _loadCustomerData();

      if (mounted) {
        setState(() {
          _selectedPaymentType = 'saved_card';
          _selectedCardIndex = _savedCards.length - 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card added successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Card charged but no auth code returned. Try again.')),
        );
      }
    }
  }


  Future<void> _handlePayment() async {
    final total = _toDouble(widget.orderData['total']);
    final user = _auth.currentUser;
    if (user == null) return;

    if (_selectedPaymentType == 'wallet') {
      if (_walletBalance < total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient wallet balance. Please select another payment method.')),
        );
        return;
      }
      await _payWithWallet(user.uid, total);
    } else if (_selectedPaymentType == 'saved_card') {
      if (_savedCards.isEmpty) {
        await _addNewCard();
      } else {
        await _payWithCard(user.email ?? '', total);
      }
    } else if (_selectedPaymentType == 'bank') {
      await _payWithBankTransfer(total);
    } else if (_selectedPaymentType == 'card') {
      await _payWithCard(user.email ?? '', total);
    }
  }

  Future<void> _payWithWallet(String userId, double total) async {
    setState(() => _isProcessing = true);
    try {
      final custRef = _firestore.collection('customers').doc(userId);

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(custRef);
        if (!snap.exists) throw Exception('User profile not found');
        final data = snap.data()!;
        final currentBal = _toDouble(data['balance'] ?? data['walletBalance']);
        if (currentBal < total) throw Exception('Insufficient wallet balance');

        tx.update(custRef, {
          'balance': currentBal - total,
          'walletBalance': currentBal - total,
        });
      });

      // Update Order & Payment Session
      await _markOrderAsPaid();

      // Add transaction history
      await custRef.collection('transactions').add({
        'title': 'Pay for Me Order Checkout',
        'amount': total,
        'type': 'Orders',
        'isExpense': true,
        'orderId': widget.orderId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isProcessing = false);
        _showSuccessBottomSheet();
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    }
  }

  Future<void> _payWithBankTransfer(double total) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Show loading while fetching bank account from Paystack
    setState(() => _isProcessing = true);

    final bankAcc = await PaystackService.createBankTransferAccount(
      email: user.email ?? 'customer@martfood.com',
      amountInNaira: total,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (bankAcc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not generate bank transfer account. Please ensure "Pay with Transfer" is enabled on your Paystack dashboard, or choose another payment method.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final String bankName = bankAcc['bank_name'] ?? 'N/A';
    final String accountName = bankAcc['account_name'] ?? 'N/A';
    final String accountNumber = bankAcc['account_number'] ?? 'N/A';
    final String reference = bankAcc['reference'] ?? '';

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final cardBgColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF3F4F6);
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
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
              Text(
                'Bank Transfer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(24),
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Complete your payment by transferring the exact amount to the account below.',
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
                        IconButton(
                          icon: Icon(LucideIcons.copy,
                              size: 18.sp, color: purpleColor),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: accountNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account number copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
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
                      _formatCurrency(total),
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

                          if (!ctx.mounted) return;

                          if (isSuccess) {
                            Navigator.pop(ctx);
                            setState(() => _isProcessing = true);
                            await _markOrderAsPaid();
                            if (mounted) {
                              setState(() => _isProcessing = false);
                              _showSuccessBottomSheet();
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
                onPressed: () => Navigator.pop(ctx),
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
        ),
      ),
    );
  }

  Future<void> _payWithCard(String email, double total) async {
    setState(() => _isProcessing = true);
    try {
      final res = await PaystackService.initializeTransaction(
        email: email.isNotEmpty ? email : 'customer@martfood.com',
        amountInNaira: total,
      );

      if (res == null || res['authorization_url'] == null) {
        if (mounted) setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize Paystack transaction.')),
        );
        return;
      }

      final authUrl = res['authorization_url'].toString();
      final reference = (res['reference'] ?? '').toString();

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (navContext) => PaystackWebViewScreen(
            authorizationUrl: authUrl,
            reference: reference,
            onSuccess: (_) {
              if (navContext.mounted) Navigator.pop(navContext, true);
            },
            onCancel: () {
              if (navContext.mounted) Navigator.pop(navContext, false);
            },
          ),
        ),
      );

      if (result == true) {
        if (mounted) setState(() => _isProcessing = true);
        await _markOrderAsPaid();
        if (mounted) {
          setState(() => _isProcessing = false);
          _showSuccessBottomSheet();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paystack error: $e')),
      );
    }
  }

  Future<void> _markOrderAsPaid() async {
    final token = widget.orderData['paymentToken'];

    await _firestore.collection('orders').doc(widget.orderId).update({
      'status': 'pending',
      'paymentStatus': 'paid',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (token != null && token.toString().isNotEmpty) {
      await _firestore.collection('payment_sessions').doc(token.toString()).update({
        'status': 'paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _showSuccessBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 44.sp),
            ),
            SizedBox(height: 20.h),
            Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: AppTypography.font(22),
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            Text(
              'Your payment has been received. Your order has been placed and sent to the restaurant for preparation!',
              style: TextStyle(
                fontSize: AppTypography.font(14),
                color: mutedTextColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 28.h),
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/orders?showSuccess=true');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27.r),
                  ),
                ),
                child: Text(
                  'Okay',
                  style: TextStyle(
                    fontSize: AppTypography.font(16),
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


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final restaurantName = (widget.orderData['restaurantName'] ?? widget.orderData['vendorName'] ?? 'MartFood Order').toString();
    final bool hideOrderDetails = (widget.orderData['hideOrderDetails'] == true);
    final items = List<Map<String, dynamic>>.from(widget.orderData['items'] ?? []);
    final subtotal = _toDouble(widget.orderData['subtotal']);
    final deliveryFee = _toDouble(widget.orderData['deliveryFee']);
    final platformFee = _toDouble(widget.orderData['platformFee']);
    final total = _toDouble(widget.orderData['total']);

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
              border: Border.all(color: borderColor, width: 1),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back, color: purpleColor, size: 20.sp),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Text(
          'Pay Order',
          style: TextStyle(
            color: purpleColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: _isProcessing
          ? Center(child: CircularProgressIndicator(color: purpleColor))
          : SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Order Summary Card ─────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurantName,
                          style: TextStyle(
                            fontSize: AppTypography.font(18),
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Divider(color: borderColor, height: 1),
                        SizedBox(height: 12.h),

                        // Food Items or Privacy Card
                        if (hideOrderDetails)
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 4.h),
                            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 14.w),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : AppTheme.lightInputFill,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: purpleColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(LucideIcons.eyeOff, size: 18.sp, color: purpleColor),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order Details Hidden',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        'The customer chose to keep the items and meal choices in this order private.',
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
                          )
                        else
                          ...items.map((item) {
                            final title = (item['title'] ?? 'Food Item').toString();
                            final qty = item['quantity'] ?? 1;
                            final itemPrice = _toDouble(item['price']) * qty;
                            final choices = List<Map<String, dynamic>>.from(item['selectedChoices'] ?? []);
                            final addOns = List<Map<String, dynamic>>.from(item['selectedAddOns'] ?? []);

                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 6.h),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${qty}x ', style: TextStyle(fontWeight: FontWeight.bold, color: purpleColor, fontSize: AppTypography.font(AppFontSizes.bodyMedium))),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor, fontSize: AppTypography.font(AppFontSizes.bodyMedium))),
                                        if (choices.isNotEmpty)
                                          Text(
                                            choices.map((c) => c['label'] ?? c['group']).join(', '),
                                            style: TextStyle(color: mutedTextColor, fontSize: AppTypography.font(AppFontSizes.bodySmall)),
                                          ),
                                        if (addOns.isNotEmpty)
                                          Text(
                                            'Add-ons: ${addOns.map((a) => (((a['quantity'] as num?)?.toInt() ?? 1) > 1) ? '${a['name'] ?? a['title']} (x${a['quantity']})' : '${a['name'] ?? a['title']}').where((n) => n.isNotEmpty).join(', ')}',
                                            style: TextStyle(color: mutedTextColor, fontSize: AppTypography.font(AppFontSizes.bodySmall)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(_formatCurrency(itemPrice), style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor, fontSize: AppTypography.font(AppFontSizes.bodyMedium))),
                                ],
                              ),
                            );
                          }),

                        SizedBox(height: 12.h),
                        Divider(color: borderColor, height: 1),
                        SizedBox(height: 12.h),

                        _buildSummaryRow('Subtotal', subtotal, primaryTextColor, mutedTextColor),
                        SizedBox(height: 8.h),
                        _buildSummaryRow('Delivery Fee', deliveryFee, primaryTextColor, mutedTextColor),
                        SizedBox(height: 8.h),
                        _buildSummaryRow('Platform Fee', platformFee, primaryTextColor, mutedTextColor),
                        SizedBox(height: 12.h),
                        Divider(color: borderColor, height: 1),
                        SizedBox(height: 12.h),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total', style: TextStyle(fontSize: AppTypography.font(AppFontSizes.headlineSmall), fontWeight: FontWeight.w800, color: primaryTextColor)),
                            Text(_formatCurrency(total), style: TextStyle(fontSize: AppTypography.font(AppFontSizes.headlineMedium), fontWeight: FontWeight.w800, color: purpleColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // ── Select Payment Method Section ───────────────────
                  Text(
                    'Select Payment Method',
                    style: TextStyle(
                      fontSize: AppTypography.font(16),
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 14.h),

                  // E-Wallet Option
                  _buildPaymentOption(
                    type: 'wallet',
                    icon: LucideIcons.wallet,
                    title: 'My E-Wallet',
                    subtitle: _isLoadingWallet ? 'Loading balance...' : _formatCurrency(_walletBalance),
                    isInsufficient: !_isLoadingWallet && total > _walletBalance,
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    purpleColor: purpleColor,
                    primaryTextColor: primaryTextColor,
                    mutedTextColor: mutedTextColor,
                  ),

                  // Bank Transfer Option
                  _buildPaymentOption(
                    type: 'bank',
                    icon: LucideIcons.landmark,
                    title: 'Bank Transfer',
                    subtitle: 'Transfer directly to virtual account',
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    purpleColor: purpleColor,
                    primaryTextColor: primaryTextColor,
                    mutedTextColor: mutedTextColor,
                  ),

                  // Saved Cards Option
                  _buildSavedCardsOption(
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    purpleColor: purpleColor,
                    primaryTextColor: primaryTextColor,
                    mutedTextColor: mutedTextColor,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 54.h,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27.r),
                ),
              ),
              child: Text(
                'Pay ${_formatCurrency(total)}',
                style: TextStyle(
                  fontSize: AppTypography.font(16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedCardsOption({
    required Color surfaceColor,
    required Color borderColor,
    required Color purpleColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
  }) {
    final isSelected = _selectedPaymentType == 'saved_card';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isSelected ? purpleColor : borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: purpleColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.creditCard, color: purpleColor, size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved Cards',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTypography.font(14),
                        color: primaryTextColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _savedCards.isEmpty ? 'No saved card available' : '${_savedCards.length} saved card(s)',
                      style: TextStyle(
                        fontSize: AppTypography.font(12),
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: 'saved_card',
                groupValue: _selectedPaymentType,
                activeColor: purpleColor,
                onChanged: (val) {
                  setState(() => _selectedPaymentType = val!);
                  if (_savedCards.isEmpty) {
                    _addNewCard();
                  }
                },
              ),
            ],
          ),

          if (_savedCards.isNotEmpty && isSelected) ...[
            SizedBox(height: 12.h),
            Divider(color: borderColor, height: 1),
            SizedBox(height: 10.h),
            ..._savedCards.asMap().entries.map((entry) {
              final idx = entry.key;
              final card = entry.value;
              final isCardSelected = _selectedCardIndex == idx;

              return InkWell(
                onTap: () => setState(() => _selectedCardIndex = idx),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    children: [
                      Icon(
                        isCardSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isCardSelected ? purpleColor : mutedTextColor,
                        size: 18.sp,
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        '${card['brand'] ?? 'Card'} (•••• ${card['last4'] ?? '****'})',
                        style: TextStyle(
                          fontWeight: isCardSelected ? FontWeight.bold : FontWeight.w500,
                          color: primaryTextColor,
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          SizedBox(height: 8.h),
          GestureDetector(
            onTap: _addNewCard,
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, color: purpleColor, size: 18.sp),
                SizedBox(width: 6.w),
                Text(
                  '+ Add New Card',
                  style: TextStyle(
                    color: purpleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color primaryTextColor, Color mutedTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: mutedTextColor, fontSize: AppTypography.font(AppFontSizes.bodySmall))),
        Text(_formatCurrency(amount), style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600, fontSize: AppTypography.font(AppFontSizes.bodySmall))),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
    bool isInsufficient = false,
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color purpleColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
  }) {
    final isSelected = _selectedPaymentType == type;

    return GestureDetector(
      onTap: isInsufficient ? null : () => setState(() => _selectedPaymentType = type),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? purpleColor : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: isInsufficient ? Colors.grey.withValues(alpha: 0.1) : purpleColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isInsufficient ? Colors.grey : purpleColor, size: 22.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.font(14),
                      color: isInsufficient ? Colors.grey : primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    isInsufficient ? '$subtitle (Insufficient balance)' : subtitle,
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                      color: isInsufficient ? Colors.red : mutedTextColor,
                      fontWeight: isInsufficient ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: type,
              groupValue: _selectedPaymentType,
              activeColor: purpleColor,
              onChanged: isInsufficient ? null : (val) => setState(() => _selectedPaymentType = val!),
            ),
          ],
        ),
      ),
    );
  }
}
