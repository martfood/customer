import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class RateRiderScreen extends StatefulWidget {
  final String orderId;
  final String riderId;
  final String riderName;
  final String riderPhoto;

  const RateRiderScreen({
    super.key,
    required this.orderId,
    required this.riderId,
    required this.riderName,
    required this.riderPhoto,
  });

  @override
  State<RateRiderScreen> createState() => _RateRiderScreenState();
}

class _RateRiderScreenState extends State<RateRiderScreen> {
  int _rating = 5;
  bool _isSubmitting = false;
  final TextEditingController _feedbackController = TextEditingController();
  final List<String> _labels = ['Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to rate the rider.')),
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
      final customerName =
          customerData['fullName'] ?? customerData['name'] ?? 'Customer';
      final customerAvatarUrl = customerData['profilePic'] ?? '';

      // Add review to rider's reviews subcollection
      if (widget.riderId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('riders')
            .doc(widget.riderId)
            .collection('reviews')
            .add({
          'rating': _rating.toDouble(),
          'comment': _feedbackController.text.trim().isNotEmpty
              ? _feedbackController.text.trim()
              : 'Great delivery service!',
          'customerId': user.uid,
          'customerName': customerName,
          'customerAvatarUrl': customerAvatarUrl,
          'orderId': widget.orderId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Mark order as rider rated
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'isRiderRated': true});

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
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
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
              'Your rating has been submitted successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                color: AppTheme.mutedTextColorFor(isDark),
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
        title: Text(
          'Rate Rider',
          style: TextStyle(
            color: purpleColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(18.w),
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
                            child: widget.riderPhoto.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.riderPhoto,
                                    width: 72.w,
                                    height: 72.w,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) =>
                                        Container(color: Colors.grey[200]),
                                    errorWidget: (_, __, ___) =>
                                        _buildRiderFallback(purpleColor),
                                  )
                                : _buildRiderFallback(purpleColor),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.riderName.isNotEmpty
                                      ? widget.riderName
                                      : 'MartFood Rider',
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: AppTypography.font(
                                      AppFontSizes.bodyLarge,
                                    ),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'How was your delivery service?',
                                  style: TextStyle(
                                    color: mutedTextColor,
                                    fontSize: AppTypography.font(
                                      AppFontSizes.bodySmall,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Your rating',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Tap the stars to rate your delivery rider.',
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodySmall),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final selected = index < _rating;
                              return IconButton(
                                onPressed: () => setState(() => _rating = index + 1),
                                icon: Icon(
                                  selected
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: purpleColor,
                                  size: 36.sp,
                                ),
                              );
                            }),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _labels[_rating - 1],
                            style: TextStyle(
                              color: purpleColor,
                              fontSize: AppTypography.font(
                                AppFontSizes.bodyLarge,
                              ),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Write a feedback',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Share notes about speed, politeness, or handling.',
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodySmall),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
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
                        maxLines: 4,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Optional: Leave feedback for the rider...',
                          hintStyle: TextStyle(
                            color: mutedTextColor,
                            fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 16.h),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 56.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
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
                        'Submit Rating',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderFallback(Color purpleColor) {
    return Container(
      width: 72.w,
      height: 72.w,
      color: purpleColor.withValues(alpha: 0.12),
      child: Icon(
        Icons.two_wheeler_rounded,
        color: purpleColor,
        size: 30.sp,
      ),
    );
  }
}
