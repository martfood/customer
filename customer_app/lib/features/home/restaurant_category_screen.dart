import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_widgets/widgets/skeleton_loader.dart';
import 'package:shared_widgets/widgets/verification_badge.dart';
import '../../core/services/price_helper.dart';

class RestaurantCategoryScreen extends StatefulWidget {
  const RestaurantCategoryScreen({super.key});

  @override
  State<RestaurantCategoryScreen> createState() =>
      _RestaurantCategoryScreenState();
}

class _RestaurantCategoryScreenState extends State<RestaurantCategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  Position? _currentPosition;
  String _currentAddress = 'Set delivery address';
  String _fullAddress = '';

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
    if (openStr == null || openStr.isEmpty || closeStr == null || closeStr.isEmpty) return true;

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
  void initState() {
    super.initState();
    _currentPosition = PriceHelper.currentPosition;
    if (PriceHelper.currentAddress != null) {
      _currentAddress = PriceHelper.currentAddress!;
    }
    if (PriceHelper.fullAddress != null) {
      _fullAddress = PriceHelper.fullAddress!;
    }

    PriceHelper.locationNotifier.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    if (mounted) {
      setState(() {
        _currentPosition = PriceHelper.currentPosition;
        if (PriceHelper.currentAddress != null) {
          _currentAddress = PriceHelper.currentAddress!;
        }
        if (PriceHelper.fullAddress != null) {
          _fullAddress = PriceHelper.fullAddress!;
        }
      });
    }
  }

  @override
  void dispose() {
    PriceHelper.locationNotifier.removeListener(_onLocationChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _geocodeAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newPos = Position(
          latitude: loc.latitude,
          longitude: loc.longitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
        if (mounted) {
          setState(() {
            _currentPosition = newPos;
          });
        }
        PriceHelper.currentPosition = newPos;
      }
    } catch (e) {
      debugPrint('RestaurantCategoryScreen: Error geocoding address: $e');
    }
  }

  Widget _buildCartAction(bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final pillBg =
        isDark ? purpleColor.withValues(alpha: 0.2) : const Color(0xFFF3E8FF);

    return StreamBuilder<QuerySnapshot>(
      stream: user != null
          ? FirebaseFirestore.instance
              .collection('customers')
              .doc(user.uid)
              .collection('cart')
              .snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        final cartCount = snapshot.data?.docs.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: () => context.push('/cart'),
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pillBg,
                ),
                child: Icon(Icons.shopping_bag_rounded,
                    size: 20.sp, color: purpleColor),
              ),
            ),
            if (cartCount > 0)
              Positioned(
                right: -2.w,
                top: -2.h,
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16.w,
                    minHeight: 16.w,
                  ),
                  child: Center(
                    child: Text(
                      '$cartCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTypography.font(AppFontSizes.caption - 2),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkSurface : Colors.white;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── 1. Delivery Location Top Bar ──────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 8.h),
              child: InkWell(
                onTap: () async {
                  final result =
                      await context.push('/profile/address/location');
                  if (result != null && result is Map<String, dynamic>) {
                    final newAddr = result['address'] ?? '';
                    final double? lat = result['latitude'] != null
                        ? (result['latitude'] as num).toDouble()
                        : null;
                    final double? lng = result['longitude'] != null
                        ? (result['longitude'] as num).toDouble()
                        : null;

                    setState(() {
                      _currentAddress = result['title'] ?? _currentAddress;
                      _fullAddress = newAddr;
                    });
                    PriceHelper.currentAddress = _currentAddress;
                    PriceHelper.fullAddress = _fullAddress;

                    if (lat != null && lng != null) {
                      final newPos = Position(
                        latitude: lat,
                        longitude: lng,
                        timestamp: DateTime.now(),
                        accuracy: 0.0,
                        altitude: 0.0,
                        altitudeAccuracy: 0.0,
                        heading: 0.0,
                        headingAccuracy: 0.0,
                        speed: 0.0,
                        speedAccuracy: 0.0,
                      );
                      if (mounted) {
                        setState(() {
                          _currentPosition = newPos;
                        });
                      }
                      PriceHelper.currentPosition = newPos;
                    } else {
                      _geocodeAddress(
                          newAddr.isNotEmpty ? newAddr : _currentAddress);
                    }
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, color: purpleColor, size: 16.sp),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(
                        _currentAddress,
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down,
                        color: Colors.grey[600], size: 18.sp),
                  ],
                ),
              ),
            ),

            // ─── 2. Header Row: "Restaurants" (Left) & Cart (Right) ───────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withAlpha(15)
                                : const Color(0xFFF3F4F6),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18.sp,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        'Restaurants',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize:
                              AppTypography.font(AppFontSizes.displaySmall),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  _buildCartAction(isDark),
                ],
              ),
            ),

            // ─── 3. Search Bar ─────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppTheme.darkSurface : AppTheme.lightInputFill,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: borderColor),
                  boxShadow: null,
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.search,
                        color: mutedTextColor, size: 20.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() => _searchText = val.trim());
                        },
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search restaurants...',
                          hintStyle: TextStyle(
                            color: mutedTextColor,
                            fontSize:
                                AppTypography.font(AppFontSizes.bodyMedium),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchText.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchText = '');
                        },
                        child: Icon(Icons.close_rounded,
                            color: mutedTextColor, size: 20.sp),
                      ),
                  ],
                ),
              ),
            ),

            // ─── 4. Restaurant Card List ────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('vendors')
                    .where('businessProfile.status', isEqualTo: 'verified')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
                      itemCount: 3,
                      itemBuilder: (context, index) => Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: SkeletonLoader.restaurantCard(context: context),
                      ),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  // Filter in-memory: category = Restaurant AND within range AND search filter
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final profile =
                        data['businessProfile'] as Map<String, dynamic>?;

                    if (profile?['category'] != 'Restaurant') return false;

                    // Search filter
                    if (_searchText.isNotEmpty) {
                      final name = (profile?['businessName'] ?? '').toString().toLowerCase();
                      final tagline = (profile?['tagline'] ?? '').toString().toLowerCase();
                      final searchLower = _searchText.toLowerCase();
                      if (!name.contains(searchLower) && !tagline.contains(searchLower)) {
                        return false;
                      }
                    }

                    if (_currentPosition == null) return true;

                    final vendorLocation =
                        (profile?['currentvendorLocation'] as GeoPoint?) ??
                            (data['currentvendorLocation'] as GeoPoint?);
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

                  // Sort by proximity (closest first)
                  filteredDocs.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final profileA =
                        dataA['businessProfile'] as Map<String, dynamic>?;
                    final locA = (profileA?['currentvendorLocation']
                            as GeoPoint?) ??
                        (dataA['currentvendorLocation'] as GeoPoint?);
                    final dataB = b.data() as Map<String, dynamic>;
                    final profileB =
                        dataB['businessProfile'] as Map<String, dynamic>?;
                    final locB = (profileB?['currentvendorLocation']
                            as GeoPoint?) ??
                        (dataB['currentvendorLocation'] as GeoPoint?);
                    if (_currentPosition == null) return 0;
                    final distA = locA != null
                        ? Geolocator.distanceBetween(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            locA.latitude,
                            locA.longitude)
                        : 999999.0;
                    final distB = locB != null
                        ? Geolocator.distanceBetween(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            locB.latitude,
                            locB.longitude)
                        : 999999.0;
                    return distA.compareTo(distB);
                  });

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.w, vertical: 40.h),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/emoji/sad.png',
                              width: 140.w,
                              height: 140.w,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(height: 24.h),
                            Text(
                              _searchText.isNotEmpty
                                  ? 'No matching restaurants'
                                  : 'No Restaurants Available',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: AppTypography.font(
                                    AppFontSizes.bodyLarge + 2),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              _searchText.isNotEmpty
                                  ? 'No verified restaurants matched your search query. Try searching for a different keyword.'
                                  : 'There are no verified restaurants available in your location right now. We are expanding quickly, check back soon!',
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: AppTypography.font(
                                    AppFontSizes.bodySmall),
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final vendorDoc = filteredDocs[index];
                      final data = vendorDoc.data() as Map<String, dynamic>;
                      final vendorId = vendorDoc.id;
                      final profile =
                          data['businessProfile'] as Map<String, dynamic>?;
                      final name = profile?['businessName'] ?? 'Restaurant';
                      final tagline = profile?['tagline'] ?? '';
                      final logoUrl = profile?['logoUrl'] ?? '';
                      final coverImageUrl = profile?['coverImageUrl'] ?? '';
                      final deliveryFeeVal = data['deliveryFee'] ?? 0;
                      final prepTime = data['prepTimeMinutes'] ?? 15;
                      final vendorLocation =
                          (profile?['currentvendorLocation'] as GeoPoint?) ??
                              (data['currentvendorLocation'] as GeoPoint?);

                      return _buildRestaurantCard(
                        context,
                        vendorId: vendorId,
                        name: name,
                        tagline: tagline,
                        logoUrl: logoUrl,
                        coverImageUrl: coverImageUrl,
                        deliveryFee: deliveryFeeVal,
                        prepTime: prepTime,
                        vendorLocation: vendorLocation,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(
    BuildContext context, {
    required String vendorId,
    required String name,
    required String tagline,
    required String logoUrl,
    required String coverImageUrl,
    required dynamic deliveryFee,
    required int prepTime,
    required GeoPoint? vendorLocation,
    required bool isDark,
    required Color surfaceColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required Color purpleColor,
    required Color borderColor,
    required Map<String, dynamic> vendorData,
  }) {
    final isOpen = _isVendorOpen(vendorData['operatingHours'] as Map<String, dynamic>?);
    final user = FirebaseAuth.instance.currentUser;

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
                              color: isDark ? Colors.grey[900] : Colors.grey[200],
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
                        // Left Column: Business Name + Rating below
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
                                        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
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
                                                  (r.data() as Map<String, dynamic>)['rating'] as num? ??
                                                  5.0)
                                              .reduce((a, b) => a + b) /
                                          reviews.length;
                                  return Row(
                                    children: [
                                      Icon(Icons.star_rounded, color: Colors.amber, size: 16.sp),
                                      SizedBox(width: 4.w),
                                      Text(
                                        reviews.isEmpty ? '0.0' : rating.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        '(${reviews.length})',
                                        style: TextStyle(
                                          fontSize: AppTypography.font(AppFontSizes.caption),
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
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
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
                                StreamBuilder<DocumentSnapshot>(
                                  stream: user != null
                                      ? FirebaseFirestore.instance
                                          .collection('customers')
                                          .doc(user.uid)
                                          .snapshots()
                                      : null,
                                  builder: (context, favSnap) {
                                    final favData = favSnap.data?.data() as Map<String, dynamic>?;
                                    final favList = List<String>.from(favData?['favoriteRestaurants'] ?? []);
                                    final isFav = favList.contains(vendorId);

                                    return GestureDetector(
                                      onTap: () async {
                                        if (user == null) return;
                                        final docRef = FirebaseFirestore.instance
                                            .collection('customers')
                                            .doc(user.uid);
                                        if (isFav) {
                                          await docRef.update({
                                            'favoriteRestaurants': FieldValue.arrayRemove([vendorId])
                                          });
                                        } else {
                                          await docRef.set({
                                            'favoriteRestaurants': FieldValue.arrayUnion([vendorId])
                                          }, SetOptions(merge: true));
                                        }
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(6.w),
                                        decoration: BoxDecoration(
                                          color: isFav
                                              ? Colors.red.withValues(alpha: 0.12)
                                              : (isDark ? Colors.grey[800] : Colors.grey[200]),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          LucideIcons.heart,
                                          color: isFav ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                          size: 16.sp,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              '$prepTime–${prepTime + 10} mins',
                              style: TextStyle(
                                fontSize: AppTypography.font(AppFontSizes.caption),
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
}
