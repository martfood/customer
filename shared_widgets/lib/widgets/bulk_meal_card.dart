import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import 'verification_badge.dart';

class BulkMealCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final double price;
  final double? promoPrice;
  final String? vendorName;
  final bool isVerified;
  final Map<String, dynamic>? vendorData;
  final String orderTimeWindow;
  final String deliveryTimeWindow;
  final String? orderClosesText;
  final bool isClosed;
  final VoidCallback onTap;
  final VoidCallback? onAddTap;
  final double? width;
  final double? height;
  final double? imageAspectRatio;

  const BulkMealCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.price,
    this.promoPrice,
    this.vendorName,
    this.isVerified = true,
    this.vendorData,
    this.orderTimeWindow = '',
    this.deliveryTimeWindow = '',
    this.orderClosesText,
    this.isClosed = false,
    required this.onTap,
    this.onAddTap,
    this.width,
    this.height,
    this.imageAspectRatio,
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
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFF0E6FF);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

    final isFullWidth = width == double.infinity;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final double cardWidth = width ?? (isTablet ? 204.w : 240.w);

    final effectivePrice =
        (promoPrice != null && promoPrice! > 0) ? promoPrice! : price;
    final showBanner =
        orderClosesText != null && orderClosesText!.trim().isNotEmpty;
    final bannerText = showBanner ? orderClosesText!.trim() : '';

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
            : onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          children: [
            Container(
              width: cardWidth,
              height: height,
              padding: isFullWidth
                  ? EdgeInsets.all(12.w)
                  : (isTablet
                      ? EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h)
                      : EdgeInsets.symmetric(horizontal: 7.w, vertical: 6.8.h)),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Food Image ─────────────────────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: AspectRatio(
                        aspectRatio: imageAspectRatio ??
                            (isFullWidth ? (16 / 9) : (4 / 3)),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: double.infinity,
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                            child: Icon(LucideIcons.image,
                                color: Colors.grey[500],
                                size: isTablet ? 22.sp : 20.sp),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: double.infinity,
                            color: purpleColor,
                            alignment: Alignment.center,
                            child: Text(
                              title.trim().isNotEmpty
                                  ? title.trim()[0].toUpperCase()
                                  : 'F',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 22 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                        height: isFullWidth ? 10.h : (isTablet ? 6.h : 5.h)),

                    // ── Title ──────────────────────────────────────────────────
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isFullWidth ? 16 : (isTablet ? 14 : 13.5),
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(
                        height: isFullWidth ? 4.h : (isTablet ? 2.h : 1.8.h)),

                    // ── Price & Add Button Row ─────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _priceLabel(effectivePrice),
                            style: TextStyle(
                              fontSize:
                                  isFullWidth ? 16.5 : (isTablet ? 15.5 : 14.5),
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
                            width:
                                isFullWidth ? 26.w : (isTablet ? 20.w : 19.w),
                            height:
                                isFullWidth ? 26.w : (isTablet ? 20.w : 19.w),
                            decoration: BoxDecoration(
                              color: purpleColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add,
                                color: Colors.white,
                                size: isFullWidth ? 16 : (isTablet ? 14 : 12)),
                          ),
                        ),
                      ],
                    ),

                    // ── Vendor Subline with Verified Badge ────────────────────
                    if (vendorName != null && vendorName!.isNotEmpty) ...[
                      SizedBox(
                          height: isFullWidth ? 4.h : (isTablet ? 2.h : 1.8.h)),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              vendorName!,
                              style: TextStyle(
                                fontSize:
                                    isFullWidth ? 13 : (isTablet ? 11 : 10.5),
                                color: isDark
                                    ? Colors.grey[300]
                                    : const Color(0xFF333333),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (vendorData != null) ...[
                            SizedBox(width: 4.w),
                            VerificationBadge(
                                vendorData: vendorData!,
                                size: isFullWidth ? 13 : (isTablet ? 11 : 10)),
                          ] else if (isVerified) ...[
                            SizedBox(width: 4.w),
                            Icon(Icons.verified,
                                color: const Color(0xFF2563EB),
                                size: isFullWidth ? 14 : (isTablet ? 12 : 11)),
                          ],
                        ],
                      ),
                    ],

                    // ── Hairline Divider ──────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: isFullWidth ? 8.h : (isTablet ? 4.h : 3.h)),
                      child: Container(
                        height: 1,
                        color: isDark
                            ? AppTheme.darkBorder
                            : const Color(0xFFF1F1F5),
                      ),
                    ),

                    // ── Timing Row: Order time ────────────────────────────────
                    if (orderTimeWindow.trim().isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.clock,
                                  size: isFullWidth ? 14 : (isTablet ? 12 : 11),
                                  color: purpleColor),
                              SizedBox(width: 6.w),
                              Text(
                                'Order from',
                                style: TextStyle(
                                  fontSize:
                                      isFullWidth ? 13 : (isTablet ? 11 : 10.5),
                                  color: mutedTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Flexible(
                            child: Text(
                              orderTimeWindow,
                              style: TextStyle(
                                fontSize:
                                    isFullWidth ? 13 : (isTablet ? 11 : 10.5),
                                color: isDark
                                    ? Colors.grey[300]
                                    : const Color(0xFF333333),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                          height: isFullWidth ? 6.h : (isTablet ? 2.h : 1.8.h)),
                    ],

                    // ── Timing Row: Delivery time ─────────────────────────────
                    if (deliveryTimeWindow.trim().isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.calendar,
                                  size: isFullWidth ? 14 : (isTablet ? 12 : 11),
                                  color: purpleColor),
                              SizedBox(width: 6.w),
                              Text(
                                'Delivery time',
                                style: TextStyle(
                                  fontSize:
                                      isFullWidth ? 13 : (isTablet ? 11 : 10.5),
                                  color: mutedTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Flexible(
                            child: Text(
                              deliveryTimeWindow,
                              style: TextStyle(
                                fontSize:
                                    isFullWidth ? 13 : (isTablet ? 11 : 10.5),
                                color: isDark
                                    ? Colors.grey[300]
                                    : const Color(0xFF333333),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                          height: isFullWidth ? 10.h : (isTablet ? 5.h : 4.h)),
                    ],

                    // ── Status Pill Banner ────────────────────────────────────
                    if (showBanner) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                            vertical:
                                isFullWidth ? 7.h : (isTablet ? 3.5.h : 3.h),
                            horizontal: 8.w),
                        decoration: BoxDecoration(
                          color: isDark
                              ? purpleColor.withValues(alpha: 0.18)
                              : const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(
                              isFullWidth ? 20.r : (isTablet ? 10.r : 8.r)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.clock,
                                size: isFullWidth ? 13 : 10,
                                color: purpleColor),
                            SizedBox(width: 5.w),
                            Flexible(
                              child: Text(
                                bannerText,
                                style: TextStyle(
                                  fontSize: isFullWidth ? 12 : 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: purpleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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
              ),
          ],
        ),
      ),
    );
  }
}
