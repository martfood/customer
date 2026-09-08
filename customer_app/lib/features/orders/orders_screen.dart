import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/bottom_nav_bar.dart';
import 'package:shared_widgets/widgets/verification_badge.dart';

class OrdersScreen extends StatefulWidget {
  final bool showSuccess;
  final bool payForMeSuccess;
  final String? orderId;
  final String? paymentToken;
  final int initialIndex;

  const OrdersScreen({
    super.key,
    this.showSuccess = false,
    this.payForMeSuccess = false,
    this.orderId,
    this.paymentToken,
    this.initialIndex = 0,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    int initialTab = widget.initialIndex;
    if ((widget.showSuccess || widget.payForMeSuccess) && initialTab == 0) {
      initialTab = 1;
    }
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.payForMeSuccess) {
        _showPayForMeCreatedPopup(
          orderId: widget.orderId,
          token: widget.paymentToken,
        );
      } else if (widget.showSuccess) {
        _showPaymentSuccessPopup();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPayForMeCreatedPopup({String? orderId, String? token}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final payUrl = token != null && token.isNotEmpty
        ? 'https://martfood-app.web.app/pay/$token'
        : '';

    bool isCopied = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
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
                  'Order placed successfully!',
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
                  'Your order has been placed successfully. Share your payment link with a sponsor to complete payment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    color: mutedTextColor,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                if (payUrl.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.lightInputFill,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.link, size: 18.sp, color: purpleColor),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            payUrl,
                            style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.bodySmall),
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                            child: isCopied
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
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: payUrl));
                            setSheetState(() {
                              isCopied = true;
                            });
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Payment link copied to clipboard!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            Future.delayed(const Duration(seconds: 3), () {
                              if (sheetContext.mounted) {
                                setSheetState(() {
                                  isCopied = false;
                                });
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 28.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _tabController.animateTo(1);
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
                      'Track Order',
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
      ),
    );
  }

  void _showPaymentSuccessPopup() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
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
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(28.w, 16.h, 28.w, 32.h),
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
              size: 88.sp,
              color: purpleColor,
            ),
            SizedBox(height: 24.h),
            Text(
              'Payment Successful!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(26),
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Your payment has been confirmed successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                color: mutedTextColor,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _tabController.animateTo(1);
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
                  'Track Order',
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                    fontWeight: FontWeight.w700,
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
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Please log in to view your orders',
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
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'Orders',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.white : purpleColor,
          unselectedLabelColor: AppTheme.mutedTextColorFor(isDark),
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              width: 2.5,
              color: isDark ? Colors.white : purpleColor,
            ),
            insets: EdgeInsets.symmetric(horizontal: 16.w),
          ),
          labelStyle: TextStyle(
            fontSize: AppTypography.font(AppFontSizes.bodyLarge),
            fontWeight: FontWeight.w800,
          ),
          tabs: const [
            Tab(text: 'Cart'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCartTab(
            user.uid,
            isDark,
            backgroundColor,
            surfaceColor,
            primaryTextColor,
            purpleColor,
            borderColor,
          ),
          _buildOrdersList(
            user.uid,
            [
              'awaiting_payment',
              'payment_processing',
              'draft',
              'pending',
              'pending_verification',
              'preparing',
              'accepted',
              'rider_assigned',
              'at_restaurant',
              'in_transit',
              'ready',
              'arrived',
            ],
            OrderType.active,
          ),
          _buildOrdersList(user.uid, ['delivered'], OrderType.completed),
        ],
      ),
      bottomNavigationBar: MartFoodBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) context.go('/home');
          if (index == 1) context.go('/search');
          if (index == 3) context.go('/profile/customer-service');
          if (index == 4) context.go('/profile');
        },
      ),
    );
  }

  Future<void> _updateCartQuantity(String docId, int newQuantity) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('customers')
          .doc(user.uid)
          .collection('cart')
          .doc(docId)
          .update({'quantity': newQuantity});
    }
  }

  Future<void> _removeCartItem(String docId) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('customers')
          .doc(user.uid)
          .collection('cart')
          .doc(docId)
          .delete();
    }
  }

  Widget _buildCartTab(
    String userId,
    bool isDark,
    Color backgroundColor,
    Color surfaceColor,
    Color primaryTextColor,
    Color purpleColor,
    Color borderColor,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('customers')
          .doc(userId)
          .collection('cart')
          .orderBy('addedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: purpleColor));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72.w,
                    height: 72.w,
                    decoration: BoxDecoration(
                      color: purpleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 32.sp,
                      color: purpleColor,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    "Your cart is empty",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Add meals, groceries, or pharmacy items and they will appear here for checkout.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      color: AppTheme.mutedTextColorFor(isDark),
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 28.w,
                        vertical: 16.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Explore Restaurants',
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final cartItems = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        final bool hasMultipleItems = cartItems.length >= 2;
        final double subtotal = cartItems.fold<double>(
          0.0,
          (acc, item) =>
              acc +
              ((item['price'] ?? 0.0) as num).toDouble() *
                  ((item['quantity'] ?? 1) as num).toInt(),
        );
        final int totalQuantity = cartItems.fold<int>(
          0,
          (acc, item) => acc + ((item['quantity'] ?? 1) as num).toInt(),
        );

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  return _buildCartItemWidget(
                    context,
                    item,
                    isDark,
                    surfaceColor,
                    borderColor,
                    purpleColor,
                    primaryTextColor,
                    showCheckoutButton: !hasMultipleItems,
                  );
                },
              ),
            ),
            if (hasMultipleItems)
              Container(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push('/checkout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Checkout ($totalQuantity item${totalQuantity > 1 ? 's' : ''})',
                                style: TextStyle(
                                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              const Icon(LucideIcons.arrowRight, size: 18),
                            ],
                          ),
                          Text(
                            _formatCurrency(subtotal),
                            style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCartItemWidget(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color purpleColor,
    Color primaryTextColor, {
    required bool showCheckoutButton,
  }) {
    final docId = item['id'];
    final imageUrl = item['imageUrl'] ?? '';
    final title = item['title'] ?? 'Food Item';
    final restaurant = item['restaurant'] ?? 'MartFood';
    final price = (item['price'] ?? 0.0).toDouble();
    final quantity = item['quantity'] ?? 1;
    final selectedChoices = item['selectedChoices'] as List<dynamic>? ?? [];
    final selectedAddOns = item['selectedAddOns'] as List<dynamic>? ?? [];

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) async {
        await _removeCartItem(docId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title removed from cart'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      background: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(24.r),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24.w),
        child: const Icon(LucideIcons.trash2, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: null,
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 92.w,
                            height: 92.w,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 92.w,
                              height: 92.w,
                              color: isDark ? Colors.grey[800] : Colors.grey[300],
                              child: Icon(Icons.fastfood, color: Colors.grey, size: 24.sp),
                            ),
                          )
                        : Container(
                            width: 92.w,
                            height: 92.w,
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            child: Icon(Icons.fastfood, color: Colors.grey, size: 24.sp),
                          ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Food Name & Quantity Controls at Top Right
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCartQuantityButton(LucideIcons.minus, () {
                                  if (quantity > 1) {
                                    _updateCartQuantity(docId, quantity - 1);
                                  }
                                }, isDark, purpleColor, borderColor),
                                SizedBox(width: 6.w),
                                Text(
                                  '$quantity',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                    color: primaryTextColor,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                _buildCartQuantityButton(LucideIcons.plus, () {
                                  _updateCartQuantity(docId, quantity + 1);
                                }, isDark, purpleColor, borderColor, isPrimary: true),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        // Price
                        Text(
                          _formatCurrency(price),
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                            fontWeight: FontWeight.w800,
                            color: purpleColor,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        // Restaurant Name & Verification Badge
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                restaurant,
                                style: TextStyle(
                                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.mutedTextColorFor(isDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            VendorVerificationBadge(
                              vendorId: (item['vendorId'] ?? item['restaurantId'] ?? '').toString(),
                              fallbackData: item,
                              size: 14.sp,
                            ),
                          ],
                        ),
                        if (selectedChoices.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            selectedChoices
                                .map((choice) => choice['label'] ?? '')
                                .where((label) => label.toString().isNotEmpty)
                                .join(' • '),
                            style: TextStyle(
                              color: AppTheme.mutedTextColorFor(isDark),
                              fontSize: AppTypography.font(AppFontSizes.caption),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (selectedAddOns.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            'Add-ons: ${selectedAddOns.map((addon) => (((addon['quantity'] as num?)?.toInt() ?? 1) > 1) ? '${addon['name'] ?? addon['title']} (x${addon['quantity']})' : '${addon['name'] ?? addon['title']}').where((name) => name.isNotEmpty).join(', ')}',
                            style: TextStyle(
                              color: AppTheme.mutedTextColorFor(isDark),
                              fontSize: AppTypography.font(AppFontSizes.caption),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: borderColor,
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  if (showCheckoutButton) ...[
                    // Checkout Button (Full Width)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          context.push('/checkout');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Checkout',
                              style: TextStyle(
                                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            const Icon(LucideIcons.arrowRight, size: 18),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                  ],
                  // Delete Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await _removeCartItem(docId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$title removed from cart'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: isDark ? Colors.white : purpleColor,
                        side: BorderSide(
                          color: borderColor,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          color: isDark ? Colors.white : purpleColor,
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartQuantityButton(
    IconData icon,
    VoidCallback onTap,
    bool isDark,
    Color purpleColor,
    Color borderColor, {
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28.w,
        height: 28.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPrimary
              ? purpleColor
              : (isDark ? AppTheme.darkSurface : Colors.grey[100]),
          border: Border.all(
            color: isPrimary ? purpleColor : borderColor,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 14.sp,
          color:
              isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  Widget _buildOrdersList(String userId, List<String> statuses, OrderType type) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("Firestore Error: ${snapshot.error}");
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        final allDocs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);

        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final status = (data['status'] ?? '').toString();
          return statuses.contains(status);
        }).toList();

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>? ?? {};
          final bData = b.data() as Map<String, dynamic>? ?? {};
          final aTime = aData['createdAt'];
          final bTime = bData['createdAt'];
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          if (aTime is String && bTime is String) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });

        if (docs.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return _buildEmptyState(isDark, type);
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          children: List.generate(docs.length, (index) {
              final orderData = docs[index].data() as Map<String, dynamic>;
              final orderId = docs[index].id;
              final items = orderData['items'] as List<dynamic>? ?? [];
              final itemCount = items.fold<int>(
                0,
                (acc, item) => acc + ((item['quantity'] ?? 1) as int),
              );
              final title =
                  (orderData['restaurantName'] ?? 'MartFood Order').toString();
              final totalValue = orderData['total'];
              final price = totalValue is num
                  ? totalValue.toDouble()
                  : double.tryParse(totalValue?.toString() ?? '') ?? 0.0;
              final status = (orderData['status'] ?? 'pending').toString();

              String imageUrl = '';
              if (items.isNotEmpty) {
                imageUrl = (items.first['imageUrl'] ?? '').toString();
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == docs.length - 1 ? 0 : 16.h,
                ),
                child: _buildOrderCard(
                  orderId: orderId,
                  title: title,
                  itemsCount: itemCount,
                  distanceKm: 2.0,
                  price: price,
                  status: _formatStatus(status),
                  imageUrl: imageUrl,
                  type: type,
                  orderData: orderData,
                  items: items,
                ),
              );
            }),
        );
      },
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'awaiting_payment': return 'Awaiting Payment';
      case 'payment_processing': return 'Processing';
      case 'draft': return 'Draft';
      case 'pending': return 'Pending';
      case 'pending_verification': return 'Verifying';
      case 'preparing': return 'Preparing';
      case 'accepted': return 'Accepted';
      case 'rider_assigned': return 'Rider Assigned';
      case 'at_restaurant': return 'At Restaurant';
      case 'in_transit': return 'In Transit';
      case 'ready': return 'Ready';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return status.toUpperCase();
    }
  }

  Widget _buildOrderCard({
    required String orderId,
    required String title,
    required int itemsCount,
    required double distanceKm,
    required double price,
    required String status,
    required String imageUrl,
    required OrderType type,
    required Map<String, dynamic> orderData,
    required List<dynamic> items,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final statusColor =
        type == OrderType.completed ? Colors.green : purpleColor;

    final foodName = items.isNotEmpty
        ? (items.first['title'] ?? items.first['name'] ?? title).toString()
        : title;
    final restaurantName =
        (orderData['restaurantName'] ?? orderData['vendorName'] ?? title).toString();
    final isReviewed = (orderData['isReviewed'] == true) ||
        (orderData['hasBeenReviewed'] == true) ||
        (orderData['reviewed'] == true) ||
        (orderData['hasReview'] == true);
    final isRiderRated = (orderData['isRiderRated'] == true) ||
        (orderData['riderRated'] == true) ||
        (orderData['hasRiderBeenRated'] == true);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: null,
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18.r),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 92.w,
                          height: 92.w,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _buildImageFallback(),
                        )
                      : _buildImageFallback(),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food Name & Status Tag
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              foodName,
                              style: TextStyle(
                                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: AppTypography.font(AppFontSizes.caption),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      // Price
                      Text(
                        _formatCurrency(price),
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                          fontWeight: FontWeight.w800,
                          color: purpleColor,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      // Restaurant Name & Verification Badge
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              restaurantName,
                              style: TextStyle(
                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                fontWeight: FontWeight.w600,
                                color: mutedTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          VendorVerificationBadge(
                            vendorId: (orderData['vendorId'] ?? orderData['restaurantId'] ?? '').toString(),
                            fallbackData: orderData,
                            size: 14.sp,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (type == OrderType.active) ...[
            Divider(
              height: 1,
              color: borderColor,
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: orderData['status'] == 'awaiting_payment'
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _cancelAwaitingOrder(
                              orderId,
                              orderData['paymentToken']?.toString(),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18.r),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                            ),
                            child: Text(
                              'Cancel Request',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showPayNowModal(
                              orderId,
                              orderData,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18.r),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              elevation: 0,
                            ),
                            child: Text(
                              'Pay Now',
                              style: TextStyle(
                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.push(
                          '/track_driver',
                          extra: {'orderId': orderId},
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          elevation: 0,
                        ),
                        child: Text(
                          'Track Order',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
          if (type == OrderType.completed && (!isReviewed || !isRiderRated)) ...[
            Divider(
              height: 1,
              color: borderColor,
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  if (!isReviewed)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.push(
                          '/orders/leave-review',
                          extra: {
                            'name': title,
                            'imageUrl': imageUrl,
                            'vendorId': orderData['vendorId'] ?? orderData['restaurantId'] ?? '',
                            'orderId': orderId,
                            'itemsSummary': items
                                .map((i) => "${i['quantity'] ?? 1}x ${i['title'] ?? i['name'] ?? 'Item'}")
                                .join(', '),
                          },
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: isDark ? Colors.white : purpleColor,
                          side: BorderSide(color: isDark ? Colors.white : purpleColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          elevation: 0,
                        ),
                        child: Text(
                          'Leave Review',
                          style: TextStyle(
                            color: isDark ? Colors.white : purpleColor,
                            fontSize: AppTypography.font(AppFontSizes.bodySmall),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (!isReviewed && !isRiderRated)
                    SizedBox(width: 12.w),
                  if (!isRiderRated)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push(
                          '/rate_rider',
                          extra: {
                            'orderId': orderId,
                            'riderId': orderData['riderId'] ?? '',
                            'riderName': orderData['riderName'] ?? 'Rider',
                            'riderPhotoUrl': orderData['riderPhotoUrl'] ?? '',
                          },
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          elevation: 0,
                        ),
                        child: Text(
                          'Rate Rider',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodySmall),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      width: 92.w,
      height: 92.w,
      color: Colors.grey[200],
      child: Icon(
        Icons.fastfood,
        color: Colors.grey,
        size: 24.sp,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, OrderType type) {
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 36.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: purpleColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(22.r),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 30.sp,
                color: purpleColor,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              type == OrderType.active
                  ? 'No active orders right now'
                  : type == OrderType.completed
                      ? 'No completed orders yet'
                      : 'No cancelled orders yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              type == OrderType.active
                  ? 'When you place a new order, it will appear here for tracking.'
                  : type == OrderType.completed
                      ? 'Delivered orders will show up here after they are completed.'
                      : 'Cancelled orders will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                color: mutedTextColor,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (type == OrderType.active) ...[
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Explore Restaurants',
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancelAwaitingOrder(String orderId, String? paymentToken) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSurface
          : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Cancel Payment Request?',
              style: TextStyle(
                fontSize: AppTypography.font(20),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Are you sure you want to cancel this order and invalidate its payment link?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppTypography.font(14), color: Colors.grey[600]),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: const Text('Keep Active'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      elevation: 0,
                    ),
                    child: const Text('Yes, Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('orders').doc(orderId).update({
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (paymentToken != null && paymentToken.isNotEmpty) {
          await _firestore.collection('payment_sessions').doc(paymentToken).update({
            'status': 'cancelled',
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment request cancelled.')),
          );
        }
      } catch (e) {
        debugPrint('Error cancelling order: $e');
      }
    }
  }

  void _showPayNowModal(String orderId, Map<String, dynamic> orderData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    bool hideOrderDetails = orderData['hideOrderDetails'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Complete Payment',
                style: TextStyle(
                  fontSize: AppTypography.font(20),
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Choose how you would like to complete payment for this order.',
                style: TextStyle(
                  fontSize: AppTypography.font(14),
                  color: mutedTextColor,
                ),
              ),
              SizedBox(height: 24.h),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: purpleColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share, color: purpleColor, size: 20.sp),
                ),
                title: Text(
                  'Copy Payment Link',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                ),
                subtitle: Text(
                  'Generate a fresh payment link for a friend or relative',
                  style: TextStyle(
                    color: mutedTextColor,
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _regenerateAndCopyPaymentLink(
                    orderId,
                    orderData,
                    hideOrderDetails: hideOrderDetails,
                  );
                },
              ),

              // Hide Order Details Toggle below Copy Payment Link
              Container(
                margin: EdgeInsets.only(top: 4.h, bottom: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
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
                      child: Icon(
                        hideOrderDetails ? LucideIcons.eyeOff : LucideIcons.eye,
                        color: purpleColor,
                        size: 18.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hide order details',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: AppTypography.font(AppFontSizes.bodySmall),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Conceal food items and choices from the payment link',
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: AppTypography.font(AppFontSizes.caption),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: hideOrderDetails,
                      activeTrackColor: purpleColor,
                      onChanged: (val) {
                        setModalState(() {
                          hideOrderDetails = val;
                        });
                      },
                    ),
                  ],
                ),
              ),

              Divider(color: borderColor),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.payment, color: Colors.green, size: 20.sp),
                ),
                title: Text(
                  'Pay Myself Now',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                ),
                subtitle: Text(
                  'Proceed with your own wallet or card',
                  style: TextStyle(
                    color: mutedTextColor,
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(
                    '/orders/pay-awaiting',
                    extra: {
                      'orderId': orderId,
                      'orderData': {
                        ...orderData,
                        'hideOrderDetails': hideOrderDetails,
                      },
                    },
                  );
                },
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _regenerateAndCopyPaymentLink(
    String orderId,
    Map<String, dynamic> orderData, {
    bool? hideOrderDetails,
  }) async {
    try {
      final oldToken = orderData['paymentToken']?.toString();
      if (oldToken != null && oldToken.isNotEmpty) {
        try {
          await _firestore.collection('payment_sessions').doc(oldToken).update({'status': 'cancelled'});
        } catch (_) {}
      }

      final bool effectiveHide = hideOrderDetails ?? (orderData['hideOrderDetails'] == true);
      final newToken = 'ps_${const Uuid().v4().replaceAll('-', '')}';
      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      final totalVal = orderData['total'];
      final amount = totalVal is num
          ? totalVal.toDouble()
          : double.tryParse(totalVal?.toString() ?? '') ?? 0.0;

      await _firestore.collection('payment_sessions').doc(newToken).set({
        'id': newToken,
        'token': newToken,
        'orderId': orderId,
        'customerId': orderData['customerId'] ?? _auth.currentUser?.uid ?? '',
        'customerName': orderData['customerName'] ?? 'Customer',
        'payerName': orderData['payerName'] ?? '',
        'payerEmail': orderData['payerEmail'] ?? '',
        'relationship': orderData['relationship'] ?? 'Anyone',
        'amount': amount,
        'status': 'active',
        'hideOrderDetails': effectiveHide,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('orders').doc(orderId).update({
        'paymentToken': newToken,
        'hideOrderDetails': effectiveHide,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update in-memory orderData for current session
      orderData['paymentToken'] = newToken;
      orderData['hideOrderDetails'] = effectiveHide;

      final newUrl = 'https://martfood-app.web.app/pay/$newToken';
      await Clipboard.setData(ClipboardData(text: newUrl));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New payment link generated and copied to clipboard!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error regenerating payment link: $e');
    }
  }

  String _formatCurrency(double amount) {
    final whole = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '₦$whole';
  }
}

enum OrderType { active, completed, cancelled }

class VendorVerificationBadge extends StatelessWidget {
  final String vendorId;
  final Map<String, dynamic> fallbackData;
  final double size;

  const VendorVerificationBadge({
    super.key,
    required this.vendorId,
    required this.fallbackData,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    if (vendorId.isEmpty) {
      return _buildFallback();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('vendors').doc(vendorId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final vendorData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final bpComplete = vendorData['businessProfileComplete']?.toString() == 'true';
          final physicalVerification = vendorData['physicalVerification'];
          final physicalVerified = (physicalVerification is Map)
              ? physicalVerification['status']?.toString() == 'verified'
              : false;
          final docComplete = vendorData['verificationDocumentsComplete']?.toString() == 'true';

          if (physicalVerified || docComplete || bpComplete) {
            return VerificationBadge(vendorData: vendorData, size: size);
          }

          final isVerified = vendorData['isVerified'] == true ||
              vendorData['isVerified']?.toString() == 'true' ||
              vendorData['isVendorVerified'] == true;
          if (isVerified) {
            return Icon(Icons.verified_rounded, color: const Color(0xFF34C759), size: size);
          }
        }
        return _buildFallback();
      },
    );
  }

  Widget _buildFallback() {
    final vendorMap = fallbackData['vendorData'] is Map
        ? Map<String, dynamic>.from(fallbackData['vendorData'])
        : fallbackData;
    final bpComplete = vendorMap['businessProfileComplete']?.toString() == 'true';
    final physicalVerification = vendorMap['physicalVerification'];
    final physicalVerified = (physicalVerification is Map)
        ? physicalVerification['status']?.toString() == 'verified'
        : false;
    final docComplete = vendorMap['verificationDocumentsComplete']?.toString() == 'true';

    if (physicalVerified || docComplete || bpComplete) {
      return VerificationBadge(vendorData: vendorMap, size: size);
    }

    return Icon(Icons.verified_rounded, color: const Color(0xFF34C759), size: size);
  }
}
