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

import 'package:shared_widgets/widgets/bottom_nav_bar.dart';
import 'package:shared_widgets/widgets/food_card_horizontal.dart';
import 'package:shared_widgets/widgets/skeleton_loader.dart';
import '../../core/services/price_helper.dart';

class DiscountGuaranteedScreen extends StatefulWidget {
  const DiscountGuaranteedScreen({super.key});

  @override
  State<DiscountGuaranteedScreen> createState() =>
      _DiscountGuaranteedScreenState();
}

class _DiscountGuaranteedScreenState extends State<DiscountGuaranteedScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _selectedTab = 'Restaurants';

  Position? _currentPosition;
  String _currentAddress = 'Set delivery address';
  String _fullAddress = '';

  Map<String, Map<String, dynamic>> _vendorsMap = {};
  StreamSubscription? _vendorsSubscription;
  Stream<List<Map<String, dynamic>>>? _combinedStream;

  final List<Map<String, dynamic>> _categories = const [
    {
      'title': 'Restaurants',
      'imageUrl': 'assets/category/restaurant.png',
    },
    {
      'title': 'Grocery',
      'imageUrl': 'assets/category/grocery.png',
    },
    {
      'title': 'Pharmacy',
      'imageUrl': 'assets/category/pharmacy.png',
    },
    {
      'title': 'Bakery',
      'imageUrl': 'assets/category/bakery.png',
    },
  ];

  static const Map<String, String> _collectionMap = {
    'Restaurants': 'resturantPosts',
    'Grocery': 'grocerytPosts',
    'Pharmacy': 'pharmacytPosts',
    'Bakery': 'bakerytPosts',
  };

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
    _listenToVendors();
    _buildCombinedStream();
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
    _vendorsSubscription?.cancel();
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
      debugPrint('DiscountScreen: Error geocoding address: $e');
    }
  }

  void _listenToVendors() {
    _vendorsSubscription = FirebaseFirestore.instance
        .collection('vendors')
        .snapshots()
        .listen((snapshot) {
      final map = <String, Map<String, dynamic>>{};
      for (var doc in snapshot.docs) {
        map[doc.id] = doc.data();
      }
      if (mounted) {
        setState(() {
          _vendorsMap = map;
        });
      }
    });
  }

  void _buildCombinedStream() {
    final collName = _collectionMap[_selectedTab] ?? 'resturantPosts';
    final collectionsToListen = [collName];

    final StreamController<List<Map<String, dynamic>>> controller =
        StreamController<List<Map<String, dynamic>>>();

    final Map<String, List<Map<String, dynamic>>> lastData = {};
    final List<StreamSubscription> subscriptions = [];

    void emitCombined() {
      if (controller.isClosed) return;
      final List<Map<String, dynamic>> allItems = [];
      for (var list in lastData.values) {
        allItems.addAll(list);
      }
      controller.add(allItems);
    }

    for (var collName in collectionsToListen) {
      final sub = FirebaseFirestore.instance
          .collection(collName)
          .snapshots()
          .listen((snap) {
        final items = snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          data['sourceCollection'] = collName;
          return data;
        }).where((item) {
          final isVisible = item['visibleOnMenu'] != false && item['isVisible'] != false && item['visible'] != false;
          if (!isVisible) return false;

          final bool isPromo = item['isPromotion'] == true ||
              (item['promoPrice'] != null && (item['promoPrice'] as num) > 0);
          return isPromo;
        }).toList();
        lastData[collName] = items;
        emitCombined();
      }, onError: (err) {
        debugPrint('Error listening to discounts in $collName: $err');
      });
      subscriptions.add(sub);
    }

    controller.onCancel = () {
      for (var sub in subscriptions) {
        sub.cancel();
      }
    };

    setState(() {
      _combinedStream = controller.stream;
    });
  }

  void _onTabSelected(String tab) {
    if (_selectedTab == tab) return;
    _selectedTab = tab;
    _buildCombinedStream();
  }

  double _getDistanceToVendor(String vendorId) {
    final pos = _currentPosition ?? PriceHelper.currentPosition;
    if (pos == null) return 0.0;
    final vendor = _vendorsMap[vendorId];
    if (vendor == null) return 0.0;
    final profile = vendor['businessProfile'] as Map<String, dynamic>?;
    final geoPoint = (profile?['currentvendorLocation'] as GeoPoint?) ??
        (vendor['currentvendorLocation'] as GeoPoint?);
    if (geoPoint == null) return 0.0;
    return Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          geoPoint.latitude,
          geoPoint.longitude,
        ) /
        1000.0;
  }

  Widget _buildCategoryItem({
    required BuildContext context,
    required String title,
    required String imageUrl,
    IconData? iconData,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final isTablet = MediaQuery.of(context).size.width >= 600;
    final circleSize = isTablet ? 54.w : 46.w;
    final iconSize = isTablet ? 40.w : 34.w;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: isSelected
                    ? purpleColor.withValues(alpha: 0.12)
                    : surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? purpleColor : borderColor,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: imageUrl.isNotEmpty
                  ? Image.asset(
                      imageUrl,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        LucideIcons.store,
                        size: iconSize * 0.8,
                        color: isSelected ? purpleColor : mutedTextColor,
                      ),
                    )
                  : Icon(
                      iconData ?? LucideIcons.layoutGrid,
                      size: iconSize * 0.8,
                      color: isSelected ? purpleColor : mutedTextColor,
                    ),
            ),
            SizedBox(height: 4.h),
            Text(
              title,
              style: TextStyle(
                fontSize: isTablet ? 12.sp : 11.sp,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? purpleColor : primaryTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

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

            // ─── 2. Header Row: "Discounts" (Left) & Cart (Right) ───────────
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
                        'Discounts',
                        style: TextStyle(
                          color: isDark ? Colors.white : purpleColor,
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
                          hintText: 'Search discounts...',
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

            // ─── 4. Category Tabs ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: SizedBox(
                height: MediaQuery.of(context).size.width >= 600 ? 96.h : 86.h,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _categories.map((cat) {
                    final title = cat['title'] as String;
                    final imageUrl = (cat['imageUrl'] ?? '').toString();
                    final iconData = cat['icon'] as IconData?;
                    final isSelected = _selectedTab == title;

                    return Expanded(
                      child: _buildCategoryItem(
                        context: context,
                        title: title,
                        imageUrl: imageUrl,
                        iconData: iconData,
                        isSelected: isSelected,
                        onTap: () => _onTabSelected(title),
                        isDark: isDark,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            SizedBox(height: 8.h),

            // ─── 5. Results Grid ───────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _combinedStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return GridView.builder(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width >= 900
                            ? 4
                            : (MediaQuery.of(context).size.width >= 600
                                ? 3
                                : 2),
                        crossAxisSpacing: 14.w,
                        mainAxisSpacing: 16.h,
                        childAspectRatio: 0.90,
                      ),
                      itemCount: 6,
                      itemBuilder: (context, index) =>
                          SkeletonLoader.horizontalFoodCard(context: context),
                    );
                  }

                  final allItems = snapshot.data ?? [];

                  final filteredItems = allItems.where((item) {
                    final vendorId = item['vendorId'] ?? '';
                    final dist = _getDistanceToVendor(vendorId);

                    // 1. Distance filter
                    if (dist > PriceHelper.maxDeliveryDistance) return false;

                    // 2. Search Text filter
                    if (_searchText.isNotEmpty) {
                      final name =
                          (item['name'] ?? '').toString().toLowerCase();
                      if (!name.contains(_searchText.toLowerCase())) {
                        return false;
                      }
                    }

                    return true;
                  }).toList();

                  // Sort by nearest
                  filteredItems.sort((a, b) {
                    final distA =
                        _getDistanceToVendor((a['vendorId'] ?? '').toString());
                    final distB =
                        _getDistanceToVendor((b['vendorId'] ?? '').toString());
                    return distA.compareTo(distB);
                  });

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.w, vertical: 40.h),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/emoji/sad.png',
                              width: 120.w,
                              height: 120.w,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(height: 20.h),
                            Text(
                              'No Discounts Available',
                              style: TextStyle(
                                fontSize: AppTypography.font(
                                    AppFontSizes.headlineMedium),
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'There are no discounted items in your delivery area right now.',
                              style: TextStyle(
                                fontSize:
                                    AppTypography.font(AppFontSizes.bodyMedium),
                                color: mutedTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width >= 900
                          ? 4
                          : (MediaQuery.of(context).size.width >= 600 ? 3 : 2),
                      crossAxisSpacing: 14.w,
                      mainAxisSpacing: 12.h,
                      childAspectRatio:
                          MediaQuery.of(context).size.width >= 600
                              ? 0.72
                              : 0.84,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final vendorId = item['vendorId'] ?? '';
                      return _SearchResultItem(
                        item: item,
                        vendorId: vendorId,
                        vendorInfo: _vendorsMap[vendorId],
                        currentPosition: _currentPosition,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MartFoodBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) context.go('/home');
          if (index == 1) context.push('/search');
          if (index == 2) context.push('/orders');
          if (index == 3) context.push('/profile/customer-service');
          if (index == 4) context.push('/profile');
        },
      ),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final String vendorId;
  final Map<String, dynamic>? vendorInfo;
  final Position? currentPosition;

  const _SearchResultItem({
    required this.item,
    required this.vendorId,
    required this.vendorInfo,
    required this.currentPosition,
  });

  @override
  Widget build(BuildContext context) {
    final title = (item['name'] ?? 'Product').toString();

    String extractPhotoUrl(Map<String, dynamic> data) {
      final pUrl = (data['photoUrl'] ?? '').toString().trim();
      if (pUrl.isNotEmpty) return pUrl;

      final rawImageUrls = data['imageUrls'];
      if (rawImageUrls is List && rawImageUrls.isNotEmpty) {
        final first = rawImageUrls.first?.toString().trim() ?? '';
        if (first.isNotEmpty) return first;
      } else if (rawImageUrls is String && rawImageUrls.trim().isNotEmpty) {
        return rawImageUrls.trim();
      }

      final imgUrl = (data['imageUrl'] ?? '').toString().trim();
      if (imgUrl.isNotEmpty) return imgUrl;

      final img = (data['image'] ?? '').toString().trim();
      if (img.isNotEmpty) return img;

      return '';
    }

    final photoUrl = extractPhotoUrl(item);

    final profile = vendorInfo?['businessProfile'] as Map<String, dynamic>?;
    final vendorName = (profile?['restaurantName'] ??
            profile?['businessName'] ??
            vendorInfo?['restaurantName'] ??
            vendorInfo?['businessName'] ??
            '')
        .toString();
    final isVerified = profile?['status'] == 'verified';

    final geoPoint = (profile?['currentvendorLocation'] as GeoPoint?) ??
        (vendorInfo?['currentvendorLocation'] as GeoPoint?);

    double distanceKm = 999999.0;
    if (currentPosition != null && geoPoint != null) {
      distanceKm = Geolocator.distanceBetween(
            currentPosition!.latitude,
            currentPosition!.longitude,
            geoPoint.latitude,
            geoPoint.longitude,
          ) /
          1000.0;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .collection('reviews')
          .snapshots(),
      builder: (context, reviewSnapshot) {
        final allReviews = reviewSnapshot.data?.docs ?? [];

        final postReviews = allReviews.where((r) {
          final data = r.data() as Map<String, dynamic>;
          final summary = (data['orderSummary'] ?? '').toString().toLowerCase();
          return summary.contains(title.toLowerCase());
        }).toList();

        final double rating = postReviews.isEmpty
            ? 0.0
            : postReviews
                    .map((r) =>
                        (r.data() as Map<String, dynamic>)['rating'] as num? ??
                        0.0)
                    .reduce((a, b) => a + b) /
                postReviews.length;

        return FoodCardHorizontal(
          width: double.infinity,
          title: title,
          imageUrl: photoUrl,
          rating: double.parse(rating.toStringAsFixed(1)),
          reviewsCount: postReviews.length,
          distanceKm: distanceKm,
          basePrice: item['basePrice'] != null
              ? PriceHelper.applyMarkup((item['basePrice'] as num).toDouble(),
                  item['sourceCollection'])
              : null,
          promoPrice: item['promoPrice'] != null
              ? PriceHelper.applyMarkup((item['promoPrice'] as num).toDouble(),
                  item['sourceCollection'])
              : null,
          isPromo: item['isPromotion'] == true ||
              (item['promoPrice'] != null && (item['promoPrice'] as num) > 0),
          isClosed: !_isVendorOpen(vendorInfo?['operatingHours']),
          isOutOfStock: item['inStock'] == false ||
              item['isAvailable'] == false ||
              (item['quantity'] != null && (item['quantity'] as num) <= 0) ||
              (item['stockQuantity'] != null && (item['stockQuantity'] as num) <= 0),
          vendorName: vendorName.isNotEmpty ? vendorName : null,
          isVerified: isVerified,
          vendorData: vendorInfo,
          onTap: () => context.push(
            '/food-details/$title',
            extra: {
              'vendorId': vendorId,
              'docId': item['id'],
              'sourceCollection': item['sourceCollection'],
            },
          ),
          onFavoriteTap: () {},
        );
      },
    );
  }
}

bool _isVendorOpen(Map<String, dynamic>? operatingHours) {
  if (operatingHours == null) return true;
  final now = DateTime.now();
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final currentDayStr = days[now.weekday - 1];
  final dayConfig = operatingHours[currentDayStr];
  if (dayConfig == null) return true;
  final bool closed = dayConfig['closed'] ?? false;
  if (closed) return false;
  final String? openTime = dayConfig['open'];
  final String? closeTime = dayConfig['close'];
  if (openTime == null || closeTime == null) return true;
  try {
    final nowTimeMin = now.hour * 60 + now.minute;
    final openParts = openTime.split(':');
    final openMin = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
    final closeParts = closeTime.split(':');
    final closeMin = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
    if (closeMin < openMin) {
      return nowTimeMin >= openMin || nowTimeMin < closeMin;
    } else {
      return nowTimeMin >= openMin && nowTimeMin < closeMin;
    }
  } catch (e) {
    return true;
  }
}
