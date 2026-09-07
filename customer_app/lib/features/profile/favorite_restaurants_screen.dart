import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_widgets/widgets/skeleton_loader.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/verification_badge.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/price_helper.dart';

class FavoriteRestaurantsScreen extends StatefulWidget {
  const FavoriteRestaurantsScreen({super.key});

  @override
  State<FavoriteRestaurantsScreen> createState() =>
      _FavoriteRestaurantsScreenState();
}

class _FavoriteRestaurantsScreenState
    extends State<FavoriteRestaurantsScreen> {
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _currentPosition = PriceHelper.currentPosition;
    PriceHelper.locationNotifier.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    if (mounted) {
      setState(() {
        _currentPosition = PriceHelper.currentPosition;
      });
    }
  }

  @override
  void dispose() {
    PriceHelper.locationNotifier.removeListener(_onLocationChanged);
    super.dispose();
  }

  bool _isVendorOpen(Map<String, dynamic>? operatingHours) {
    if (operatingHours == null) return true;
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
    if (dayKey == null) return true;

    final dayConfig = operatingHours[dayKey] as Map<String, dynamic>?;
    if (dayConfig == null) return true;

    final bool isClosedToday = dayConfig['closed'] == true;
    if (isClosedToday) return false;

    final String? openStr = dayConfig['open'] as String?;
    final String? closeStr = dayConfig['close'] as String?;
    if (openStr == null || openStr.isEmpty || closeStr == null || closeStr.isEmpty) {
      return true;
    }

    try {
      final openParts = openStr.split(':');
      final closeParts = closeStr.split(':');

      if (openParts.length < 2 || closeParts.length < 2) return true;

      final openHour = int.parse(openParts[0]);
      final openMin = int.parse(openParts[1]);
      final closeHour = int.parse(closeParts[0]);
      final closeMin = int.parse(closeParts[1]);

      final openMinutes = openHour * 60 + openMin;
      final closeMinutes = closeHour * 60 + closeMin;
      final nowMinutes = now.hour * 60 + now.minute;

      if (closeMinutes >= openMinutes) {
        return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
      } else {
        return nowMinutes >= openMinutes || nowMinutes <= closeMinutes;
      }
    } catch (e) {
      debugPrint("Error parsing operating hours: $e");
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Please log in to view favorites.',
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
              border: Border.all(color: borderColor, width: 1),
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
          'Favorite Restaurants',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .snapshots(),
        builder: (context, customerSnapshot) {
          if (customerSnapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingList();
          }

          if (!customerSnapshot.hasData || !customerSnapshot.data!.exists) {
            return _buildEmptyState(isDark);
          }

          final customerData =
              customerSnapshot.data!.data() as Map<String, dynamic>?;
          final favoriteIds =
              List<String>.from(customerData?['favoriteRestaurants'] ?? []);

          if (favoriteIds.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('vendors')
                .where(FieldPath.documentId, whereIn: favoriteIds)
                .snapshots(),
            builder: (context, vendorsSnapshot) {
              if (vendorsSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingList();
              }

              final docs = vendorsSnapshot.data?.docs ?? [];
              final filteredDocs = docs.where((doc) {
                final vendorData = doc.data() as Map<String, dynamic>;
                final profile =
                    vendorData['businessProfile'] as Map<String, dynamic>?;
                final vendorLocation =
                    (profile?['currentvendorLocation'] as GeoPoint?) ??
                        (vendorData['currentvendorLocation'] as GeoPoint?);

                if (_currentPosition == null) return true;
                if (vendorLocation == null) return true;

                final distanceKm = Geolocator.distanceBetween(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      vendorLocation.latitude,
                      vendorLocation.longitude,
                    ) /
                    1000.0;
                return distanceKm <= PriceHelper.maxDeliveryDistance;
              }).toList();

              if (filteredDocs.isEmpty) {
                return _buildEmptyState(isDark, noNearby: true);
              }

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final vendorDoc = filteredDocs[index];
                  final data = vendorDoc.data() as Map<String, dynamic>;
                  final vendorId = vendorDoc.id;
                  final profile =
                      data['businessProfile'] as Map<String, dynamic>?;
                  final name = profile?['businessName'] ?? 'Restaurant';
                  final logoUrl = profile?['logoUrl'] ?? '';
                  final coverImageUrl = profile?['coverImageUrl'] ?? '';
                  final prepTime = data['prepTimeMinutes'] ?? 15;

                  return _buildRestaurantCard(
                    context,
                    userId: user.uid,
                    vendorId: vendorId,
                    name: name,
                    logoUrl: logoUrl,
                    coverImageUrl: coverImageUrl,
                    prepTime: prepTime,
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    primaryTextColor: primaryTextColor,
                    mutedTextColor: mutedTextColor,
                    purpleColor: purpleColor,
                    borderColor: borderColor,
                    vendorData: data,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRestaurantCard(
    BuildContext context, {
    required String userId,
    required String vendorId,
    required String name,
    required String logoUrl,
    required String coverImageUrl,
    required int prepTime,
    required bool isDark,
    required Color surfaceColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required Color purpleColor,
    required Color borderColor,
    required Map<String, dynamic> vendorData,
  }) {
    final isOpen =
        _isVendorOpen(vendorData['operatingHours'] as Map<String, dynamic>?);

    return GestureDetector(
      onTap: () => context.push('/vendor/$vendorId'),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverImageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: coverImageUrl,
                height: 120.h,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 120.h,
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 120.h,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
              ),

            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60.w,
                    height: 60.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18.r),
                      color: surfaceColor,
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: logoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: logoUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color:
                                  isDark ? Colors.grey[900] : Colors.grey[200],
                            ),
                            errorWidget: (_, __, ___) => Image.asset(
                              'assets/logo/martfood_logo.png',
                              fit: BoxFit.contain,
                            ),
                          )
                        : Image.asset('assets/logo/martfood_logo.png',
                            fit: BoxFit.contain),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: AppTypography.font(
                                            AppFontSizes.bodyLarge),
                                        fontWeight: FontWeight.w800,
                                        color: primaryTextColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  VerificationBadge(
                                    vendorData: vendorData,
                                    size: 16.sp,
                                  ),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              // Rating & Reviews right below businessName
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('vendors')
                                    .doc(vendorId)
                                    .collection('reviews')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final reviews = snapshot.data?.docs ?? [];
                                  final double rating = reviews.isEmpty
                                      ? 0.0
                                      : reviews
                                              .map((r) =>
                                                  (r.data() as Map<String,
                                                          dynamic>)['rating']
                                                      as num? ??
                                                  5.0)
                                              .reduce((a, b) => a + b) /
                                          reviews.length;
                                  return Row(
                                    children: [
                                      Icon(Icons.star_rounded,
                                          color: Colors.amber, size: 16.sp),
                                      SizedBox(width: 4.w),
                                      Text(
                                        reviews.isEmpty
                                            ? '0.0'
                                            : rating.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: AppTypography.font(
                                              AppFontSizes.bodySmall),
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        '(${reviews.length})',
                                        style: TextStyle(
                                          fontSize: AppTypography.font(
                                              AppFontSizes.caption),
                                          color: mutedTextColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Right Column: Heart Icon on top, Preparation time BELOW Heart Icon
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isOpen) ...[
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Text(
                                      'Closed',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: AppTypography.font(9),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                ],
                                GestureDetector(
                                  onTap: () async {
                                    await FirebaseFirestore.instance
                                        .collection('customers')
                                        .doc(userId)
                                        .update({
                                      'favoriteRestaurants':
                                          FieldValue.arrayRemove([vendorId])
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(6.w),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      LucideIcons.heart,
                                      color: Colors.red,
                                      size: 16.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              '$prepTime–${prepTime + 10} mins',
                              style: TextStyle(
                                fontSize: AppTypography.font(
                                    AppFontSizes.caption),
                                color: mutedTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildEmptyState(bool isDark, {bool noNearby = false}) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (noNearby)
              Image.asset(
                'assets/emoji/sad.png',
                width: 120.w,
                height: 120.w,
                fit: BoxFit.contain,
              )
            else
              Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  color: purpleColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22.r),
                ),
                child: Icon(
                  LucideIcons.heart,
                  size: 32.sp,
                  color: purpleColor,
                ),
              ),
            SizedBox(height: 20.h),
            Text(
              noNearby
                  ? 'No Restaurants Available Nearby'
                  : 'No favorite restaurants yet',
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            Text(
              noNearby
                  ? 'The restaurants you saved might not be available to place orders from your current location.'
                  : 'Explore restaurants and save the ones you love for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                color: mutedTextColor,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      itemCount: 4,
      separatorBuilder: (context, index) => SizedBox(height: 16.h),
      itemBuilder: (context, index) =>
          SkeletonLoader.restaurantCard(context: context),
    );
  }
}
