import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'package:shared_widgets/widgets/bottom_nav_bar.dart';
import 'package:shared_widgets/widgets/food_card_horizontal.dart';
import 'package:shared_widgets/widgets/skeleton_loader.dart';
import '../../core/services/price_helper.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _selectedTab = 'Restaurants';

  // Filter Options State
  String _sortBy = 'All'; // 'All', 'Discount', 'Top Rated', 'Nearest'
  String?
      _deliveryTimeFilter; // null, 'Under 15 mins', '15 - 30 mins', '30 - 40 mins', '45+ mins'
  double? _minRatingFilter; // null, 4.5, 4.0, 3.5, 2.5
  double _selectedDistanceKm = 10.0; // 1.0 to 10.0 km

  bool get _hasActiveFilters =>
      _sortBy != 'All' ||
      _deliveryTimeFilter != null ||
      _minRatingFilter != null ||
      _selectedDistanceKm < 10.0;

  Position? _currentPosition;
  Map<String, Map<String, dynamic>> _vendorsMap = {};
  StreamSubscription? _vendorsSubscription;
  bool _vendorsLoaded = false;

  // Service Coverage State
  String _currentAddress = 'Set delivery address';
  String _fullAddress = '';
  bool _isServiceAvailable = true;
  List<String> _enabledStatesList = [];
  List<String> _enabledLgasList = [];
  List<String> _enabledTownsList = [];
  StreamSubscription<DocumentSnapshot>? _serviceAvailabilitySubscription;
  StreamSubscription<QuerySnapshot>? _addressesSubscription;

  // Debug log entries shown in the on-screen console
  final List<String> _debugLogs = [];

  // The cached combined stream — rebuilt only when tab changes
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

  // Firestore collection names (matching the rest of the app)
  static const Map<String, String> _collectionMap = {
    'Restaurants': 'resturantPosts',
    'Grocery': 'grocerytPosts',
    'Pharmacy': 'pharmacytPosts',
    'Bakery': 'bakerytPosts',
  };

  /// Safe log — always prints to console; schedules panel update after the
  /// current frame so it never calls setState() during a build.
  void _log(String msg) {
    final time = DateTime.now();
    final label =
        '[${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}] $msg';
    debugPrint('🔍 SEARCH_DEBUG: $label');
    // Schedule the UI update for after the current frame — safe even when
    // called from initState / listeners, but also harmless from build().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _debugLogs.insert(0, label);
          if (_debugLogs.length > 80) _debugLogs.removeLast();
        });
      }
    });
  }

  /// Print-only version — use inside builder/where callbacks to avoid
  /// triggering a setState() during the build phase.
  void _dprint(String msg) {
    debugPrint('🔍 SEARCH_DEBUG: $msg');
  }

  @override
  void initState() {
    super.initState();
    // Seed from PriceHelper — do NOT overwrite with GPS if already set
    _currentPosition = PriceHelper.currentPosition;
    if (PriceHelper.currentAddress != null) {
      _currentAddress = PriceHelper.currentAddress!;
    }
    if (PriceHelper.fullAddress != null) {
      _fullAddress = PriceHelper.fullAddress!;
    }

    _log(
        'initState — PriceHelper.currentPosition: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
    _log('initState — PriceHelper.currentAddress: $_currentAddress');
    _log(
        'initState — maxDeliveryDistance: ${PriceHelper.maxDeliveryDistance} km');

    PriceHelper.locationNotifier.addListener(_onLocationChanged);
    _listenToVendors();
    _buildCombinedStream();

    // Subscribe to service availability settings
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

  void _onLocationChanged() {
    _log(
        'locationNotifier fired — new pos: ${PriceHelper.currentPosition?.latitude}, ${PriceHelper.currentPosition?.longitude}');
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
      _validateServiceAvailability();
    }
  }

  @override
  void dispose() {
    PriceHelper.locationNotifier.removeListener(_onLocationChanged);
    _searchController.dispose();
    _vendorsSubscription?.cancel();
    _serviceAvailabilitySubscription?.cancel();
    _addressesSubscription?.cancel();
    super.dispose();
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

  Widget _buildServiceUnavailableView(bool isDark) {
    const primaryColor = AppTheme.primaryColor;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
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
            "No vendors available in this location yet",
            style: TextStyle(
              fontSize: AppTypography.font(20),
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          Text(
            "We're sorry, our services are not available in this region yet. We are working hard to expand our coverage areas!",
            style: TextStyle(
              fontSize: AppTypography.font(14),
              fontWeight: FontWeight.w500,
              color: mutedTextColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          ElevatedButton(
            onPressed: () async {
              final result = await context.push('/profile/address/location');
              if (result != null && result is Map<String, dynamic>) {
                setState(() {
                  _currentAddress = result['title'] ?? _currentAddress;
                  _fullAddress = result['address'] ?? '';
                });
                _validateServiceAvailability();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 0,
            ),
            child: Text(
              "Select Another Location",
              style: TextStyle(
                fontSize: AppTypography.font(14),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final unselectedChipBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final unselectedBorderColor =
        isDark ? AppTheme.darkBorder : const Color(0xFFE2E4EA);
    final unselectedTextColor =
        isDark ? Colors.grey[300]! : const Color(0xFF4A4A68);

    // Draft local state for modal
    String draftSortBy = _sortBy;
    String? draftDeliveryTime = _deliveryTimeFilter;
    double? draftMinRating = _minRatingFilter;
    double draftDistanceKm = _selectedDistanceKm;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      elevation: 0,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildSectionHeader(String title) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h, top: 16.h),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTypography.font(16),
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
              );
            }

            Widget buildChip({
              required String label,
              required bool isSelected,
              required VoidCallback onTap,
            }) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(24.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? purpleColor : unselectedChipBg,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(
                        color: isSelected ? purpleColor : unselectedBorderColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: AppTypography.font(13),
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : unselectedTextColor,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 32.h),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 38.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[700]
                              : const Color(0xFFDCDCE0),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Section 1: Sort By
                    buildSectionHeader('Sort By'),
                    Wrap(
                      spacing: 10.w,
                      runSpacing: 10.h,
                      children: [
                        'All',
                        'Discount',
                        'Top Rated',
                        'Nearest',
                      ].map((option) {
                        return buildChip(
                          label: option,
                          isSelected: draftSortBy == option,
                          onTap: () {
                            setSheetState(() {
                              draftSortBy = option;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    // Section 2: Delivery Time
                    buildSectionHeader('Delivery Time'),
                    Wrap(
                      spacing: 10.w,
                      runSpacing: 10.h,
                      children: [
                        'Under 15 mins',
                        '15 - 30 mins',
                        '30 - 40 mins',
                        '45+ mins',
                      ].map((option) {
                        final isSel = draftDeliveryTime == option;
                        return buildChip(
                          label: option,
                          isSelected: isSel,
                          onTap: () {
                            setSheetState(() {
                              draftDeliveryTime = isSel ? null : option;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    // Section 3: Minimum Rating
                    buildSectionHeader('Minimum Rating'),
                    Wrap(
                      spacing: 10.w,
                      runSpacing: 10.h,
                      children: [
                        {'label': '4.5 & above', 'val': 4.5},
                        {'label': '4.0+', 'val': 4.0},
                        {'label': '3.5+', 'val': 3.5},
                        {'label': '2.5+', 'val': 2.5},
                      ].map((item) {
                        final label = item['label'] as String;
                        final val = item['val'] as double;
                        final isSel = draftMinRating == val;
                        return buildChip(
                          label: label,
                          isSelected: isSel,
                          onTap: () {
                            setSheetState(() {
                              draftMinRating = isSel ? null : val;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    // Section 4: Distance
                    buildSectionHeader('Distance'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Within',
                          style: TextStyle(
                            fontSize: AppTypography.font(14),
                            color: mutedTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${draftDistanceKm.round()} km',
                          style: TextStyle(
                            fontSize: AppTypography.font(14),
                            color: purpleColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4.h,
                        activeTrackColor: purpleColor,
                        inactiveTrackColor:
                            isDark ? Colors.grey[800] : const Color(0xFFF0EBF8),
                        thumbColor: purpleColor,
                        overlayColor: purpleColor.withValues(alpha: 0.15),
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 9.r,
                        ),
                      ),
                      child: Slider(
                        value: draftDistanceKm.clamp(1.0, 10.0),
                        min: 1.0,
                        max: 10.0,
                        divisions: 9,
                        onChanged: (val) {
                          setSheetState(() {
                            draftDistanceKm = val;
                          });
                        },
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // Bottom Action Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setSheetState(() {
                                draftSortBy = 'All';
                                draftDeliveryTime = null;
                                draftMinRating = null;
                                draftDistanceKm = 10.0;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF27272A)
                                  : const Color(0xFFF3F4F8),
                              foregroundColor: primaryTextColor,
                              elevation: 0,
                              minimumSize: Size(double.infinity, 52.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.r),
                              ),
                            ),
                            child: Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: AppTypography.font(15),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _sortBy = draftSortBy;
                                _deliveryTimeFilter = draftDeliveryTime;
                                _minRatingFilter = draftMinRating;
                                _selectedDistanceKm = draftDistanceKm;
                              });
                              Navigator.pop(sheetContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: Size(double.infinity, 52.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.r),
                              ),
                            ),
                            child: Text(
                              'Show Result',
                              style: TextStyle(
                                fontSize: AppTypography.font(15),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _getDistanceToVendor(String vendorId) {
    final pos = _currentPosition ?? PriceHelper.currentPosition;
    if (pos == null) return 999999.0;
    final vendor = _vendorsMap[vendorId];
    if (vendor == null) return 999999.0;
    final profile = vendor['businessProfile'] as Map<String, dynamic>?;
    final geoPoint = (profile?['currentvendorLocation'] as GeoPoint?) ??
        (vendor['currentvendorLocation'] as GeoPoint?) ??
        (vendor['location'] as GeoPoint?);
    if (geoPoint == null) return 999999.0;
    return Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          geoPoint.latitude,
          geoPoint.longitude,
        ) /
        1000.0;
  }

  double _extractRating(
      Map<String, dynamic> item, Map<String, dynamic>? vendor) {
    // 1. Direct item rating
    final itemRating = item['rating'] ?? item['averageRating'] ?? item['stars'];
    if (itemRating != null) {
      final parsed = double.tryParse(itemRating.toString());
      if (parsed != null && parsed > 0.0) return parsed;
    }
    // 2. Vendor profile rating
    if (vendor != null) {
      final profile = vendor['businessProfile'] as Map<String, dynamic>?;
      final vendorRating = profile?['rating'] ??
          profile?['averageRating'] ??
          vendor['rating'] ??
          vendor['averageRating'] ??
          vendor['stars'];
      if (vendorRating != null) {
        final parsed = double.tryParse(vendorRating.toString());
        if (parsed != null && parsed > 0.0) return parsed;
      }
    }
    return 0.0;
  }

  double _extractPrepTimeMinutes(
      Map<String, dynamic> item, Map<String, dynamic>? vendor) {
    // Helper to parse numbers or string ranges like "20-30 mins"
    double? parseTime(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      final str = val.toString().toLowerCase().replaceAll('mins', '').replaceAll('min', '').trim();
      if (str.isEmpty) return null;
      if (str.contains('-')) {
        final parts = str.split('-');
        if (parts.length >= 2) {
          final p1 = double.tryParse(parts[0].trim());
          final p2 = double.tryParse(parts[1].trim());
          if (p1 != null && p2 != null) return (p1 + p2) / 2.0;
          if (p2 != null) return p2;
        }
      }
      return double.tryParse(str);
    }

    final tItem = parseTime(item['prepTimeMinutes'] ??
        item['prepTime'] ??
        item['preparationTime'] ??
        item['deliveryTime']);
    if (tItem != null && tItem > 0) return tItem;

    if (vendor != null) {
      final profile = vendor['businessProfile'] as Map<String, dynamic>?;
      final tVendor = parseTime(vendor['preparationTime'] ??
          vendor['prepTime'] ??
          vendor['prepTimeMinutes'] ??
          profile?['preparationTime'] ??
          profile?['prepTime'] ??
          vendor['deliveryTime']);
      if (tVendor != null && tVendor > 0) return tVendor;
    }

    return 15.0;
  }

  double _extractDiscountFraction(Map<String, dynamic> item) {
    final basePrice = (item['basePrice'] as num?)?.toDouble() ??
        (item['price'] as num?)?.toDouble() ??
        0.0;
    final promoPrice = (item['promoPrice'] as num?)?.toDouble();

    if (promoPrice != null && promoPrice > 0 && basePrice > promoPrice) {
      return (basePrice - promoPrice) / basePrice;
    }

    final discountPct = (item['discountPercentage'] as num?)?.toDouble() ??
        (item['discountPercent'] as num?)?.toDouble() ??
        (item['discount'] as num?)?.toDouble();
    if (discountPct != null && discountPct > 0) {
      return (discountPct > 1.0 ? discountPct / 100.0 : discountPct);
    }

    if (item['isPromotion'] == true || item['isDiscountGuaranteed'] == true) {
      return 0.10; // Default 10% indicator if flagged as promotional
    }

    return 0.0;
  }

  void _listenToVendors() {
    _log('Starting vendors listener...');
    _vendorsSubscription = FirebaseFirestore.instance
        .collection('vendors')
        .where('businessProfile.status', isEqualTo: 'verified')
        .snapshots()
        .listen((snapshot) {
      final map = <String, Map<String, dynamic>>{};
      for (var doc in snapshot.docs) {
        map[doc.id] = doc.data();
      }
      _log('Vendors loaded: ${map.length} verified vendors');
      for (final entry in map.entries) {
        final profile = entry.value['businessProfile'] as Map<String, dynamic>?;
        final geo = profile?['currentvendorLocation'] ??
            entry.value['currentvendorLocation'];
        _log('  vendor ${entry.key}: geoPoint=$geo');
      }
      if (mounted) {
        setState(() {
          _vendorsMap = map;
          _vendorsLoaded = true;
        });
      }
    });
  }

  /// Build (or rebuild) a combined Firestore stream for the active tab.
  /// Only called when the tab changes — not on every build().
  void _buildCombinedStream() {
    final collectionsToListen = [
      _collectionMap[_selectedTab] ?? 'resturantPosts'
    ];

    _log('Building stream for collections: $collectionsToListen');

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
      _log('Stream emitting ${allItems.length} total raw posts');
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
        }).toList();
        _log('Collection "$collName" returned ${items.length} docs');
        for (final item in items) {
          _log('  post: name=${item['name']}, vendorId=${item['vendorId']}');
        }
        lastData[collName] = items;
        emitCombined();
      }, onError: (err) {
        _log('ERROR listening to $collName: $err');
        debugPrint('Error listening to $collName: $err');
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
    setState(() => _selectedTab = tab);
    _buildCombinedStream();
  }

  Widget _buildCategoryItem({
    required BuildContext context,
    required String title,
    required String imageUrl,
    required IconData? iconData,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

    final isTablet = MediaQuery.of(context).size.width >= 600;
    final circleSize = isTablet ? 48.r : 44.r;
    final iconSize = isTablet ? 34.r : 30.r;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
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
                  fontSize: AppTypography.font(isTablet ? 12 : 11),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF121212) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor =
        isDark ? Colors.white.withAlpha(15) : const Color(0xFFE9EAF0);

    final isTablet = MediaQuery.of(context).size.width >= 600;
    final double headerHeight = 116.h;
    final double categoryHeight = (isTablet ? 104.h : 88.h) + 12.h;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          floatHeaderSlivers: true,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor: backgroundColor,
                elevation: 0,
                scrolledUnderElevation: 0,
                floating: true,
                pinned: false,
                snap: false,
                toolbarHeight: 0,
                collapsedHeight: 0,
                expandedHeight: headerHeight,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    final currentHeight = constraints.biggest.height;
                    final t = (currentHeight / headerHeight).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: t,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          height: headerHeight,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ─── Screen Text Header: Search ──────────────
                              Padding(
                                padding: EdgeInsets.only(top: 8.h, bottom: 4.h),
                                child: Center(
                                  child: Text(
                                    'Search',
                                    style: TextStyle(
                                      color: purpleColor,
                                      fontSize: AppTypography.font(
                                          AppFontSizes.displaySmall),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),

                              // ─── Search Bar & Filter ─────────────────────
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20.w, vertical: 6.h),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: surfaceColor,
                                          borderRadius:
                                              BorderRadius.circular(18.r),
                                          border:
                                              Border.all(color: borderColor),
                                          boxShadow: null,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(LucideIcons.search,
                                                color: mutedTextColor,
                                                size: 20.sp),
                                            SizedBox(width: 12.w),
                                            Expanded(
                                              child: TextField(
                                                controller: _searchController,
                                                onChanged: (val) {
                                                  setState(() =>
                                                      _searchText = val.trim());
                                                },
                                                style: TextStyle(
                                                  color: primaryTextColor,
                                                  fontSize: AppTypography.font(
                                                      AppFontSizes.bodyMedium),
                                                ),
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Search restaurants, groceries...',
                                                  hintStyle: TextStyle(
                                                      color: mutedTextColor,
                                                      fontSize:
                                                          AppTypography.font(
                                                              AppFontSizes
                                                                  .bodyMedium)),
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                ),
                                              ),
                                            ),
                                            if (_searchText.isNotEmpty)
                                              GestureDetector(
                                                onTap: () {
                                                  _searchController.clear();
                                                  setState(() =>
                                                      _searchText = '');
                                                },
                                                child: Icon(
                                                    Icons.close_rounded,
                                                    color: mutedTextColor,
                                                    size: 20.sp),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    // Filter Icon Button
                                    GestureDetector(
                                      onTap: () =>
                                          _showFilterBottomSheet(context),
                                      child: Container(
                                        width: 48.w,
                                        height: 48.w,
                                        decoration: BoxDecoration(
                                          color: _hasActiveFilters
                                              ? AppTheme.primaryPurpleFor(isDark)
                                                  .withValues(alpha: 0.15)
                                              : surfaceColor,
                                          borderRadius:
                                              BorderRadius.circular(18.r),
                                          border: Border.all(
                                            color: _hasActiveFilters
                                                ? AppTheme.primaryPurpleFor(isDark)
                                                : borderColor,
                                            width: 1,
                                          ),
                                          boxShadow: null,
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Icon(
                                              LucideIcons.filter,
                                              color: _hasActiveFilters
                                                  ? AppTheme.primaryPurpleFor(isDark)
                                                  : mutedTextColor,
                                              size: 20.sp),
                                            if (_hasActiveFilters)
                                              Positioned(
                                                top: 10.h,
                                                right: 10.w,
                                                child: Container(
                                                  width: 7.w,
                                                  height: 7.w,
                                                  decoration: BoxDecoration(
                                                    color: AppTheme
                                                        .primaryPurpleFor(isDark),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ─── Category Tabs (Pinned) ──────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedHeaderDelegate(
                  height: categoryHeight,
                  backgroundColor: backgroundColor,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 8.h),
                    child: SizedBox(
                      height: isTablet ? 104.h : 88.h,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _categories.map((cat) {
                          final title = cat['title'] as String;
                          final imageUrl =
                              (cat['imageUrl'] ?? '').toString();
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
                ),
              ),
            ];
          },

          // ─── Results Body ──────────────────────────────────────────────
          body: !_isServiceAvailable
                        ? _buildServiceUnavailableView(isDark)
                        : StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _combinedStream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !snapshot.hasData) {
                                return ListView.separated(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 20.w),
                                  itemCount: 4,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(height: 16.h),
                                  itemBuilder: (_, __) =>
                                      SkeletonLoader.verticalFoodCard(
                                          context: context),
                                );
                              }

                              final allItems = snapshot.data ?? [];

                              // ─── DEBUG: log filtering details (print-only, no setState) ─
                              if (allItems.isNotEmpty || _vendorsLoaded) {
                                final posInfo = _currentPosition != null
                                    ? '${_currentPosition!.latitude.toStringAsFixed(4)},${_currentPosition!.longitude.toStringAsFixed(4)}'
                                    : 'NULL';
                                _dprint(
                                    'StreamBuilder rebuild: ${allItems.length} raw posts | pos=$posInfo | vendorsLoaded=$_vendorsLoaded | vendorCount=${_vendorsMap.length}');
                              }

                              final userPos =
                                  _currentPosition ?? PriceHelper.currentPosition;

                              final filteredItems = allItems.where((item) {
                                final isVisible = item['visibleOnMenu'] !=
                                        false &&
                                    item['isVisible'] != false &&
                                    item['visible'] != false;
                                if (!isVisible) return false;

                                final vendorId = item['vendorId'] ?? '';
                                final vendor = _vendorsMap[vendorId];

                                // 1. Search Text filter
                                if (_searchText.isNotEmpty) {
                                  final name = (item['name'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final query = _searchText.toLowerCase();
                                  final vProfile = vendor?['businessProfile']
                                      as Map<String, dynamic>?;
                                  final vName = (vProfile?['restaurantName'] ??
                                          vProfile?['businessName'] ??
                                          vendor?['restaurantName'] ??
                                          '')
                                      .toString()
                                      .toLowerCase();
                                  if (!name.contains(query) &&
                                      !vName.contains(query)) {
                                    return false;
                                  }
                                }

                                // 2. Distance filter
                                final dist = _getDistanceToVendor(vendorId);
                                final maxDist = _selectedDistanceKm;
                                if (userPos != null && dist < 999990.0) {
                                  if (dist > maxDist) {
                                    return false;
                                  }
                                }

                                // 3. Discount filter (if Sort By is 'Discount')
                                if (_sortBy == 'Discount') {
                                  final discountFraction =
                                      _extractDiscountFraction(item);
                                  if (discountFraction <= 0.0) return false;
                                }

                                // 4. Delivery Time filter
                                if (_deliveryTimeFilter != null) {
                                  final double prepTime =
                                      _extractPrepTimeMinutes(item, vendor);
                                  final double transitTime =
                                      (dist < 999990.0) ? (dist * 3.0) : 10.0;
                                  final double estMins = prepTime + transitTime;

                                  if (_deliveryTimeFilter == 'Under 15 mins') {
                                    if (estMins > 15.0) return false;
                                  } else if (_deliveryTimeFilter ==
                                      '15 - 30 mins') {
                                    if (estMins < 15.0 || estMins > 30.0) {
                                      return false;
                                    }
                                  } else if (_deliveryTimeFilter ==
                                      '30 - 40 mins') {
                                    // Covers 30 up to 45 mins smoothly without gap
                                    if (estMins < 30.0 || estMins > 45.0) {
                                      return false;
                                    }
                                  } else if (_deliveryTimeFilter ==
                                      '45+ mins') {
                                    if (estMins < 45.0) return false;
                                  }
                                }

                                // 5. Minimum Rating filter
                                if (_minRatingFilter != null) {
                                  final double rating =
                                      _extractRating(item, vendor);
                                  if (rating < _minRatingFilter!) {
                                    return false;
                                  }
                                }

                                return true;
                              }).toList();

                              _dprint(
                                  'After filtering: ${filteredItems.length} posts visible');

                              // ── Sort results based on _sortBy mode ──────────────
                              filteredItems.sort((a, b) {
                                final vendorA =
                                    _vendorsMap[a['vendorId'] ?? ''];
                                final vendorB =
                                    _vendorsMap[b['vendorId'] ?? ''];
                                final distA =
                                    _getDistanceToVendor(a['vendorId'] ?? '');
                                final distB =
                                    _getDistanceToVendor(b['vendorId'] ?? '');

                                if (_sortBy == 'Nearest') {
                                  return distA.compareTo(distB);
                                } else if (_sortBy == 'Top Rated') {
                                  final double ratingA =
                                      _extractRating(a, vendorA);
                                  final double ratingB =
                                      _extractRating(b, vendorB);
                                  if (ratingA != ratingB) {
                                    return ratingB.compareTo(ratingA);
                                  }
                                  return distA.compareTo(distB);
                                } else if (_sortBy == 'Discount') {
                                  final double discA =
                                      _extractDiscountFraction(a);
                                  final double discB =
                                      _extractDiscountFraction(b);
                                  if (discA != discB) {
                                    return discB.compareTo(discA);
                                  }
                                  return distA.compareTo(distB);
                                } else {
                                  // Default ('All'): nearest distance order
                                  return distA.compareTo(distB);
                                }
                              });

                              if (filteredItems.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 24.w, vertical: 40.h),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/emoji/sad.png',
                                          width: 120.w,
                                          height: 120.w,
                                          fit: BoxFit.contain,
                                        ),
                                        SizedBox(height: 20.h),
                                        Text(
                                          _searchText.isEmpty
                                              ? 'No Posts Found'
                                              : 'No Results Found',
                                          style: TextStyle(
                                            fontSize: AppTypography.font(
                                                AppFontSizes.bodyLarge + 2),
                                            fontWeight: FontWeight.w800,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                        SizedBox(height: 8.h),
                                        Text(
                                          _searchText.isEmpty
                                              ? 'There are no active food posts or items available at this time.'
                                              : 'We couldn\'t find any matches for "$_searchText". Try checking your spelling or search for something else!',
                                          style: TextStyle(
                                            fontSize: AppTypography.font(
                                                AppFontSizes.bodySmall),
                                            fontWeight: FontWeight.w500,
                                            color: mutedTextColor,
                                            height: 1.4,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return GridView.builder(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20.w, vertical: 10.h),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      MediaQuery.of(context).size.width >= 900
                                          ? 4
                                          : (MediaQuery.of(context)
                                                      .size
                                                      .width >=
                                                  600
                                              ? 3
                                              : 2),
                                  crossAxisSpacing: 14.w,
                                  mainAxisSpacing: 10.h,
                                  childAspectRatio:
                                      MediaQuery.of(context).size.width >= 900
                                          ? 0.92
                                          : (MediaQuery.of(context)
                                                      .size
                                                      .width >=
                                                  600
                                              ? 0.88
                                              : 0.86),
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
      ),
      bottomNavigationBar: MartFoodBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) context.go('/home');
          if (index == 2) context.go('/orders');
          if (index == 3) context.go('/profile/customer-service');
          if (index == 4) context.go('/profile');
        },
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Color backgroundColor;
  final Widget child;

  _PinnedHeaderDelegate({
    required this.height,
    required this.backgroundColor,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: height,
      color: backgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.child != child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extracted item widget — owns its own Firestore reviews stream so each card
// rebuilds in isolation rather than cascading rebuilds across the whole list.
// ─────────────────────────────────────────────────────────────────────────────

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

    // Use vendorInfo already passed in — no extra Firestore stream per card
    final profile = vendorInfo?['businessProfile'] as Map<String, dynamic>?;
    final vendorName = (profile?['restaurantName'] ??
            profile?['businessName'] ??
            vendorInfo?['restaurantName'] ??
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
          isPromo: item['isPromotion'] == true,
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
    debugPrint('Error parsing operating hours: $e');
    return true;
  }
}
