import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import 'verification_badge.dart';

class FoodCardHorizontal extends StatelessWidget {
  final String title;
  final String imageUrl;
  final double rating;
  final int reviewsCount;
  final double distanceKm;
  final double? basePrice;
  final double? promoPrice;
  final bool isPromo;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback? onAddTap;
  final bool isClosed;
  final bool isOutOfStock;
  final String? vendorName;
  final bool isVerified;
  final String? deliveryTime;
  final Map<String, dynamic>? vendorData;
  final double? width;
  final Color? backgroundColor;
  final String? categoryName;

  const FoodCardHorizontal({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.reviewsCount,
    required this.distanceKm,
    this.basePrice,
    this.promoPrice,
    this.isPromo = false,
    this.isFavorite = false,
    required this.onTap,
    required this.onFavoriteTap,
    this.onAddTap,
    this.isClosed = false,
    this.isOutOfStock = false,
    this.vendorName,
    this.isVerified = true,
    this.deliveryTime,
    this.vendorData,
    this.width,
    this.backgroundColor,
    this.categoryName,
  });

  /// Formats price with thousand-separator commas e.g. ₦2,500
  String _priceLabel(double val) {
    final int kobo = ((val % 1) * 100).round();
    final String whole = val.toInt().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return kobo > 0 ? '₦$whole.${kobo.toString().padLeft(2, '0')}' : '₦$whole';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final surfaceColor = backgroundColor ?? (isDark ? AppTheme.darkSurface : Colors.white);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final bool hasPromo = promoPrice != null && promoPrice! > 0;
    final bool hasBase = basePrice != null && basePrice! > 0;
    final bool showPrice = hasBase || hasPromo;

    final isTablet = MediaQuery.of(context).size.shortestSide >= 600 ||
        MediaQuery.of(context).size.width >= 600;
    final double cardWidth = width ?? (isTablet ? 133.w : 155.w);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isClosed
            ? () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Ordering is disabled as this store is currently closed'),
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
        child: Stack(
          children: [
            Container(
              width: cardWidth,
              padding: isTablet
                  ? EdgeInsets.symmetric(horizontal: 7.w, vertical: 6.h)
                  : EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Image ──────────────────────────────────────────────────
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: double.infinity,
                              color: isDark
                                  ? Colors.grey[900]
                                  : Colors.grey[200],
                              child: Icon(LucideIcons.image,
                                  color: Colors.grey[500],
                                  size: isTablet ? 18.sp : 24.sp),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: double.infinity,
                              color: purpleColor,
                              alignment: Alignment.center,
                              child: Text(
                                title.trim().isNotEmpty
                                    ? title.trim()[0].toUpperCase()
                                    : 'F',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isPromo)
                        Positioned(
                          top: isTablet ? 4.h : 6.h,
                          left: isTablet ? 4.w : 6.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 6.w : 8.w,
                                vertical: isTablet ? 2.h : 3.h),
                            decoration: BoxDecoration(
                              color: purpleColor,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: const Text(
                              'PROMO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: isTablet ? 5.h : 6.h),

                  // ── Title ──────────────────────────────────────────────────
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isTablet ? 15 : 14,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isTablet ? 4.h : 4.h),

                  // ── Price / Add Button ──────────────────────────────────────
                  if (showPrice) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            hasPromo
                                ? _priceLabel(promoPrice!)
                                : _priceLabel(basePrice!),
                            style: TextStyle(
                              fontSize: isTablet ? 15.5 : 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : purpleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: onAddTap ?? onTap,
                          child: Container(
                            width: isTablet ? 20.w : 22.w,
                            height: isTablet ? 20.w : 22.w,
                            decoration: BoxDecoration(
                              color: purpleColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add,
                                color: Colors.white,
                                size: isTablet ? 15 : 13),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Category / Vendor Subline ─────────────────────────────
                  if (categoryName != null && categoryName!.isNotEmpty) ...[
                    SizedBox(height: isTablet ? 3.h : 3.h),
                    Text(
                      categoryName!,
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 11.5,
                        color: mutedTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (vendorName != null && vendorName!.isNotEmpty) ...[
                    SizedBox(height: isTablet ? 3.h : 3.h),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vendorName!,
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 11.5,
                              color: mutedTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vendorData != null) ...[
                          SizedBox(width: 4.w),
                          VerificationBadge(
                              vendorData: vendorData!,
                              size: isTablet ? 12 : 11),
                        ] else if (isVerified) ...[
                          SizedBox(width: 4.w),
                          Icon(Icons.verified,
                              color: Colors.blue,
                              size: isTablet ? 12 : 11),
                        ],
                      ],
                    ),
                  ],
                ],
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
                      padding:
                          EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Text(
                        'CLOSED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Text(
                        'OUT OF STOCK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
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
      ),
    );
  }
}
