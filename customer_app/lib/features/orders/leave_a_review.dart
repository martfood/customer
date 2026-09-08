import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/bottom_nav_bar.dart';
import 'package:shared_widgets/widgets/verification_badge.dart';

class LeaveAReviewScreen extends StatefulWidget {
  final String restaurantName;
  final String imageUrl;
  final String vendorId;
  final String orderId;
  final String itemsSummary;
  final double? price;

  const LeaveAReviewScreen({
    super.key,
    required this.restaurantName,
    required this.imageUrl,
    required this.vendorId,
    required this.orderId,
    required this.itemsSummary,
    this.price,
  });

  @override
  State<LeaveAReviewScreen> createState() => _LeaveAReviewScreenState();
}

class _LeaveAReviewScreenState extends State<LeaveAReviewScreen> {
  int _rating = 5;
  bool _isSubmitting = false;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submitReview() async {
    if (widget.vendorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor identity not found.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to leave a review.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();

      final customerData = customerDoc.data() ?? {};
      final customerName = customerData['fullName'] ?? customerData['name'] ?? 'Customer';
      final customerAvatarUrl = customerData['profilePic'] ?? '';

      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.vendorId)
          .collection('reviews')
          .add({
        'rating': _rating.toDouble(),
        'comment': _feedbackController.text.trim().isNotEmpty
            ? _feedbackController.text.trim()
            : 'Excellent service and delicious food!',
        'customerId': user.uid,
        'customerName': customerName,
        'customerAvatarUrl': customerAvatarUrl,
        'orderId': widget.orderId,
        'orderSummary': widget.itemsSummary.isNotEmpty ? widget.itemsSummary : 'MartFood Order',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'isReviewed': true});

      if (mounted) {
        _showSuccessBottomSheet(context, Theme.of(context).brightness == Brightness.dark);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessBottomSheet(BuildContext context, bool isDark) {
    final nav = Navigator.of(context);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => Padding(
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
            Image.asset(
              'lib/assets/emoji/happy_face.png',
              width: 90.w,
              height: 90.w,
              errorBuilder: (_, __, ___) => Icon(Icons.check_circle, color: purpleColor, size: 90.sp),
            ),
            SizedBox(height: 20.h),
            Text(
              'Thank You! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.headlineLarge),
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Your review has been submitted successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                color: mutedTextColor,
                height: 1.5,
              ),
            ),
            SizedBox(height: 28.h),
            ElevatedButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 54.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) nav.pop();
    });
  }

  String _formatPrice(double? price) {
    if (price == null || price == 0.0) return '₦2500';
    return '₦${price.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _getFoodTitle() {
    if (widget.itemsSummary.isNotEmpty) {
      final firstItem = widget.itemsSummary.split(',').first.trim();
      return firstItem.replaceAll(RegExp(r'^\d+x\s*'), '');
    }
    return 'Beef Burger';
  }

  String _getShortOrderId() {
    if (widget.orderId.isEmpty) return '01234567';
    if (widget.orderId.length > 8) return widget.orderId.substring(0, 8);
    return widget.orderId;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final foodTitle = _getFoodTitle();
    final displayOrderId = _getShortOrderId();
    final displayPrice = _formatPrice(widget.price);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: isDark ? Colors.white : purpleColor,
            size: 22.sp,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Leave Review',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: AppTypography.font(AppFontSizes.bodyLarge),
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                child: Responsive.maxContainer(
                  context: context,
                  maxWidth: 650,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Card: Food Item & Order Details
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: borderColor,
                            width: 1,
                          ),
                          boxShadow: null,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18.r),
                              child: widget.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: widget.imageUrl,
                                      width: 86.w,
                                      height: 86.w,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          _buildRestaurantFallback(purpleColor, isDark),
                                    )
                                  : _buildRestaurantFallback(purpleColor, isDark),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          foodTitle,
                                          style: TextStyle(
                                            color: primaryTextColor,
                                            fontSize: AppTypography.font(
                                              AppFontSizes.bodyLarge,
                                            ),
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        'Order $displayOrderId',
                                        style: TextStyle(
                                          color: mutedTextColor,
                                          fontSize: AppTypography.font(
                                            AppFontSizes.caption,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    displayPrice,
                                    style: TextStyle(
                                      color: purpleColor,
                                      fontSize: AppTypography.font(
                                        AppFontSizes.bodyLarge,
                                      ),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.restaurantName,
                                          style: TextStyle(
                                            color: mutedTextColor,
                                            fontSize: AppTypography.font(
                                              AppFontSizes.bodySmall,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (widget.vendorId.isNotEmpty) ...[
                                        SizedBox(width: 4.w),
                                        StreamBuilder<DocumentSnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('vendors')
                                              .doc(widget.vendorId)
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData &&
                                                snapshot.data != null &&
                                                snapshot.data!.exists) {
                                              final vendorData = snapshot.data!.data()
                                                      as Map<String, dynamic>? ??
                                                  {};
                                              final bpComplete = vendorData[
                                                          'businessProfileComplete']
                                                      ?.toString() ==
                                                  'true';
                                              final physicalVerification =
                                                  vendorData['physicalVerification'];
                                              final physicalVerified =
                                                  (physicalVerification is Map)
                                                      ? physicalVerification['status']
                                                              ?.toString() ==
                                                          'verified'
                                                      : false;
                                              final docComplete = vendorData[
                                                          'verificationDocumentsComplete']
                                                      ?.toString() ==
                                                  'true';

                                              if (physicalVerified ||
                                                  docComplete ||
                                                  bpComplete) {
                                                return VerificationBadge(
                                                    vendorData: vendorData,
                                                    size: 14.sp);
                                              }

                                              final isVerified =
                                                  vendorData['isVerified'] == true ||
                                                      vendorData['isVerified']
                                                              ?.toString() ==
                                                          'true' ||
                                                      vendorData['isVendorVerified'] ==
                                                          true;
                                              if (isVerified) {
                                                return Icon(Icons.verified_rounded,
                                                    color: const Color(0xFF34C759),
                                                    size: 14.sp);
                                              }
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                      // Middle Card: Rating Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: borderColor,
                            width: 1,
                          ),
                          boxShadow: null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              'How was your food experience ?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final selected = index < _rating;
                                return GestureDetector(
                                  onTap: () => setState(() => _rating = index + 1),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                                    child: Icon(
                                      selected
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: const Color(0xFFFFC107),
                                      size: 36.sp,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      // Write a Review Header
                      Text(
                        'Write a Review',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      // Write a Review Input Container
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: borderColor,
                            width: 1,
                          ),
                          boxShadow: null,
                        ),
                        child: TextField(
                          controller: _feedbackController,
                          maxLines: 5,
                          minLines: 4,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Excellent quality. Arrived on time. Very reliable',
                            hintStyle: TextStyle(
                              color: AppTheme.hintColorFor(isDark),
                              fontSize: AppTypography.font(AppFontSizes.bodySmall),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Submit Button
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
              child: Responsive.maxContainer(
                context: context,
                maxWidth: 650,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 24.w,
                            height: 24.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MartFoodBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) context.go('/home');
          if (index == 1) context.go('/search');
          if (index == 2) context.go('/orders');
          if (index == 3) context.go('/profile/customer-service');
          if (index == 4) context.go('/profile');
        },
      ),
    );
  }

  Widget _buildRestaurantFallback(Color purpleColor, bool isDark) {
    return Container(
      width: 86.w,
      height: 86.w,
      color: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Icon(
        Icons.fastfood,
        color: purpleColor,
        size: 32.sp,
      ),
    );
  }
}
