import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/category_item.dart';
import 'package:shared_widgets/widgets/food_card_horizontal.dart';
import 'package:shared_widgets/widgets/food_card_vertical.dart';
import 'package:shared_widgets/widgets/bulk_meal_card.dart';
import 'package:shared_widgets/core/utils/meal_time_helper.dart';
import 'package:shared_widgets/widgets/bottom_nav_bar.dart';
import 'package:shared_widgets/widgets/section_divider.dart';
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
import '../../core/services/order_completion_service.dart';
import '../wallet/paystack_service.dart';

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

    _bulkMealsStream =
        FirebaseFirestore.instance.collection('resturantPosts').snapshots();

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
            Responsive.maxContainer(
              context: context,
              maxWidth: 850,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  _buildHeader(isDark),
                  Expanded(
                    child: _currentPosition == null
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primaryColor))
                        : CustomScrollView(
                            slivers: [
                              // Pending Bank Transfer Resume Banner (if any)
                              SliverToBoxAdapter(
                                  child: _buildPendingBankTransferResumeBanner(isDark)),
                              // Search Bar
                              SliverToBoxAdapter(
                                  child: _buildSearchBar(isDark)),
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
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isDark
                                                              ? Colors.grey[700]
                                                              : Colors
                                                                  .grey[300],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      2.r),
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
                                                          color: AppTheme
                                                              .mutedTextColorFor(
                                                                  isDark),
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
                              SliverToBoxAdapter(child: SizedBox(height: 12.h)),
                            ],
                          ),
                  ),
                ],
              ),
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

  Widget _buildPendingBankTransferResumeBanner(bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFC4B5FD);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'awaiting_payment')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // Find bank transfer orders created within the last 2 hours
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final pMethod = data['paymentMethod'];
          final pType = (pMethod is Map) ? pMethod['type']?.toString() : null;
          final isBank = pType == 'bank' || data['paymentReference'] != null;
          if (!isBank) return false;

          final createdAt = data['createdAt'];
          if (createdAt is Timestamp) {
            final diff = DateTime.now().difference(createdAt.toDate());
            return diff.inHours < 2; // Active transfer window
          }
          return true;
        }).toList();

        if (docs.isEmpty) return const SizedBox.shrink();

        final orderDoc = docs.first;
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final orderId = orderDoc.id;
        final double total = ((orderData['total'] ?? 0.0) as num).toDouble();
        final String shortId = orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId;

        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 4.h),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color: purpleColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.landmark,
                    color: purpleColor,
                    size: 18.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Transfer Pending • Order #$shortId',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF15161A),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '₦${total.toStringAsFixed(0)} - Tap to verify and complete',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.caption),
                          fontWeight: FontWeight.w500,
                          color: AppTheme.mutedTextColorFor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  onPressed: () {
                    _showBankTransferVerificationSheet(
                      orderId: orderId,
                      orderData: orderData,
                      isDark: isDark,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Verify',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBankTransferVerificationSheet({
    required String orderId,
    required Map<String, dynamic> orderData,
    required bool isDark,
  }) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final cardBgColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF3F4F6);

    final bankDetails = (orderData['bankDetails'] as Map<String, dynamic>?) ?? {};
    final String bankName = (bankDetails['bankName'] ?? bankDetails['bank_name'] ?? 'Paystack Virtual Bank').toString();
    final String accountName = (bankDetails['accountName'] ?? bankDetails['account_name'] ?? 'MartFood Delivery').toString();
    final String accountNumber = (bankDetails['accountNumber'] ?? bankDetails['account_number'] ?? 'N/A').toString();
    final String reference = (orderData['paymentReference'] ?? '').toString();
    final double amount = ((orderData['total'] ?? 0.0) as num).toDouble();

    bool isVerifying = false;
    String? verificationError;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      elevation: 0,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Verify Bank Transfer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Confirm your transfer for order #${orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    color: mutedTextColor,
                  ),
                ),
                SizedBox(height: 20.h),

                // Bank Account Details Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Name',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.caption),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        bankName,
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Text(
                        'Account Name',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.caption),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        accountName,
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Text(
                        'Account Number',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.caption),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            accountNumber,
                            style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          if (accountNumber != 'N/A')
                            IconButton(
                              icon: Icon(LucideIcons.copy,
                                  size: 18.sp, color: purpleColor),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: accountNumber));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Account number copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.caption),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '₦${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      if (reference.isNotEmpty) ...[
                        SizedBox(height: 14.h),
                        Text(
                          'Reference',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.caption),
                            fontWeight: FontWeight.w500,
                            color: mutedTextColor,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        SelectableText(
                          reference,
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodySmall),
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 14.h),

                if (verificationError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3B1515)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                            : const Color(0xFFFCA5A5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.alertTriangle,
                          size: 18.sp,
                          color: const Color(0xFFEF4444),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            verificationError!,
                            style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.caption),
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFB91C1C),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                ],

                Text(
                  'Payments are usually confirmed within a few minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    fontWeight: FontWeight.w500,
                    color: mutedTextColor,
                  ),
                ),
                SizedBox(height: 20.h),

                // Primary Button: Verify Transfer
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            setSheetState(() {
                              isVerifying = true;
                              verificationError = null;
                            });

                            bool isSuccess = false;
                            try {
                              if (reference.isNotEmpty) {
                                final verifyRes =
                                    await PaystackService.verifyTransaction(reference);
                                if (verifyRes != null &&
                                    (verifyRes['status'] == 'success' ||
                                        verifyRes['status'] == true)) {
                                  isSuccess = true;
                                }
                              }
                            } catch (_) {}

                            if (!sheetContext.mounted) return;

                            if (isSuccess) {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(sheetContext);
                              await OrderCompletionService.completeOrderPayment(
                                orderId: orderId,
                              );
                              if (mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Payment verified! Order confirmed.'),
                                  ),
                                );
                              }
                            } else {
                              setSheetState(() {
                                isVerifying = false;
                                verificationError =
                                    "We haven't received your transfer yet. Please make sure you completed the payment in your banking app. If you just sent it, please wait a minute and tap to retry.";
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 56.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      elevation: 0,
                    ),
                    child: isVerifying
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Verifying Transfer...',
                                style: TextStyle(
                                  fontSize:
                                      AppTypography.font(AppFontSizes.bodyMedium),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            verificationError != null
                                ? 'Retry Verification'
                                : "I've Made the Transfer",
                            style: TextStyle(
                              fontSize:
                                  AppTypography.font(AppFontSizes.bodyMedium),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 12.h),

                TextButton.icon(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: Icon(
                    LucideIcons.xCircle,
                    size: 20.sp,
                    color: mutedTextColor,
                  ),
                  label: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      fontWeight: FontWeight.w600,
                      color: mutedTextColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoVendorsBottomSheetOverlay(bool isDark) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
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
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 650,
            alignment: Alignment.topCenter,
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
    final subtextColor = AppTheme.mutedTextColorFor(isDark);

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        final currentUser = FirebaseAuth.instance.currentUser;
        final isGuest = currentUser == null;
        String firstName = isGuest ? 'Guest' : 'John';
        if (!isGuest && snapshot.hasData && snapshot.data!.exists) {
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
                        isGuest
                            ? 'Welcome to MartFood'
                            : '${_getGreeting()}, $firstName',
                        style: TextStyle(
                          fontSize:
                              AppTypography.font(AppFontSizes.headlineSmall),
                          fontWeight: FontWeight.w800,
                          color: purpleColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        isGuest
                            ? 'Explore meals & daily essentials'
                            : 'Welcome back',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                  _buildHeaderAction(
                    Icons.shopping_bag_rounded,
                    () => context.push('/cart'),
                  ),
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
                  color: AppTheme.hintColorFor(isDark),
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
    return StreamBuilder<QuerySnapshot>(
      stream: _promosStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final promos = snapshot.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .where((promo) {
              if (promo['isActive'] == false) return false;

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
              return imageUrl.toString().trim().isNotEmpty;
            }).toList();

        if (promos.isEmpty) {
          return const SizedBox.shrink();
        }

        final count = promos.length;
        if (_bannerLength != count) {
          _bannerLength = count;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  SizedBox(
                    height: 165.h,
                    child: PageView.builder(
                      controller: _bannerController,
                      itemCount: count,
                      onPageChanged: (p) =>
                          setState(() => _currentBannerPage = p),
                      itemBuilder: (context, index) {
                        final imageUrl = (promos[index]['imageUrl'] ?? '').toString();
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(24.r),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, __) => Container(
                              color: isDark
                                  ? Colors.grey[900]
                                  : Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: isDark
                                  ? AppTheme.darkSurface
                                  : Colors.grey[100],
                              child: Center(
                                child: Icon(
                                  LucideIcons.imageOff,
                                  color: AppTheme.mutedTextColorFor(isDark),
                                  size: 28.sp,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (count > 1) ...[
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
                                ? AppTheme.primaryPurpleFor(isDark)
                                : (isDark ? Colors.grey[800] : Colors.grey[300]),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
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
              _buildSectionDivider(isDark),
              _buildSectionHeader(
                  'Discounts', () => context.push('/discount-guaranteed')),
              SizedBox(
                height: 160.h,
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
            _buildSectionDivider(isDark),
            _buildSectionHeader(
                'Discounts', () => context.push('/discount-guaranteed')),
            SizedBox(
              height: MediaQuery.of(context).size.width >= 600 ? 178.h : 184.h,
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
              _buildSectionDivider(isDark),
              _buildSectionHeader(
                'Schedule Meal',
                () => context.push('/schedule-meal'),
                subtitle:
                    'Plan your meals ahead and order within the vendor’s available ordering window.',
              ),
              SizedBox(height: 6.h),
              SizedBox(
                height:
                    MediaQuery.of(context).size.width >= 600 ? 308.h : 302.h,
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
            _buildSectionDivider(isDark),
            _buildSectionHeader(
              'Schedule Meal',
              () => context.push('/schedule-meal'),
              subtitle:
                  'Plan your meals ahead and order within the vendor’s available ordering window.',
            ),
            SizedBox(height: 6.h),
            SizedBox(
              height: MediaQuery.of(context).size.width >= 600 ? 332.h : 330.h,
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

                  final rawOrderStart =
                      data['orderStartTime'] ?? data['orderStarttime'];
                  final rawOrderClose = data['orderEndTime'] ??
                      data['orderClosetime'] ??
                      data['orderTimeClose'];
                  final rawDeliveryStart =
                      data['deliveryStartTime'] ?? data['deliveryStarttime'];
                  final rawDeliveryClose =
                      data['deliveryEndTime'] ?? data['deliveryClosetime'];

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

                  final isTablet = MediaQuery.of(context).size.width >= 600;

                  return Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: BulkMealCard(
                      title: title,
                      vendorName: vName.isNotEmpty ? vName : null,
                      isVerified: true,
                      vendorData: vendorInfo,
                      imageUrl: photoUrl.isNotEmpty ? photoUrl : '',
                      height: isTablet ? 313.h : 313.h,
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
        _buildSectionDivider(isDark),
        _buildSectionHeader(
            'Restaurants', () => context.push('/category/restaurant')),
        SizedBox(
          height: MediaQuery.of(context).size.width >= 600 ? 180.h : 214.h,
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
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

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
                      fontSize: AppTypography.font(AppFontSizes.caption),
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
                  color: isDark ? Colors.white : purpleColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Thick Divider Helper ───────────────────────────────────────────
  Widget _buildSectionDivider(bool isDark) {
    return SectionDivider(
      margin: EdgeInsets.only(top: 14.h, bottom: 18.h),
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
