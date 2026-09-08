import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/category_item.dart';
import 'package:shared_widgets/widgets/food_card_horizontal.dart';
import 'package:shared_widgets/widgets/food_card_vertical.dart';
import 'package:shared_widgets/widgets/bulk_meal_card.dart';
import 'package:shared_widgets/core/utils/meal_time_helper.dart';
import 'package:shared_widgets/widgets/bottom_nav_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_widgets/widgets/skeleton_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../../core/services/price_helper.dart';
import '../../core/services/app_update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  String _currentAddress = 'Set delivery address';
  String _fullAddress = '';
  bool _isServiceAvailable = true;
  List<String> _enabledStatesList = [];
  List<String> _enabledLgasList = [];
  List<String> _enabledTownsList = [];
  StreamSubscription<DocumentSnapshot>? _serviceAvailabilitySubscription;

  // Banner state
  final PageController _bannerController = PageController();
  int _currentBannerPage = 0;
  Timer? _bannerTimer;
  int _bannerLength = 3;
  late final Stream<QuerySnapshot> _promosStream;
  late final Stream<DocumentSnapshot>? _userStream;
  late final Stream<QuerySnapshot> _vendorsStream;
  late final Stream<QuerySnapshot> _discountStream;
  late final Stream<QuerySnapshot> _bulkMealsStream;

  static Map<String, Map<String, dynamic>> _cachedVendorsMap = {};
  static bool _hasLoadedVendorsOnce = false;

  Position? _currentPosition;
  Map<String, Map<String, dynamic>> _vendorsMap = _cachedVendorsMap;
  bool _vendorsLoaded = _hasLoadedVendorsOnce;
  StreamSubscription<QuerySnapshot>? _vendorsSubscription;
  StreamSubscription<QuerySnapshot>? _addressesSubscription;

  static const _bannerAssets = [
    'assets/promotional_banner/banner_1.png',
    'assets/promotional_banner/banner_2.png',
    'assets/promotional_banner/banner_3.png',
  ];

  final List<Map<String, String>> _categories = [
    {'title': 'Restaurant', 'imageUrl': 'assets/category/restaurant.png'},
    {'title': 'Grocery', 'imageUrl': 'assets/category/grocery.png'},
    {'title': 'Bakery', 'imageUrl': 'assets/category/bakery.png'},
    {'title': 'Pharmacy', 'imageUrl': 'assets/category/pharmacy.png'},
  ];

  Map<String, bool> _categoriesStatus = {
    'Restaurant': true,
    'Grocery': true,
    'Bakery': true,
    'Pharmacy': true,
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

    _promosStream = FirebaseFirestore.instance
        .collection('promos')
        .where('isActive', isEqualTo: true)
        .snapshots();
    final user = FirebaseAuth.instance.currentUser;
    _userStream = user != null
        ? FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .snapshots()
        : null;
    _vendorsStream = FirebaseFirestore.instance
        .collection('vendors')
        .where('businessProfile.status', isEqualTo: 'verified')
        .snapshots();

    _vendorsSubscription = _vendorsStream.listen((snapshot) {
      final map = <String, Map<String, dynamic>>{};
      for (var doc in snapshot.docs) {
        map[doc.id] = doc.data() as Map<String, dynamic>;
      }
      _cachedVendorsMap = map;
      _hasLoadedVendorsOnce = true;
      if (mounted) {
        setState(() {
          _vendorsMap = map;
          _vendorsLoaded = true;
        });
      }
    });

    _discountStream = FirebaseFirestore.instance
        .collection('resturantPosts')
        .where('isPromotion', isEqualTo: true)
        .snapshots();

    _bulkMealsStream = FirebaseFirestore.instance
        .collection('resturantPosts')
        .snapshots();

    _initLocationAndPermissions();
    _listenToCategoryStatus();
    _startBannerTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.checkAndPromptUpdate(context);
      }
    });

    if (user != null) {
      _addressesSubscription = FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .collection('addresses')
          .snapshots()
          .listen((snap) {
        if (snap.docs.isNotEmpty && mounted) {
          // If the customer has already manually selected a location during this session,
          // do not automatically overwrite it with their default address.
          if (PriceHelper.currentPosition != null) return;

          final defaultIdx = snap.docs.indexWhere(
            (doc) => doc.data()['isDefault'] == true,
          );
          final defaultDoc =
              defaultIdx >= 0 ? snap.docs[defaultIdx] : snap.docs.first;
          final data = defaultDoc.data();
          final newAddr = (data['address'] ?? '').toString();
          final double? lat = data['latitude'] != null
              ? (data['latitude'] as num).toDouble()
              : null;
          final double? lng = data['longitude'] != null
              ? (data['longitude'] as num).toDouble()
              : null;

          setState(() {
            _currentAddress = (data['title'] ?? '').toString();
            _fullAddress = newAddr;
          });
          PriceHelper.currentAddress = _currentAddress;
          PriceHelper.fullAddress = _fullAddress;
          _validateServiceAvailability();

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
            _geocodeAddress(newAddr.isNotEmpty ? newAddr : _currentAddress);
          }
        }
      });
    }

    _serviceAvailabilitySubscription = FirebaseFirestore.instance
        .collection('settings')
        .doc('service_availability')
        .snapshots()
        .listen((snap) {
      if (snap.exists) {
        final data = snap.data();
        if (data != null && mounted) {
          setState(() {
            _enabledStatesList = List<String>.from(data['enabledStates'] ?? []);
            _enabledLgasList = List<String>.from(data['enabledLgas'] ?? []);
            _enabledTownsList = List<String>.from(data['enabledTowns'] ?? []);
          });
          _validateServiceAvailability();
        }
      }
    });
  }

  Future<void> _initLocationAndPermissions() async {
    // If the customer has already manually selected a location during this session,
    // do not automatically overwrite it with the device's physical GPS location.
    if (PriceHelper.currentPosition != null) return;

    // 1. Notification Permission
    try {
      await Permission.notification.request();
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }

    // 2. Location Permission & Fetch
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentPosition = lastKnown;
        });
        _reverseGeocode(lastKnown.latitude, lastKnown.longitude);
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _reverseGeocode(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Error getting position: $e');
    }
  }

  Future<void> _reverseGeocode(double latitude, double longitude) async {
    const String apiKey = "AIzaSyDUSy4tm9GTFNOCZZ5UXjGnEnPnFl1u2hI";
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final formattedAddress = results[0]['formatted_address'] as String;
          final shortAddress = formattedAddress.split(',')[0];
          if (mounted) {
            setState(() {
              _currentAddress = shortAddress;
              _fullAddress = formattedAddress;
            });
            _validateServiceAvailability();
          }
          PriceHelper.currentAddress = shortAddress;
          PriceHelper.fullAddress = formattedAddress;
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
  }

  Future<void> _geocodeAddress(String addressStr) async {
    if (addressStr.isEmpty || addressStr == 'Set delivery address') return;
    const String apiKey = "AIzaSyDUSy4tm9GTFNOCZZ5UXjGnEnPnFl1u2hI";
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(addressStr)}&key=$apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final location = results[0]['geometry']['location'];
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
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
          PriceHelper.currentAddress = _currentAddress;
          PriceHelper.fullAddress = _fullAddress;
          PriceHelper.currentPosition = newPos;
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
  }

  void _listenToCategoryStatus() {
    FirebaseFirestore.instance
        .collection('settings')
        .doc('business_categories')
        .snapshots()
        .listen((snap) {
      if (snap.exists) {
        final data = snap.data();
        if (data != null && mounted) {
          setState(() {
            _categoriesStatus = {
              'Restaurant': data['Restaurant'] != false,
              'Grocery': data['Grocery'] != false,
              'Bakery': data['Bakery'] != false,
              'Pharmacy': data['Pharmacy'] != false,
            };
          });
        }
      }
    });
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
      debugPrint('Error parsing operating hours: $e');
      return true;
    }
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _bannerLength == 0) return;
      final next = (_currentBannerPage + 1) % _bannerLength;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _vendorsSubscription?.cancel();
    _addressesSubscription?.cancel();
    _serviceAvailabilitySubscription?.cancel();
    super.dispose();
  }

  double _getDistanceToVendor(String vendorId) {
    final pos = _currentPosition ?? PriceHelper.currentPosition;
    if (pos == null) return 0.0;
    final vendor = _vendorsMap[vendorId];
    if (vendor == null) return 0.0;
    // Support both storage patterns: geopoint inside businessProfile OR at document root.
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkSurface : Colors.white;
    final showNoVendorsOverlay = _vendorsLoaded &&
        (!_isServiceAvailable ||
            (_currentPosition != null && !_hasVendorsNearby));

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Main Home Screen Layout
            Column(
              children: [
                _buildHeader(isDark),
                Expanded(
                  child: _currentPosition == null
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryColor))
                      : CustomScrollView(
                          slivers: [
                            // Search Bar
                            SliverToBoxAdapter(child: _buildSearchBar(isDark)),
                            // Special Offers + Banner
                            SliverToBoxAdapter(
                                child: _buildBannerSection(isDark)),
                            // Categories Grid
                            SliverPadding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20.w,
                                  vertical:
                                      MediaQuery.of(context).size.width >= 600
                                          ? 8.h
                                          : 4.h),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  mainAxisSpacing:
                                      MediaQuery.of(context).size.width >= 600
                                          ? 12.h
                                          : 10.h,
                                  crossAxisSpacing:
                                      MediaQuery.of(context).size.width >= 600
                                          ? 16.w
                                          : 10.w,
                                  childAspectRatio:
                                      MediaQuery.of(context).size.width >= 600
                                          ? 1.00
                                          : 0.72,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final category = _categories[index];
                                    final title = category['title']!;
                                    return CategoryItem(
                                      title: title,
                                      imageUrl: category['imageUrl']!,
                                      onTap: () {
                                        final isCategoryActive =
                                            _categoriesStatus[title] ?? true;

                                        if (!isCategoryActive) {
                                          showModalBottomSheet(
                                            context: context,
                                            backgroundColor: isDark
                                                ? AppTheme.darkSurface
                                                : Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                      top: Radius.circular(
                                                          28.r)),
                                            ),
                                            builder: (sheetContext) {
                                              final purpleColor =
                                                  AppTheme.primaryPurpleFor(
                                                      isDark);
                                              return Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                    24.w, 16.h, 24.w, 24.h),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 40.w,
                                                      height: 4.h,
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? Colors.grey[700]
                                                            : Colors.grey[300],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(2.r),
                                                      ),
                                                    ),
                                                    SizedBox(height: 24.h),
                                                    Text(
                                                      '$title Coming Soon!',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: AppTypography
                                                            .font(AppFontSizes
                                                                .displaySmall),
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                    SizedBox(height: 12.h),
                                                    Text(
                                                      'We are currently preparing $title services in your area. Stay tuned!',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: AppTypography
                                                            .font(AppFontSizes
                                                                .bodyMedium),
                                                        color: isDark
                                                            ? Colors.grey[400]
                                                            : Colors.grey[600],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    SizedBox(height: 28.h),
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              sheetContext),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            purpleColor,
                                                        foregroundColor:
                                                            Colors.white,
                                                        minimumSize: Size(
                                                            double.infinity,
                                                            54.h),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      18.r),
                                                        ),
                                                        elevation: 0,
                                                      ),
                                                      child: Text(
                                                        'OK',
                                                        style: TextStyle(
                                                          fontSize: AppTypography
                                                              .font(AppFontSizes
                                                                  .bodyMedium),
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(height: 12.h),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        } else {
                                          final route =
                                              '/category/${title.toLowerCase()}';
                                          context.push(route);
                                        }
                                      },
                                    );
                                  },
                                  childCount: _categories.length,
                                ),
                              ),
                            ),
                            // Discounts Section
                            SliverToBoxAdapter(
                                child: _buildDiscountSection(isDark)),
                            // Bulk Items Section
                            SliverToBoxAdapter(
                                child: _buildBulkMealsSection(isDark)),
                            // Restaurants Section
                            SliverToBoxAdapter(
                                child: _buildRestaurantsSection(isDark)),
                            SliverToBoxAdapter(child: SizedBox(height: 8.h)),
                          ],
                        ),
                ),
              ],
            ),

            // Bottom Sheet Overlay Screen covering search bar and bottom nav when no vendors
            if (showNoVendorsOverlay)
              Positioned(
                top: 95.h, // Covers from top of search bar downwards
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildNoVendorsBottomSheetOverlay(isDark),
              ),
          ],
        ),
      ),
      bottomNavigationBar: showNoVendorsOverlay
          ? null
          : MartFoodBottomNavBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                if (index == 1) {
                  context.push('/search');
                } else if (index == 2) {
                  context.push('/orders');
                } else if (index == 3) {
                  context.push('/profile/customer-service');
                } else if (index == 4) {
                  context.push('/profile');
                } else {
                  setState(() => _selectedIndex = index);
                }
              },
            ),
    );
  }

  Widget _buildNoVendorsBottomSheetOverlay(bool isDark) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(28.w, 16.h, 28.w, 24.h),
          child: Column(
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              const Spacer(),
              Image.asset(
                'assets/emoji/sad.png',
                width: 140.w,
                height: 140.w,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 24.h),
              Text(
                "No Vendors Nearby",
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.displaySmall),
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                "We're sorry, our services are currently not available in your location. Tap your address at the top or click below to change location.",
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w500,
                  color: mutedTextColor,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () async {
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
                    _validateServiceAvailability();

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
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 56.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Change Delivery Address",
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Widget _buildHeader(bool isDark) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subtextColor = isDark ? Colors.grey[400] : const Color(0xFF6E7191);

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        String firstName = 'John';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final name = data?['firstName'] ?? data?['fullName'] ?? 'John';
          if (name.toString().trim().isNotEmpty) {
            firstName = name.toString().trim().split(' ').first;
          }
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          child: Column(
            children: [
              // Top Location Bar
              GestureDetector(
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
                    _validateServiceAvailability();

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
                          color: textColor,
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
              SizedBox(height: 12.h),

              // Greeting & Cart Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getGreeting()}, $firstName',
                        style: TextStyle(
                          fontSize:
                              AppTypography.font(AppFontSizes.headlineMedium),
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                  _buildHeaderAction(
                      Icons.shopping_bag_rounded, () => context.push('/cart')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderAction(IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              onTap: onTap,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pillBg,
                ),
                child: Icon(icon, size: 20.sp, color: purpleColor),
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

  // ── Search bar ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar(bool isDark) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF);
    final fieldBg = isDark ? AppTheme.darkSurface : Colors.white;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      child: GestureDetector(
        onTap: () => context.go('/search'),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.search, color: purpleColor, size: 20.sp),
              SizedBox(width: 12.w),
              Text(
                'Search',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Swipeable banner ────────────────────────────────────────────────────────

  Widget _buildBannerSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 4.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: StreamBuilder<QuerySnapshot>(
            stream: _promosStream,
            builder: (context, snapshot) {
              final now = DateTime.now();
              final promos = snapshot.data?.docs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .where((promo) {
                    if (promo['startDate'] != null &&
                        promo['startDate'].toString().isNotEmpty) {
                      try {
                        final start = DateTime.parse(promo['startDate']);
                        if (start.isAfter(now)) return false;
                      } catch (_) {}
                    }
                    if (promo['endDate'] != null &&
                        promo['endDate'].toString().isNotEmpty) {
                      try {
                        final end = DateTime.parse(promo['endDate']);
                        if (end.isBefore(now)) return false;
                      } catch (_) {}
                    }
                    final imageUrl = promo['imageUrl'] ?? '';
                    return imageUrl.toString().isNotEmpty;
                  }).toList() ??
                  [];

              final count =
                  promos.isNotEmpty ? promos.length : _bannerAssets.length;
              if (_bannerLength != count) {
                _bannerLength = count;
              }

              return Column(
                children: [
                  SizedBox(
                    height: 165.h,
                    child: PageView.builder(
                      controller: _bannerController,
                      itemCount: count,
                      onPageChanged: (p) =>
                          setState(() => _currentBannerPage = p),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(24.r),
                          child: promos.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: promos[index]['imageUrl'] ?? '',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (_, __) => Container(
                                    color: isDark
                                        ? Colors.grey[900]
                                        : Colors.grey[200],
                                    child: const Center(
                                        child: CircularProgressIndicator(
                                            color: AppTheme.primaryColor)),
                                  ),
                                  errorWidget: (_, __, ___) => Image.asset(
                                    _bannerAssets[index % _bannerAssets.length],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                )
                              : Image.asset(
                                  _bannerAssets[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(count, (index) {
                      final isActive = _currentBannerPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: EdgeInsets.symmetric(horizontal: 3.w),
                        width: isActive ? 20.w : 6.w,
                        height: 6.h,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primaryColor
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Discount Guaranteed ─────────────────────────────────────────────────────

  Widget _buildDiscountSection(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _discountStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData ||
            _currentPosition == null) {
          return Column(
            children: [
              _buildSectionHeader(
                  'Discount', () => context.push('/discount-guaranteed')),
              SizedBox(
                height: 208.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  itemCount: 3,
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: SkeletonLoader.horizontalFoodCard(context: context),
                  ),
                ),
              ),
            ],
          );
        }
        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isVisible = data['visibleOnMenu'] != false &&
              data['isVisible'] != false &&
              data['visible'] != false;
          if (!isVisible) return false;
          final dist = _getDistanceToVendor(data['vendorId'] ?? '');
          return dist <= PriceHelper.maxDeliveryDistance;
        }).toList();

        if (filteredDocs.isEmpty) {
          return const SizedBox.shrink();
        }

        filteredDocs.sort((a, b) {
          final distA = _getDistanceToVendor(
              (a.data() as Map<String, dynamic>)['vendorId'] ?? '');
          final distB = _getDistanceToVendor(
              (b.data() as Map<String, dynamic>)['vendorId'] ?? '');
          return distA.compareTo(distB);
        });

        return Column(
          children: [
            _buildSectionHeader(
                'Discount', () => context.push('/discount-guaranteed')),
            SizedBox(
              height: 208.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data =
                      filteredDocs[index].data() as Map<String, dynamic>;
                  final title = data['name'] ?? 'Promo Item';
                  final photoUrl = data['photoUrl'] ?? '';
                  final price = (data['basePrice'] ?? 0).toDouble();
                  final promoPriceVal = (data['promoPrice'] ?? 0).toDouble();
                  final vendorId = data['vendorId'] ?? '';
                  final vendorInfo = _vendorsMap[vendorId];
                  final profile =
                      vendorInfo?['businessProfile'] as Map<String, dynamic>?;
                  final vName = profile?['businessName'] ??
                      vendorInfo?['businessName'] ??
                      '';

                  return VendorRatingAndDistanceWrapper(
                    vendorId: vendorId,
                    currentPosition: _currentPosition,
                    vendorData: vendorInfo,
                    postName: title,
                    builder: (context, rating, reviewsCount, distanceKm,
                        deliveryFee) {
                      return Padding(
                        padding: EdgeInsets.only(right: 16.w),
                        child: FoodCardHorizontal(
                          title: title,
                          vendorName: vName.isNotEmpty ? vName : null,
                          isVerified: true,
                          vendorData: vendorInfo,
                          imageUrl: photoUrl.isNotEmpty ? photoUrl : '',
                          rating: rating,
                          reviewsCount: reviewsCount,
                          distanceKm: distanceKm,
                          basePrice: price > 0
                              ? PriceHelper.applyMarkup(price, 'resturantPosts')
                              : null,
                          promoPrice: promoPriceVal > 0
                              ? PriceHelper.applyMarkup(
                                  promoPriceVal, 'resturantPosts')
                              : null,
                          isClosed:
                              !_isVendorOpen(vendorInfo?['operatingHours']),
                          isOutOfStock: data['inStock'] == false ||
                              data['isAvailable'] == false ||
                              (data['quantity'] != null &&
                                  (data['quantity'] as num) <= 0) ||
                              (data['stockQuantity'] != null &&
                                  (data['stockQuantity'] as num) <= 0),
                          onTap: () => context.push('/food-details/$title'),
                          onFavoriteTap: () {},
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Schedule Meal Section ───────────────────────────────────────────────────────

  Widget _buildBulkMealsSection(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _bulkMealsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData ||
            _currentPosition == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Schedule Meal',
                () => context.push('/schedule-meal'),
                subtitle:
                    'Plan your meals ahead and order within the vendor’s available ordering window.',
              ),
              SizedBox(height: 6.h),
              SizedBox(
                height:
                    MediaQuery.of(context).size.width >= 600 ? 218.h : 258.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  itemCount: 3,
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: SkeletonLoader.horizontalFoodCard(context: context),
                  ),
                ),
              ),
            ],
          );
        }
        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isVisible = data['visibleOnMenu'] != false &&
              data['isVisible'] != false &&
              data['visible'] != false;
          if (!isVisible) return false;

          final orderType =
              (data['orderType'] ?? '').toString().toLowerCase().trim();
          final cat =
              (data['mealCategory'] ?? '').toString().toLowerCase().trim();
          final isBulk = orderType == 'bulk' ||
              data['isBulkMeal'] == true ||
              cat.contains('bulk') ||
              cat.contains('schedule');
          if (!isBulk) return false;

          final dist = _getDistanceToVendor(data['vendorId'] ?? '');
          return dist <= PriceHelper.maxDeliveryDistance;
        }).toList();

        if (filteredDocs.isEmpty) {
          return const SizedBox.shrink();
        }

        filteredDocs.sort((a, b) {
          final distA = _getDistanceToVendor(
              (a.data() as Map<String, dynamic>)['vendorId'] ?? '');
          final distB = _getDistanceToVendor(
              (b.data() as Map<String, dynamic>)['vendorId'] ?? '');
          return distA.compareTo(distB);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Schedule Meal',
              () => context.push('/schedule-meal'),
              subtitle:
                  'Plan your meals ahead and order within the vendor’s available ordering window.',
            ),
            SizedBox(height: 6.h),
            SizedBox(
              height: MediaQuery.of(context).size.width >= 600 ? 263.h : 258.h,
              // 255.h on Tablets vs 258.h on Phones
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data =
                      filteredDocs[index].data() as Map<String, dynamic>;
                  final title = data['name'] ?? 'Scheduled Order Item';
                  final photoUrl = data['photoUrl'] ?? data['imageUrl'] ?? '';
                  final price = (data['basePrice'] ?? 0).toDouble();
                  final promoPriceVal = (data['promoPrice'] ?? 0).toDouble();
                  final vendorId = data['vendorId'] ?? '';
                  final vendorInfo = _vendorsMap[vendorId];
                  final profile =
                      vendorInfo?['businessProfile'] as Map<String, dynamic>?;
                  final vName = profile?['businessName'] ??
                      vendorInfo?['businessName'] ??
                      '';

                  final rawOrderStart = data['orderStartTime'] ??
                      data['orderStarttime'];
                  final rawOrderClose = data['orderEndTime'] ??
                      data['orderClosetime'] ??
                      data['orderTimeClose'];
                  final rawDeliveryStart = data['deliveryStartTime'] ??
                      data['deliveryStarttime'];
                  final rawDeliveryClose = data['deliveryEndTime'] ??
                      data['deliveryClosetime'];

                  final orderWindow = MealTimeHelper.formatTimeWindow(
                    rawOrderStart?.toString(),
                    rawOrderClose?.toString(),
                  );
                  final deliveryWindow = MealTimeHelper.formatTimeWindow(
                    rawDeliveryStart?.toString(),
                    rawDeliveryClose?.toString(),
                  );

                  final rawClosesText =
                      (data['orderClosesText'] ?? '').toString().trim();
                  final orderClosesText = rawClosesText.isNotEmpty
                      ? rawClosesText
                      : MealTimeHelper.calculateOrderClosesText(
                          startTimeStr: rawOrderStart?.toString(),
                          closeTimeStr: rawOrderClose?.toString(),
                        );

                  return Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: BulkMealCard(
                      title: title,
                      vendorName: vName.isNotEmpty ? vName : null,
                      isVerified: true,
                      vendorData: vendorInfo,
                      imageUrl: photoUrl.isNotEmpty ? photoUrl : '',
                      price: price > 0
                          ? PriceHelper.applyMarkup(price, 'resturantPosts')
                          : 0,
                      promoPrice: promoPriceVal > 0
                          ? PriceHelper.applyMarkup(
                              promoPriceVal, 'resturantPosts')
                          : null,
                      orderTimeWindow: orderWindow,
                      deliveryTimeWindow: deliveryWindow,
                      orderClosesText: orderClosesText,
                      isClosed: !_isVendorOpen(vendorInfo?['operatingHours']),
                      onTap: () => context.push('/food-details/$title'),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Restaurants Section ─────────────────────────────────────────────────────

  Widget _buildRestaurantsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            'Restaurants', () => context.push('/category/restaurant')),
        SizedBox(
          height: MediaQuery.of(context).size.width >= 600 ? 190.h : 225.h,
          child: Builder(builder: (context) {
            if (_currentPosition == null || _vendorsMap.isEmpty) {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                itemCount: 3,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(right: 16.w),
                  child: SkeletonLoader.verticalFoodCard(context: context),
                ),
              );
            }

            final nearby = _vendorsMap.entries.where((entry) {
              final dist = _getDistanceToVendor(entry.key);
              return dist <= PriceHelper.maxDeliveryDistance;
            }).toList();

            if (nearby.isEmpty) {
              return const SizedBox.shrink();
            }

            nearby.sort((a, b) {
              final distA = _getDistanceToVendor(a.key);
              final distB = _getDistanceToVendor(b.key);
              return distA.compareTo(distB);
            });

            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              itemCount: nearby.length,
              itemBuilder: (context, index) {
                final vendorId = nearby[index].key;
                final data = nearby[index].value;
                final profile =
                    data['businessProfile'] as Map<String, dynamic>?;
                final bannerUrl =
                    profile?['bannerUrl'] ?? profile?['logoUrl'] ?? '';
                final vendorName = profile?['businessName'] ?? 'Adamu Fishery';

                return VendorRatingAndDistanceWrapper(
                  vendorId: vendorId,
                  currentPosition: _currentPosition,
                  vendorData: data,
                  builder:
                      (context, rating, reviewsCount, distanceKm, deliveryFee) {
                    return Padding(
                      padding: EdgeInsets.only(right: 16.w),
                      child: FoodCardVertical(
                        title: vendorName,
                        imageUrl: bannerUrl,
                        rating: rating,
                        reviewsCount: reviewsCount,
                        distanceM: (distanceKm * 1000).toInt(),
                        deliveryTime: '10 - 15 min',
                        isVerified: true,
                        vendorData: data,
                        isClosed: !_isVendorOpen(data['operatingHours']),
                        onTap: () => context.push('/vendor/$vendorId'),
                        onFavoriteTap: () {},
                      ),
                    );
                  },
                );
              },
            );
          }),
        ),
      ],
    );
  }

  // ── Section Header Helper ──────────────────────────────────────────────────

  Widget _buildSectionHeader(
    String title,
    VoidCallback onSeeAll, {
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  SizedBox(height: 3.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                      color: mutedTextColor,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 14.w),
          GestureDetector(
            onTap: onSeeAll,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isDark
                    ? purpleColor.withValues(alpha: 0.2)
                    : const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                'View all',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                  fontWeight: FontWeight.w600,
                  color: purpleColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _validateServiceAvailability() {
    final checkAddr = (_fullAddress.isNotEmpty ? _fullAddress : _currentAddress)
        .toLowerCase();

    if (checkAddr.isEmpty || checkAddr == 'set delivery address') {
      setState(() {
        _isServiceAvailable = true;
      });
      return;
    }

    if (_enabledStatesList.isEmpty &&
        _enabledLgasList.isEmpty &&
        _enabledTownsList.isEmpty) {
      setState(() {
        _isServiceAvailable = true;
      });
      return;
    }

    bool matchFound = false;

    // 1. Check Towns
    for (final town in _enabledTownsList) {
      if (checkAddr.contains(town.toLowerCase().trim())) {
        matchFound = true;
        break;
      }
    }

    // 2. Check LGAs
    if (!matchFound) {
      for (final lga in _enabledLgasList) {
        if (checkAddr.contains(lga.toLowerCase().trim())) {
          matchFound = true;
          break;
        }
      }
    }

    // 3. Check States
    if (!matchFound) {
      for (final state in _enabledStatesList) {
        if (checkAddr.contains(state.toLowerCase().trim())) {
          matchFound = true;
          break;
        }
      }
    }

    setState(() {
      _isServiceAvailable = matchFound;
    });
  }

  bool get _hasVendorsNearby {
    // Don't show content optimistically while location or vendors are loading.
    // Only declare "vendors nearby" once we actually have both location and
    // vendor data and can confirm at least one vendor is within range.
    if (_currentPosition == null || !_vendorsLoaded) {
      return true; // still loading location or initial vendor stream — keep showing content / spinner
    }
    if (_vendorsMap.isEmpty) {
      return false; // vendors loaded, none exist → show "no vendors" UI
    }
    return _vendorsMap.keys.any((vendorId) {
      final dist = _getDistanceToVendor(vendorId);
      return dist <= PriceHelper.maxDeliveryDistance;
    });
  }
}

class VendorRatingAndDistanceWrapper extends StatelessWidget {
  final String vendorId;
  final Position? currentPosition;
  final Map<String, dynamic>? vendorData;

  /// Optional post name used to filter reviews by orderSummary.
  /// Falls back to all vendor reviews when no matching reviews are found.
  final String? postName;
  final Widget Function(
    BuildContext context,
    double rating,
    int reviewsCount,
    double distanceKm,
    double deliveryFee,
  ) builder;

  const VendorRatingAndDistanceWrapper({
    super.key,
    required this.vendorId,
    required this.currentPosition,
    required this.vendorData,
    required this.builder,
    this.postName,
  });

  @override
  Widget build(BuildContext context) {
    double distanceKm = 0.0;
    double deliveryFee = 0.0;

    if (vendorData != null) {
      final baseFee = (vendorData!['deliveryFee'] ?? 0.0).toDouble();
      final profile = vendorData!['businessProfile'] as Map<String, dynamic>?;
      final geoPoint = profile?['currentvendorLocation'] as GeoPoint?;
      if (currentPosition != null && geoPoint != null) {
        distanceKm = Geolocator.distanceBetween(
              currentPosition!.latitude,
              currentPosition!.longitude,
              geoPoint.latitude,
              geoPoint.longitude,
            ) /
            1000.0;
        // Dynamic delivery fee = vendor base + distance surcharge
        deliveryFee =
            PriceHelper.calculateDynamicDeliveryFee(baseFee, distanceKm);
      } else {
        deliveryFee = baseFee;
      }
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .collection('reviews')
          .snapshots(),
      builder: (context, snapshot) {
        final allReviews = snapshot.data?.docs ?? [];

        // Filter to reviews that mention this post in orderSummary
        final postReviews = postName != null
            ? allReviews.where((r) {
                final data = r.data() as Map<String, dynamic>;
                final summary =
                    (data['orderSummary'] ?? '').toString().toLowerCase();
                return summary.contains(postName!.toLowerCase());
              }).toList()
            : <QueryDocumentSnapshot>[];

        // Only use post-specific reviews â€” do NOT fall back to all vendor
        // reviews, because that would make every post share the vendor average.
        final reviews = postName != null ? postReviews : allReviews;

        final double averageRating = reviews.isEmpty
            ? 0.0
            : reviews
                    .map((r) =>
                        (r.data() as Map<String, dynamic>)['rating'] as num? ??
                        0.0)
                    .reduce((a, b) => a + b) /
                reviews.length;

        return builder(
          context,
          double.parse(averageRating.toStringAsFixed(1)),
          reviews.length,
          distanceKm,
          deliveryFee,
        );
      },
    );
  }
}
