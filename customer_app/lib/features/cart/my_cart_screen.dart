import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyCartScreen extends StatefulWidget {
  const MyCartScreen({super.key});

  @override
  State<MyCartScreen> createState() => _MyCartScreenState();
}

class _MyCartScreenState extends State<MyCartScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> _updateQuantity(String docId, int newQuantity) async {
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

  Future<void> _removeItem(String docId) async {
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

  Future<bool?> _showDeleteConfirmationBottomSheet(
    BuildContext context,
    String itemTitle,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : Colors.white;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textClr = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedClr = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            border: Border.all(color: border, width: 1),
            boxShadow: null,
          ),
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 28.h),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.trash2,
                    color: Colors.red,
                    size: 26.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Remove from Cart?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                    fontWeight: FontWeight.w800,
                    color: textClr,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Are you sure you want to remove "$itemTitle" from your cart?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w500,
                    color: mutedClr,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: isDark ? Colors.white : textClr,
                          side: BorderSide(color: border, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          elevation: 0,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize:
                                AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : textClr,
                          ),
                        ),
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
                        child: Text(
                          'Remove',
                          style: TextStyle(
                            fontSize:
                                AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            "Please log in to view your cart",
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
        centerTitle: true,
        title: Text(
          'My Cart',
          style: TextStyle(
            color: purpleColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('customers')
            .doc(user.uid)
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
                        color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
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
                    return _buildCartItem(
                      context,
                      item,
                      isDark,
                      surfaceColor,
                      borderColor,
                      purpleColor,
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
                              '₦${subtotal.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
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
      ),
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color purpleColor, {
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
    final primaryTextColor = isDark ? Colors.white : Colors.black87;

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        final confirmed =
            await _showDeleteConfirmationBottomSheet(context, title);
        return confirmed == true;
      },
      onDismissed: (direction) async {
        await _removeItem(docId);
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
                                _buildQuantityButton(LucideIcons.minus, () {
                                  if (quantity > 1) {
                                    _updateQuantity(docId, quantity - 1);
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
                                _buildQuantityButton(LucideIcons.plus, () {
                                  _updateQuantity(docId, quantity + 1);
                                }, isDark, purpleColor, borderColor, isPrimary: true),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '₦${price.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                            fontWeight: FontWeight.w800,
                            color: purpleColor,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                restaurant,
                                style: TextStyle(
                                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                        final confirmed =
                            await _showDeleteConfirmationBottomSheet(
                                context, title);
                        if (confirmed == true) {
                          await _removeItem(docId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$title removed from cart'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
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

  Widget _buildQuantityButton(
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
}
