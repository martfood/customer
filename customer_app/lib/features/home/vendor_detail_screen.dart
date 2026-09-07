import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/verification_badge.dart';

class VendorDetailScreen extends StatelessWidget {
  final String vendorId;

  const VendorDetailScreen({
    super.key,
    required this.vendorId,
  });

  String _getTodayOperatingHoursText(Map<String, dynamic>? operatingHours) {
    if (operatingHours == null) return 'Open 24/7';
    final now = DateTime.now();
    final weekday = now.weekday;

    const weekdayKeys = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    final dayKey = weekdayKeys[weekday];
    if (dayKey == null) return 'Open today';

    final dayConfig = operatingHours[dayKey] as Map<String, dynamic>?;
    if (dayConfig == null) return 'Open today';

    final bool isClosedToday = dayConfig['closed'] == true;
    if (isClosedToday) return 'Closed today';

    final String? openStr = dayConfig['open'] as String?;
    final String? closeStr = dayConfig['close'] as String?;
    if (openStr == null || openStr.isEmpty || closeStr == null || closeStr.isEmpty) {
      return 'Open today';
    }

    return 'Open till $closeStr • Mon - Sat';
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      return '';
    }

    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('vendors').doc(vendorId).snapshots(),
      builder: (context, vendorSnapshot) {
        if (vendorSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              backgroundColor: purpleColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        if (!vendorSnapshot.hasData || !vendorSnapshot.data!.exists) {
          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              backgroundColor: purpleColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            body: const Center(
              child: Text('Vendor details not found.'),
            ),
          );
        }

        final vendorData = vendorSnapshot.data!.data() as Map<String, dynamic>;
        final profile = vendorData['businessProfile'] as Map<String, dynamic>?;
        final name = profile?['businessName'] ?? 'Vendor';
        final about = profile?['about'] ?? profile?['description'] ?? profile?['tagline'] ?? '';
        final location = profile?['address'] ?? profile?['businessAddress'] ?? profile?['locationAddress'] ?? '';
        final operatingHoursText = _getTodayOperatingHoursText(vendorData['operatingHours'] as Map<String, dynamic>?);

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: purpleColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseAuth.instance.currentUser != null
                    ? FirebaseFirestore.instance
                        .collection('customers')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .snapshots()
                    : null,
                builder: (context, customerSnapshot) {
                  final customerData = customerSnapshot.data?.data() as Map<String, dynamic>?;
                  final favorites = List<String>.from(customerData?['favoriteRestaurants'] ?? []);
                  final isFav = favorites.contains(vendorId);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                    onPressed: () async {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return;
                      final docRef = FirebaseFirestore.instance.collection('customers').doc(uid);
                      if (isFav) {
                        await docRef.update({
                          'favoriteRestaurants': FieldValue.arrayRemove([vendorId])
                        });
                      } else {
                        await docRef.update({
                          'favoriteRestaurants': FieldValue.arrayUnion([vendorId])
                        });
                      }
                    },
                  );
                },
              ),
              SizedBox(width: 8.w),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('vendors')
                .doc(vendorId)
                .collection('reviews')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, reviewsSnapshot) {
              final reviews = reviewsSnapshot.data?.docs ?? [];
              double avgRating = 0.0;
              if (reviews.isNotEmpty) {
                avgRating = reviews
                        .map((r) => ((r.data() as Map<String, dynamic>)['rating'] as num? ?? 0))
                        .reduce((a, b) => a + b) /
                    reviews.length;
              }
              final ratingLabel = reviews.isEmpty
                  ? 'No ratings yet'
                  : '${avgRating.toStringAsFixed(1)} (${reviews.length})';

              return SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Store Title & Badge ────────────────────────────────
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: AppTypography.font(22),
                              fontWeight: FontWeight.w900,
                              color: purpleColor,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        VerificationBadge(
                          vendorData: vendorData,
                          size: 20,
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),

                    // ── About Section ──────────────────────────────────────
                    if (about.toString().trim().isNotEmpty) ...[
                      Text(
                        'About',
                        style: TextStyle(
                          fontSize: AppTypography.font(16),
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        about.toString(),
                        style: TextStyle(
                          fontSize: AppTypography.font(14),
                          color: mutedTextColor,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Divider(color: borderColor, height: 1),
                      SizedBox(height: 24.h),
                    ],

                    // ── Location Section ───────────────────────────────────
                    if (location.toString().trim().isNotEmpty) ...[
                      Text(
                        'Location',
                        style: TextStyle(
                          fontSize: AppTypography.font(16),
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        location.toString(),
                        style: TextStyle(
                          fontSize: AppTypography.font(14),
                          color: mutedTextColor,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Divider(color: borderColor, height: 1),
                      SizedBox(height: 24.h),
                    ],

                    // ── Opening Hours Section ──────────────────────────────
                    Text(
                      'Opening hours',
                      style: TextStyle(
                        fontSize: AppTypography.font(16),
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      operatingHoursText,
                      style: TextStyle(
                        fontSize: AppTypography.font(14),
                        color: mutedTextColor,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Divider(color: borderColor, height: 1),
                    SizedBox(height: 24.h),

                    // ── Reviews & Ratings Section ──────────────────────────
                    Text(
                      'Reviews & Ratings',
                      style: TextStyle(
                        fontSize: AppTypography.font(16),
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 20, color: Colors.amber),
                        SizedBox(width: 6.w),
                        Text(
                          ratingLabel,
                          style: TextStyle(
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // Reviews List
                    if (reviews.isEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        child: Center(
                          child: Text(
                            'No customer reviews yet.',
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: AppTypography.font(13),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reviews.length,
                        separatorBuilder: (_, __) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final rData = reviews[index].data() as Map<String, dynamic>;
                          final customerName = rData['customerName'] ?? rData['userName'] ?? 'Leslie';
                          final comment = rData['comment'] ?? rData['review'] ?? '';
                          final ratingVal = ((rData['rating'] as num?) ?? 5).toDouble();
                          final timeAgoStr = _timeAgo(rData['createdAt']);
                          final photos = List<String>.from(rData['photos'] ?? rData['images'] ?? []);

                          return Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      customerName,
                                      style: TextStyle(
                                        fontSize: AppTypography.font(14),
                                        fontWeight: FontWeight.w800,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    if (timeAgoStr.isNotEmpty)
                                      Text(
                                        timeAgoStr,
                                        style: TextStyle(
                                          fontSize: AppTypography.font(12),
                                          color: mutedTextColor,
                                        ),
                                      ),
                                  ],
                                ),
                                if (comment.toString().trim().isNotEmpty) ...[
                                  SizedBox(height: 6.h),
                                  Text(
                                    comment.toString(),
                                    style: TextStyle(
                                      fontSize: AppTypography.font(13),
                                      color: mutedTextColor,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                if (photos.isNotEmpty) ...[
                                  SizedBox(height: 10.h),
                                  SizedBox(
                                    height: 60.h,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: photos.length,
                                      separatorBuilder: (_, __) => SizedBox(width: 8.w),
                                      itemBuilder: (context, pIdx) {
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(10.r),
                                          child: CachedNetworkImage(
                                            imageUrl: photos[pIdx],
                                            width: 60.h,
                                            height: 60.h,
                                            fit: BoxFit.cover,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                SizedBox(height: 8.h),
                                Row(
                                  children: List.generate(5, (sIdx) {
                                    final filled = ratingVal >= sIdx + 1;
                                    final half = !filled && ratingVal >= sIdx + 0.5;
                                    return Icon(
                                      filled
                                          ? Icons.star_rounded
                                          : half
                                              ? Icons.star_half_rounded
                                              : Icons.star_outline_rounded,
                                      color: Colors.amber,
                                      size: 16.sp,
                                    );
                                  }),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
