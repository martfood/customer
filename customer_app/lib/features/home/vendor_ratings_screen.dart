import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class VendorRatingsScreen extends StatelessWidget {
  final String vendorId;
  final String vendorName;

  const VendorRatingsScreen({
    super.key,
    required this.vendorId,
    required this.vendorName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF7F7F7);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Ratings & Reviews',
          style: TextStyle(
            fontSize: AppTypography.font(AppFontSizes.headlineSmall),
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendors')
            .doc(vendorId)
            .collection('reviews')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final reviews = snapshot.data?.docs ?? [];

          // ── Compute stats ──────────────────────────────────────────
          final double average = reviews.isEmpty
              ? 0.0
              : reviews
                      .map((r) =>
                          (r.data() as Map<String, dynamic>)['rating'] as num? ??
                          0)
                      .reduce((a, b) => a + b) /
                  reviews.length;

          // Count per star (1–5)
          final Map<int, int> starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
          for (final r in reviews) {
            final data = r.data() as Map<String, dynamic>;
            final star = ((data['rating'] as num?) ?? 0).round().clamp(1, 5);
            starCounts[star] = (starCounts[star] ?? 0) + 1;
          }

          return CustomScrollView(
            slivers: [
              // ── Summary Card ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.all(16.w),
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withAlpha(60)
                            : Colors.black.withAlpha(13),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Vendor name
                      Text(
                        vendorName,
                        style: TextStyle(
                          fontSize: AppTypography.font(15),
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Big average number
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            reviews.isEmpty
                                ? '—'
                                : average.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: AppTypography.font(52),
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black,
                              height: 1,
                            ),
                          ),
                          if (reviews.isNotEmpty) ...[
                            SizedBox(width: 4.w),
                            Text(
                              '/ 5',
                              style: TextStyle(
                                  fontSize: AppTypography.font(AppFontSizes.headlineSmall), color: Colors.grey[500]),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 6.h),

                      // Star row
                      _StarRow(rating: average),
                      SizedBox(height: 4.h),
                      Text(
                        reviews.isEmpty
                            ? 'No reviews yet'
                            : '${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'}',
                        style: TextStyle(
                            fontSize: AppTypography.font(13), color: Colors.grey[500]),
                      ),

                      SizedBox(height: 20.h),

                      // Star breakdown bars
                      ...List.generate(5, (i) {
                        final star = 5 - i;
                        final count = starCounts[star] ?? 0;
                        final pct = reviews.isEmpty ? 0.0 : count / reviews.length;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 6.h),
                          child: Row(
                            children: [
                              Text(
                                '$star',
                                style: TextStyle(
                                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 4.w),
                              Icon(Icons.star_rounded,
                                  size: 12.sp, color: Colors.amber),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4.r),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 7.h,
                                    backgroundColor: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            AppTheme.primaryColor),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              SizedBox(
                                width: 24.w,
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                      fontSize: AppTypography.font(AppFontSizes.caption),
                                      color: Colors.grey[500]),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // ── Section header ──────────────────────────────────────
              if (reviews.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                    child: Text(
                      'Customer Reviews',
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),

              // ── Review Cards ────────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 40.h),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final data =
                          reviews[index].data() as Map<String, dynamic>;
                      final customerName =
                          data['customerName'] ?? 'Customer';
                      final avatarUrl = data['customerAvatarUrl'] ?? '';
                      final comment = data['comment'] ?? '';
                      final orderSummary = data['orderSummary'] ?? '';
                      final starRating =
                          ((data['rating'] as num?) ?? 0).toDouble();
                      final ts = data['createdAt'];
                      String dateStr = '';
                      if (ts is Timestamp) {
                        final dt = ts.toDate();
                        dateStr =
                            '${dt.day}/${dt.month}/${dt.year}';
                      }

                      return Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withAlpha(50)
                                  : Colors.black.withAlpha(10),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reviewer row
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20.r,
                                  backgroundColor: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                  backgroundImage: avatarUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                                  child: avatarUrl.isEmpty
                                      ? Icon(Icons.person_rounded,
                                          size: 20.sp,
                                          color: Colors.grey[500])
                                      : null,
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customerName,
                                        style: TextStyle(
                                          fontSize: AppTypography.font(13),
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      if (dateStr.isNotEmpty)
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                              fontSize: AppTypography.font(10),
                                              color: Colors.grey[500]),
                                        ),
                                    ],
                                  ),
                                ),
                                // Star badge
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withAlpha(20),
                                    borderRadius:
                                        BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded,
                                          size: 13.sp, color: Colors.amber),
                                      SizedBox(width: 3.w),
                                      Text(
                                        starRating % 1 == 0
                                            ? starRating.toInt().toString()
                                            : starRating
                                                .toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Order summary chip
                            if (orderSummary.isNotEmpty) ...[
                              SizedBox(height: 8.h),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  orderSummary,
                                  style: TextStyle(
                                      fontSize: AppTypography.font(10),
                                      color: Colors.grey[500]),
                                ),
                              ),
                            ],

                            // Comment
                            if (comment.isNotEmpty) ...[
                              SizedBox(height: 8.h),
                              Text(
                                comment,
                                style: TextStyle(
                                  fontSize: AppTypography.font(13),
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    childCount: reviews.length,
                  ),
                ),
              ),

              // Empty state
              if (reviews.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rate_review_outlined,
                            size: 64.sp, color: Colors.grey[400]),
                        SizedBox(height: 16.h),
                        Text(
                          'No reviews yet',
                          style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500]),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Be the first to leave a review!',
                          style: TextStyle(
                              fontSize: AppTypography.font(13), color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Renders a row of filled/half/empty stars
class _StarRow extends StatelessWidget {
  final double rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        final half = !filled && rating >= i + 0.5;
        return Icon(
          filled
              ? Icons.star_rounded
              : half
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
          color: Colors.amber,
          size: 22.sp,
        );
      }),
    );
  }
}
