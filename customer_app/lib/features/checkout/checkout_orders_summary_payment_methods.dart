import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_card_bottom_sheet.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final double orderTotal;
  const PaymentMethodsScreen({super.key, this.orderTotal = 0.0});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  int _selectedIndex = 0; // 0 for E-Wallet, 1 for Bank Transfer, 2+ for Saved Cards
  double _walletBalance = 0.0;
  List<Map<String, dynamic>> _savedCards = [];
  String _customerEmail = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _customerEmail = user.email ?? '';
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _walletBalance = (data['balance'] ?? 0.0) as double;
          final cards = data['savedCards'] as List<dynamic>? ?? [];
          _savedCards = cards.map((c) => Map<String, dynamic>.from(c)).toList();
          if (widget.orderTotal > _walletBalance && _selectedIndex == 0) {
            _selectedIndex = 1;
          }
        });
      }
    }
  }

  Future<void> _addNewCard() async {
    if (_customerEmail.isEmpty) return;

    setState(() => _isLoading = true);

    // Show the card input bottom sheet (₦50 tokenisation charge)
    final result = await showAddCardBottomSheet(
      context: context,
      email: _customerEmail,
      amountInNaira: 50.0,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result == null) return; // user cancelled or error already shown in sheet

    // Extract card metadata from Paystack response
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
        await _loadData();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card added successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Card charged but no auth data returned. Try again.')),
        );
      }
    }
  }

  void _applyPaymentMethod() {
    if (_selectedIndex == 0) {
      context.pop({'type': 'wallet', 'label': 'E-Wallet'});
    } else if (_selectedIndex == 1) {
      context.pop({'type': 'bank', 'label': 'Bank Transfer'});
    } else {
      final selectedCard = _savedCards[_selectedIndex - 2];
      context.pop({
        'type': 'card',
        'label': "${selectedCard['brand']} (•••• ${selectedCard['last4']})",
        'card': selectedCard
      });
    }
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '₦$whole.${parts[1]}';
  }

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
          'Payment Methods',
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: AppTypography.font(AppFontSizes.headlineMedium),
              fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(20.w),
                    children: [
                      // E-Wallet Option
                      GestureDetector(
                        onTap: widget.orderTotal > _walletBalance
                            ? null
                            : () => setState(() => _selectedIndex = 0),
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          margin: EdgeInsets.only(bottom: 16.h),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.white,
                            borderRadius: BorderRadius.circular(24.r),
                            boxShadow: AppTheme.faintShadow,
                            border: Border.all(
                                color: _selectedIndex == 0
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                                width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(LucideIcons.wallet,
                                      color: widget.orderTotal > _walletBalance
                                          ? Colors.grey
                                          : AppTheme.primaryColor,
                                      size: 24),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text('My Wallet',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                                color: widget.orderTotal > _walletBalance
                                                    ? Colors.grey
                                                    : (isDark ? Colors.white : Colors.black))),
                                        const Spacer(),
                                        Text(
                                            _formatCurrency(_walletBalance),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                                color: widget.orderTotal > _walletBalance
                                                    ? Colors.grey
                                                    : (isDark ? Colors.white : Colors.black))),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Radio<int>(
                                    value: 0,
                                    groupValue: _selectedIndex,
                                    activeColor: AppTheme.primaryColor,
                                    onChanged: widget.orderTotal > _walletBalance
                                        ? null
                                        : (val) => setState(() => _selectedIndex = val!),
                                  ),
                                ],
                              ),
                              if (widget.orderTotal > _walletBalance) ...[
                                SizedBox(height: 12.h),
                                Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                                SizedBox(height: 8.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Insufficient balance',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: AppTypography.font(13),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        await context.push('/wallet/top-up');
                                        _loadData();
                                      },
                                      icon: Icon(LucideIcons.plusCircle, size: 16.sp, color: Colors.white),
                                      label: Text(
                                        'Top Up',
                                        style: TextStyle(fontSize: AppTypography.font(AppFontSizes.bodySmall), fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16.r),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Bank Transfer Option
                      GestureDetector(
                        onTap: () => setState(() => _selectedIndex = 1),
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          margin: EdgeInsets.only(bottom: 16.h),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.white,
                            borderRadius: BorderRadius.circular(24.r),
                            boxShadow: AppTheme.faintShadow,
                            border: Border.all(
                                color: _selectedIndex == 1
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                                width: 2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_outlined,
                                  color: AppTheme.primaryColor, size: 24),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text('Bank Transfer',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black)),
                              ),
                              SizedBox(width: 12.w),
                              Radio<int>(
                                value: 1,
                                groupValue: _selectedIndex,
                                activeColor: AppTheme.primaryColor,
                                onChanged: (val) =>
                                    setState(() => _selectedIndex = val!),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Saved Cards Options
                      if (_savedCards.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Text(
                            "Saved Cards",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                color: Colors.grey),
                          ),
                        ),
                        ...List.generate(_savedCards.length, (index) {
                          final card = _savedCards[index];
                          final itemIndex = index + 2;
                          final last4 = card['last4'] ?? '••••';
                          final brand = card['brand'] ?? 'Card';

                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedIndex = itemIndex),
                            child: Container(
                              padding: EdgeInsets.all(16.w),
                              margin: EdgeInsets.only(bottom: 16.h),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[900] : Colors.white,
                                borderRadius: BorderRadius.circular(24.r),
                                boxShadow: AppTheme.faintShadow,
                                border: Border.all(
                                    color: _selectedIndex == itemIndex
                                        ? AppTheme.primaryColor
                                        : Colors.transparent,
                                    width: 2),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.creditCard,
                                      color: AppTheme.primaryColor, size: 24),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Text('$brand (•••• $last4)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black)),
                                  ),
                                  SizedBox(width: 12.w),
                                  Radio<int>(
                                    value: itemIndex,
                                    groupValue: _selectedIndex,
                                    activeColor: AppTheme.primaryColor,
                                    onChanged: (val) =>
                                        setState(() => _selectedIndex = val!),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: _addNewCard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.1),
                          foregroundColor: AppTheme.primaryColor,
                          minimumSize: Size(double.infinity, 56.h),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32.r)),
                          elevation: 0,
                        ),
                        child: const Text('Add New Card',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: _applyPaymentMethod,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 56.h),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32.r)),
                          elevation: 0,
                        ),
                        child: const Text('Apply',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
