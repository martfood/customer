import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import 'verification_badge.dart';

class FoodCardVertical extends StatelessWidget {
  final String title;
  final String imageUrl;
  final double rating;
  final int reviewsCount;
  final int distanceM;
  final double? basePrice;
  final double? promoPrice;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final Widget? badge;
  final double? deliveryFee;
  final bool isClosed;
  final bool isOutOfStock;
  final bool isVerified;
  final String? deliveryTime;
  final Map<String, dynamic>? vendorData;

  const FoodCardVertical({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.reviewsCount,
    required this.distanceM,
    this.basePrice,
    this.promoPrice,
    this.isFavorite = false,
    required this.onTap,
    required this.onFavoriteTap,
    this.badge,
    this.deliveryFee,
    this.isClosed = false,
    this.isOutOfStock = false,
    this.isVerified = true,
    this.deliveryTime,
    this.vendorData,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final isTablet = MediaQuery.of(context).size.width >= 600;
    final double cardWidth = isTablet ? 182.w : 230.w;
    final double imgHeight = isTablet ? 108.h : 135.h;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isClosed
            ? () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ordering is disabled as this store is currently closed'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            : isOutOfStock
                ? () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This item is currently out of stock'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                : onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: cardWidth,
          padding: EdgeInsets.all(isTablet ? 6.w : 8.w),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top Store Image ──────────────────────────────────────────
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: cardWidth,
                      height: imgHeight,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: cardWidth,
                        height: imgHeight,
                        color: isDark ? Colors.grey[900] : Colors.grey[200],
                        child: Icon(LucideIcons.image, color: Colors.grey[500], size: isTablet ? 18.sp : 24.sp),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: cardWidth,
                        height: imgHeight,
                        color: purpleColor,
                        alignment: Alignment.center,
                        child: Text(
                          title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : 'F',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isClosed)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: isTablet ? 10.w : 14.w, vertical: isTablet ? 4.h : 6.h),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: const Text(
                              'CLOSED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: isTablet ? 8.w : 10.w, vertical: isTablet ? 4.h : 5.h),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: isTablet ? 6.h : 8.h),

              // ── Store Title + Verified Badge + Heart Icon ──────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vendorData != null) ...[
                          SizedBox(width: 4.w),
                          VerificationBadge(vendorData: vendorData!, size: 14),
                        ] else if (isVerified) ...[
                          SizedBox(width: 4.w),
                          const Icon(Icons.verified, color: Colors.blue, size: 14),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onFavoriteTap,
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.redAccent : Colors.grey[400],
                      size: 19,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 4.h : 5.h),

              // ── Details Row: Rating & Delivery Time ────────────────────────
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  SizedBox(width: 3.w),
                  Text(
                    '$rating ($reviewsCount)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: mutedTextColor,
                    ),
                  ),
                  SizedBox(width: isTablet ? 8.w : 12.w),
                  Icon(Icons.location_on_outlined, size: 14, color: purpleColor),
                  SizedBox(width: 3.w),
                  Text(
                    deliveryTime ?? '10 - 15 min',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: mutedTextColor,
                    ),
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

