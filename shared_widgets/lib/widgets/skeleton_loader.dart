import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theme/app_theme.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppTheme.borderRadius,
  });

  // ─── Vertical Food Card Shimmer Placeholder ──────────────────────────────
  static Widget verticalFoodCard({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      width: 260.w,
      height: 90.h + 20.h,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        children: [
          SkeletonLoader(width: 90.w, height: 90.w, borderRadius: 20.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonLoader(width: 140.w, height: 16.h, borderRadius: 4.r),
                  SkeletonLoader(width: 80.w, height: 12.h, borderRadius: 4.r),
                  Row(
                    children: [
                      SkeletonLoader(width: 50.w, height: 14.h, borderRadius: 4.r),
                      SizedBox(width: 8.w),
                      SkeletonLoader(width: 40.w, height: 14.h, borderRadius: 4.r),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Food Menu Item Shimmer Placeholder (Vendor Screen) ───────────────────
  static Widget foodMenuItem({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final borderColor = isDark ? Colors.grey[900]! : Colors.grey[200]!;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          SkeletonLoader(width: 80.w, height: 80.w, borderRadius: 12.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonLoader(width: 120.w, height: 16.h, borderRadius: 4.r),
                SizedBox(height: 8.h),
                SkeletonLoader(width: 160.w, height: 12.h, borderRadius: 4.r),
                SizedBox(height: 4.h),
                SkeletonLoader(width: 100.w, height: 12.h, borderRadius: 4.r),
                SizedBox(height: 12.h),
                SkeletonLoader(width: 60.w, height: 14.h, borderRadius: 4.r),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          SkeletonLoader(width: 32.w, height: 32.w, borderRadius: 16.r),
        ],
      ),
    );
  }

  // ─── Horizontal Food Card Shimmer Placeholder ────────────────────────────
  static Widget horizontalFoodCard({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final double cardWidth = 0.46.sw;
    final double imgHeight = cardWidth * 0.65;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SkeletonLoader(width: cardWidth, height: imgHeight, borderRadius: 20.r),
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 6.h, 10.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: cardWidth * 0.7, height: 14.h, borderRadius: 4.r),
                  SizedBox(height: 5.h),
                  Row(
                    children: [
                      Flexible(child: SkeletonLoader(width: 40.w, height: 11.h, borderRadius: 4.r)),
                      SizedBox(width: 6.w),
                      Flexible(child: SkeletonLoader(width: 32.w, height: 11.h, borderRadius: 4.r)),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  SkeletonLoader(width: 60.w, height: 14.h, borderRadius: 4.r),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Restaurant Card Shimmer Placeholder ──────────────────────────────────
  static Widget restaurantCard({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: double.infinity, height: 160.h, borderRadius: 20.r),
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              children: [
                SkeletonLoader(width: 48.w, height: 48.w, borderRadius: 12.r),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 120.w, height: 16.h, borderRadius: 4.r),
                      SizedBox(height: 6.h),
                      SkeletonLoader(width: 80.w, height: 12.h, borderRadius: 4.r),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SkeletonLoader(width: 60.w, height: 14.h, borderRadius: 4.r),
                    SizedBox(height: 6.h),
                    SkeletonLoader(width: 70.w, height: 12.h, borderRadius: 4.r),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Food Details Screen Shimmer Placeholder ─────────────────────────────
  static Widget foodDetails({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final dividerColor = isDark ? Colors.grey[850]! : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: bg,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image placeholder
            SkeletonLoader(width: double.infinity, height: 300.h, borderRadius: 0),

            // Title, price, description block
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 200.w, height: 22.h, borderRadius: 6.r),
                  SizedBox(height: 10.h),
                  SkeletonLoader(width: 100.w, height: 20.h, borderRadius: 6.r),
                  SizedBox(height: 14.h),
                  SkeletonLoader(width: double.infinity, height: 14.h, borderRadius: 4.r),
                  SizedBox(height: 6.h),
                  SkeletonLoader(width: 0.75.sw, height: 14.h, borderRadius: 4.r),
                  SizedBox(height: 6.h),
                  SkeletonLoader(width: 0.5.sw, height: 14.h, borderRadius: 4.r),
                ],
              ),
            ),

            // Menu group header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 120.w, height: 18.h, borderRadius: 4.r),
                  SizedBox(height: 6.h),
                  SkeletonLoader(width: 160.w, height: 13.h, borderRadius: 4.r),
                ],
              ),
            ),

            // Option rows
            ...List.generate(3, (_) => Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(width: 140.w, height: 15.h, borderRadius: 4.r),
                            SizedBox(height: 6.h),
                            SkeletonLoader(width: 80.w, height: 13.h, borderRadius: 4.r),
                          ],
                        ),
                      ),
                      SkeletonLoader(width: 22.w, height: 22.w, borderRadius: 11.r),
                    ],
                  ),
                ),
                Divider(height: 1, color: dividerColor, indent: 20.w, endIndent: 20.w),
              ],
            )),

            SizedBox(height: 90.h),
          ],
        ),
      ),
    );
  }

  // ─── Transaction Item Shimmer Placeholder ──────────────────────────────────
  static Widget transactionItem({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            SkeletonLoader(width: 56.w, height: 56.w, borderRadius: 28.r), // Circle
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 100.w, height: 16.h, borderRadius: 4.r),
                  SizedBox(height: 8.h),
                  SkeletonLoader(width: 120.w, height: 12.h, borderRadius: 4.r),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SkeletonLoader(width: 65.w, height: 16.h, borderRadius: 4.r),
                SizedBox(height: 8.h),
                SkeletonLoader(width: 45.w, height: 12.h, borderRadius: 4.r),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[900]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
