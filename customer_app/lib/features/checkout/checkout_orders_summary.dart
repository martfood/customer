import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/services/notification_service.dart';
import '../../core/services/price_helper.dart';
import '../wallet/paystack_service.dart';
import 'add_card_bottom_sheet.dart';

/// Result of checking delivery address service coverage.
class CoverageCheckResult {
  final bool isWithinCoverage;
  final String? errorMessage;
  final double distanceKm;
  final double recalculatedFee;
  final double surcharge;
  final Map<String, dynamic>? resolvedAddress;

  CoverageCheckResult({
    required this.isWithinCoverage,
    this.errorMessage,
    this.distanceKm = 0.0,
    this.recalculatedFee = 0.0,
    this.surcharge = 0.0,
    this.resolvedAddress,
  });
}

class CheckoutOrdersSummaryScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? checkoutItems;

  const CheckoutOrdersSummaryScreen({
    super.key,
    this.checkoutItems,
  });

  @override
  State<CheckoutOrdersSummaryScreen> createState() =>
      _CheckoutOrdersSummaryScreenState();
}

class _CheckoutOrdersSummaryScreenState
    extends State<CheckoutOrdersSummaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _selectedAddress;
  bool _isCheckingCoverage = false;
  bool _isAddressOutOfCoverage = false;
  String? _coverageErrorMessage;
  Map<String, dynamic>? _selectedPayment = {
    'type': 'wallet',
    'name': 'MartFood Wallet',
  };
  bool _hideOrderDetailsForSomeone = false;
  Map<String, dynamic>? _selectedPromo;

  double _platformFee = 0.0;
  double _deliveryFee = 0.0;
  double _baseDeliveryFee = 0.0;
  double _deliverySurcharge = 0.0;
  double _deliveryDistanceKm = 0.0;
  GeoPoint? _vendorLocation;
  double _walletBalance = 0.0;
  List<Map<String, dynamic>> _savedCards = [];
  String _customerEmail = '';
  String _customerName = 'Customer';
  String _customerPhone = '';
  String _restaurantName = 'MartFood';
  String _restaurantAddress = '';
  String _vendorAvatarUrl = '';
  bool _isLoading = true;

  List<Map<String, dynamic>> _activeCheckoutItems = [];
  String? _vendorId;
  String? _restaurantType;

  String _restaurantNote = '';
  final TextEditingController _restaurantNoteController =
      TextEditingController();

  String _riderNote = '';
  final TextEditingController _riderNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _restaurantNoteController.dispose();
    _riderNoteController.dispose();
    super.dispose();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatCurrency(double value) {
    final formatted = value.toStringAsFixed(0);
    final whole = formatted.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '₦$whole';
  }

  String _generateDeliveryPin() {
    final random = Random();
    final pin = 1000 + random.nextInt(9000);
    return pin.toString();
  }

  Future<void> _loadInitialData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    _customerEmail = user.email ?? '';

    await Future.wait([
      _loadCustomerDetails(user.uid),
      _loadDefaultAddress(user.uid),
      _loadPlatformFee(),
    ]);

    if (widget.checkoutItems != null && widget.checkoutItems!.isNotEmpty) {
      _activeCheckoutItems = widget.checkoutItems!
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _vendorId = _activeCheckoutItems.first['vendorId']?.toString();
      _restaurantName =
          _activeCheckoutItems.first['restaurant']?.toString() ?? 'MartFood';
    } else {
      await _loadWholeCartItems();
    }

    await _resolveVendorDetails();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomerDetails(String userId) async {
    try {
      final customerDoc =
          await _firestore.collection('customers').doc(userId).get();
      if (!customerDoc.exists || customerDoc.data() == null) return;
      final data = customerDoc.data()!;
      _walletBalance = _toDouble(data['balance']);
      _customerName =
          (data['fullName'] ?? data['name'] ?? 'Customer').toString();
      _customerPhone = (data['phone'] ?? data['phoneNumber'] ?? '').toString();
      _customerEmail =
          (data['email'] ?? _auth.currentUser?.email ?? '').toString();
      final cards = data['savedCards'] as List<dynamic>? ?? [];
      _savedCards = cards.map((c) => Map<String, dynamic>.from(c)).toList();
    } catch (e) {
      debugPrint('Error fetching customer details: $e');
    }
  }

  Future<void> _loadDefaultAddress(String userId) async {
    try {
      final addressRef = _firestore
          .collection('customers')
          .doc(userId)
          .collection('addresses');

      final defaultSnap = await addressRef
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (defaultSnap.docs.isNotEmpty) {
        final data = defaultSnap.docs.first.data();
        final addr = {
          ...data,
          'id': defaultSnap.docs.first.id,
        };
        await _checkAndApplyAddress(addr, silentOnSuccess: true);
        return;
      }

      final firstAddress = await addressRef.orderBy('createdAt').limit(1).get();
      if (firstAddress.docs.isNotEmpty) {
        final data = firstAddress.docs.first.data();
        final addr = {
          ...data,
          'id': firstAddress.docs.first.id,
        };
        await _checkAndApplyAddress(addr, silentOnSuccess: true);
      }
    } catch (e) {
      debugPrint('Error fetching default address: $e');
    }
  }

  Future<void> _addNewCard() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final emailToUse = _customerEmail.isNotEmpty ? _customerEmail : (user.email ?? '');

    if (emailToUse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer email is required for card setup.')),
      );
      return;
    }

    // Show the in-app card input bottom sheet (₦50 tokenisation charge)
    final result = await showAddCardBottomSheet(
      context: context,
      email: emailToUse,
      amountInNaira: 50.0,
    );

    if (!mounted) return;
    if (result == null) return; // user cancelled or sheet already showed error

    final authData = result['authorization'] as Map<String, dynamic>?;
    if (authData != null) {
      final newCard = {
        'authorizationCode': authData['authorization_code'],
        'cardType': authData['card_type'],
        'last4': authData['last4'],
        'expMonth': authData['exp_month']?.toString(),
        'expYear': authData['exp_year']?.toString(),
        'brand': authData['brand'],
      };

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(currentUser.uid)
            .update({
          'savedCards': FieldValue.arrayUnion([newCard]),
        });
        await _loadCustomerDetails(currentUser.uid);
      }

      if (mounted && _savedCards.isNotEmpty) {
        final latestCard = _savedCards.last;
        setState(() {
          _selectedPayment = {
            'type': 'card',
            'name': "${latestCard['brand'] ?? 'Card'} (•••• ${latestCard['last4'] ?? '••••'})",
            'card': latestCard,
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New card added and selected successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Card charged but no auth data returned. Try again.')),
        );
      }
    }
  }

  Future<void> _loadPlatformFee() async {
    try {
      final settingsDoc =
          await _firestore.collection('settings').doc('customer_settings').get();
      if (settingsDoc.exists) {
        _platformFee = _toDouble(settingsDoc.data()?['platformFee']);
      }
    } catch (e) {
      debugPrint('Error fetching platform fee: $e');
    }
  }

  Future<void> _loadWholeCartItems() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final cartSnap = await _firestore
          .collection('customers')
          .doc(user.uid)
          .collection('cart')
          .orderBy('addedAt', descending: true)
          .get();

      _activeCheckoutItems = cartSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      if (_activeCheckoutItems.isNotEmpty) {
        _vendorId = _activeCheckoutItems.first['vendorId']?.toString();
        _restaurantName =
            _activeCheckoutItems.first['restaurant']?.toString() ?? 'MartFood';
      }
    } catch (e) {
      debugPrint('Error loading whole cart items: $e');
    }
  }

  Future<void> _resolveVendorDetails() async {
    if (_vendorId == null || _vendorId!.isEmpty) return;

    try {
      final vendorDoc =
          await _firestore.collection('vendors').doc(_vendorId).get();
      if (!vendorDoc.exists || vendorDoc.data() == null) return;

      final data = vendorDoc.data()!;
      final profile = data['businessProfile'] as Map<String, dynamic>?;

      _restaurantName = (data['businessName'] ??
              profile?['businessName'] ??
              profile?['restaurantName'] ??
              data['restaurantName'] ??
              data['vendorName'] ??
              data['fullName'] ??
              _restaurantName)
          .toString();

      _baseDeliveryFee = _toDouble(data['deliveryFee']);
      _restaurantAddress = (data['address'] ?? data['location'] ?? '').toString();
      _restaurantType = (data['restaurantType'] ?? data['vendorType'] ?? 'resturantPosts').toString();

      _vendorAvatarUrl = (data['profilePic'] ??
              data['logoUrl'] ??
              data['vendorLogo'] ??
              data['businessLogo'] ??
              profile?['logoUrl'] ??
              profile?['profilePic'] ??
              profile?['businessLogo'] ??
              '')
          .toString();

      if (_vendorAvatarUrl.isEmpty && _activeCheckoutItems.isNotEmpty) {
        for (final item in _activeCheckoutItems) {
          final img = (item['vendorLogo'] ??
                  item['restaurantImage'] ??
                  item['vendorAvatar'] ??
                  '')
              .toString();
          if (img.isNotEmpty) {
            _vendorAvatarUrl = img;
            break;
          }
        }
      }

      if (profile != null) {
        if (profile['currentvendorLocation'] is GeoPoint) {
          _vendorLocation = profile['currentvendorLocation'] as GeoPoint;
        } else if (profile['vendorLocation'] is GeoPoint) {
          _vendorLocation = profile['vendorLocation'] as GeoPoint;
        }
      }

      if (_vendorLocation == null && data['vendorLocation'] is GeoPoint) {
        _vendorLocation = data['vendorLocation'] as GeoPoint;
      }

      if (_vendorLocation == null && _restaurantAddress.isNotEmpty) {
        final geo = await _geocodeAddress(_restaurantAddress);
        if (geo != null) {
          _vendorLocation = GeoPoint(geo['lat']!, geo['lng']!);
        }
      }

      if (_selectedAddress != null) {
        await _checkAndApplyAddress(_selectedAddress!, silentOnSuccess: true);
      } else {
        _recalculateDeliveryFee();
      }
    } catch (e) {
      debugPrint('Error resolving vendor details: $e');
    }
  }

  /// Geocodes address text to latitude and longitude using Google Geocoding API.
  Future<Map<String, double>?> _geocodeAddress(String addressStr) async {
    final clean = addressStr.trim();
    if (clean.isEmpty) return null;
    const String apiKey = "AIzaSyDUSy4tm9GTFNOCZZ5UXjGnEnPnFl1u2hI";
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(clean)}&key=$apiKey',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final location = results[0]['geometry']?['location'];
          if (location != null) {
            final lat = (location['lat'] as num).toDouble();
            final lng = (location['lng'] as num).toDouble();
            return {'lat': lat, 'lng': lng};
          }
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return null;
  }

  /// Validates if an address is within MartFood service coverage areas (regionally and by vendor distance).
  Future<CoverageCheckResult> _validateAddressCoverage(
      Map<String, dynamic> address) async {
    final addrTitle = (address['title'] ?? '').toString();
    final addrAddress = (address['address'] ?? '').toString();
    final addrStreet = (address['street'] ?? '').toString();
    final addrCity = (address['city'] ?? '').toString();
    final addrState = (address['state'] ?? '').toString();

    final fullAddrStr = [addrAddress, addrStreet, addrCity, addrState, addrTitle]
        .where((s) => s.trim().isNotEmpty && s != 'null')
        .join(', ');
    final addrLower = fullAddrStr.toLowerCase();

    // 1. Fetch enabled coverage regions from settings (states, LGAs, towns)
    List<String> enabledStates = [];
    List<String> enabledLgas = [];
    List<String> enabledTowns = [];

    try {
      final docSnap = await _firestore
          .collection('settings')
          .doc('service_availability')
          .get();
      if (docSnap.exists) {
        final data = docSnap.data() ?? {};
        enabledStates.addAll(List<String>.from(data['enabledStates'] ?? []));
        enabledLgas.addAll(List<String>.from(data['enabledLgas'] ?? []));
        enabledTowns.addAll(List<String>.from(data['enabledTowns'] ?? []));
      }
    } catch (_) {}

    try {
      final sysSnap = await _firestore
          .collection('settings')
          .doc('system_settings')
          .get();
      if (sysSnap.exists) {
        final data = sysSnap.data() ?? {};
        enabledStates.addAll(List<String>.from(data['enabledStates'] ?? []));
        enabledLgas.addAll(List<String>.from(data['enabledLgas'] ?? []));
      }
    } catch (_) {}

    enabledStates = enabledStates.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();
    enabledLgas = enabledLgas.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();
    enabledTowns = enabledTowns.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();

    // If regions are configured, verify that address is in a covered region
    if (enabledStates.isNotEmpty || enabledLgas.isNotEmpty || enabledTowns.isNotEmpty) {
      bool regionalMatch = false;

      for (final town in enabledTowns) {
        if (addrLower.contains(town.toLowerCase())) {
          regionalMatch = true;
          break;
        }
      }

      if (!regionalMatch) {
        for (final lga in enabledLgas) {
          if (addrLower.contains(lga.toLowerCase())) {
            regionalMatch = true;
            break;
          }
        }
      }

      if (!regionalMatch) {
        for (final state in enabledStates) {
          if (addrLower.contains(state.toLowerCase())) {
            regionalMatch = true;
            break;
          }
        }
      }

      if (!regionalMatch) {
        return CoverageCheckResult(
          isWithinCoverage: false,
          errorMessage:
              'The delivery address is out of service coverage so change to an address that service coverage covers.',
        );
      }
    }

    // 2. Resolve coordinates for Customer Address & Vendor
    double? lat = _toDouble(address['latitude']);
    double? lng = _toDouble(address['longitude']);

    if ((lat == 0.0 || lng == 0.0) && fullAddrStr.isNotEmpty) {
      final geocoded = await _geocodeAddress(fullAddrStr);
      if (geocoded != null) {
        lat = geocoded['lat'];
        lng = geocoded['lng'];
      }
    }

    if (_vendorLocation == null && _restaurantAddress.isNotEmpty) {
      final vendorGeo = await _geocodeAddress(_restaurantAddress);
      if (vendorGeo != null) {
        _vendorLocation = GeoPoint(vendorGeo['lat']!, vendorGeo['lng']!);
      }
    }

    // 3. Distance & Vendor Coverage Radius
    double distanceKm = 0.0;
    if (_vendorLocation != null && lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      final meters = Geolocator.distanceBetween(
        _vendorLocation!.latitude,
        _vendorLocation!.longitude,
        lat,
        lng,
      );
      distanceKm = meters / 1000.0;

      await PriceHelper.initialize();
      final maxDist = PriceHelper.maxDeliveryDistance > 0 ? PriceHelper.maxDeliveryDistance : 15.0;

      if (distanceKm > maxDist) {
        return CoverageCheckResult(
          isWithinCoverage: false,
          distanceKm: distanceKm,
          errorMessage:
              'The delivery address is out of service coverage (${distanceKm.toStringAsFixed(1)} km away; max allowed is ${maxDist.toInt()} km) so change to an address that service coverage covers.',
        );
      }
    }

    // 4. Recalculate dynamic delivery fee
    await PriceHelper.initialize();
    final surcharge = PriceHelper.calculateDeliverySurcharge(distanceKm);
    final recalculatedFee = _baseDeliveryFee + surcharge;

    final resolved = Map<String, dynamic>.from(address);
    if (lat != 0.0 && lng != 0.0) {
      resolved['latitude'] = lat;
      resolved['longitude'] = lng;
    }

    return CoverageCheckResult(
      isWithinCoverage: true,
      distanceKm: distanceKm,
      surcharge: surcharge,
      recalculatedFee: recalculatedFee,
      resolvedAddress: resolved,
    );
  }

  /// Verifies service coverage, recalculates fee, and handles error state if out of coverage.
  Future<void> _checkAndApplyAddress(Map<String, dynamic> newAddress,
      {bool silentOnSuccess = false}) async {
    setState(() {
      _isCheckingCoverage = true;
    });

    try {
      final result = await _validateAddressCoverage(newAddress);

      if (!mounted) return;

      if (!result.isWithinCoverage) {
        setState(() {
          _selectedAddress = newAddress;
          _isAddressOutOfCoverage = true;
          _coverageErrorMessage = result.errorMessage ??
              'The delivery address is out of service coverage so change to an address that service coverage covers.';
          _deliveryDistanceKm = result.distanceKm;
          _deliverySurcharge = 0.0;
          _deliveryFee = 0.0;
          _isCheckingCoverage = false;
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 5),
            content: Text(
              _coverageErrorMessage!,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            action: SnackBarAction(
              label: 'Change',
              textColor: Colors.white,
              onPressed: _openDeliverToScreen,
            ),
          ),
        );

        _showOutOfCoverageBottomSheet(newAddress);
      } else {
        setState(() {
          _selectedAddress = result.resolvedAddress ?? newAddress;
          _isAddressOutOfCoverage = false;
          _coverageErrorMessage = null;
          _deliveryDistanceKm = result.distanceKm;
          _deliverySurcharge = result.surcharge;
          _deliveryFee = result.recalculatedFee;
          _isCheckingCoverage = false;
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      debugPrint('Error validating address coverage: $e');
      if (mounted) {
        setState(() {
          _isCheckingCoverage = false;
        });
      }
    }
  }

  /// Navigates to DeliverToScreen and checks address coverage upon return.
  Future<void> _openDeliverToScreen() async {
    final res = await context.push('/checkout/deliver-to');
    if (res is Map<String, dynamic>) {
      await _checkAndApplyAddress(res);
    }
  }

  /// Displays styled Bottom Sheet alerting that address is outside service coverage.
  void _showOutOfCoverageBottomSheet(Map<String, dynamic> addr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    final addrTitle = (addr['title'] ?? 'Address').toString();
    final addrFull = (addr['address'] ?? addr['street'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20.w,
          16.h,
          20.w,
          MediaQuery.of(context).viewInsets.bottom + 28.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.1),
              ),
              child: Icon(
                LucideIcons.mapPinOff,
                color: const Color(0xFFDC2626),
                size: 32.sp,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              'Out of Service Coverage',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            Text(
              _coverageErrorMessage ??
                  'The delivery address is out of service coverage so change to an address that service coverage covers.',
              style: TextStyle(
                color: mutedTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 18.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A1515) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.mapPin,
                    color: const Color(0xFFDC2626),
                    size: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          addrTitle,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          ),
                        ),
                        if (addrFull.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            addrFull,
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: AppTypography.font(AppFontSizes.caption),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _openDeliverToScreen();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 54.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Change Delivery Address',
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(
                'Dismiss',
                style: TextStyle(
                  color: mutedTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _recalculateDeliveryFee() {
    if (_selectedAddress == null) {
      _deliveryDistanceKm = 0.0;
      _deliverySurcharge = 0.0;
      _deliveryFee = _baseDeliveryFee;
      return;
    }

    final lat = _toDouble(_selectedAddress!['latitude']);
    final lng = _toDouble(_selectedAddress!['longitude']);

    if (_vendorLocation != null && lat != 0.0 && lng != 0.0) {
      final meters = Geolocator.distanceBetween(
        _vendorLocation!.latitude,
        _vendorLocation!.longitude,
        lat,
        lng,
      );
      _deliveryDistanceKm = meters / 1000.0;
      _deliverySurcharge = PriceHelper.calculateDeliverySurcharge(_deliveryDistanceKm);
    } else {
      _deliveryDistanceKm = 0.0;
      _deliverySurcharge = 0.0;
    }

    _deliveryFee = _baseDeliveryFee + _deliverySurcharge;
  }

  double get _subtotal => _activeCheckoutItems.fold(
        0.0,
        (acc, item) => acc + (_toDouble(item['price']) * ((item['quantity'] ?? 1) as int)),
      );

  double get _vendorSubtotal => _activeCheckoutItems.fold(
        0.0,
        (acc, item) => acc + (_toDouble(item['basePrice'] ?? item['price']) * ((item['quantity'] ?? 1) as int)),
      );

  double get _discountAmount {
    if (_selectedPromo == null) return 0.0;
    final percent = _toDouble(_selectedPromo!['discountPercentage']);
    final appliedOn = (_selectedPromo!['appliedOn'] ?? 'full_order').toString();

    if (appliedOn == 'delivery_fee') {
      return _deliveryFee * (percent / 100.0);
    }
    return _subtotal * (percent / 100.0);
  }

  double get _totalPrice {
    final sub = _subtotal;
    final del = _deliveryFee;
    final plat = _platformFee;
    final disc = _discountAmount;
    final total = sub + del + plat - disc;
    return total < 0 ? 0.0 : total;
  }

  int get _totalItemCount => _activeCheckoutItems.fold(
        0,
        (acc, item) => acc + ((item['quantity'] ?? 1) as int),
      );

  Future<void> _removePurchasedCartItems(String userId) async {
    final cartRef =
        _firestore.collection('customers').doc(userId).collection('cart');

    for (final item in _activeCheckoutItems) {
      final itemId = item['id']?.toString();
      if (itemId != null && itemId.isNotEmpty) {
        try {
          await cartRef.doc(itemId).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _placeOrder() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to complete checkout.')),
      );
      return;
    }

    if (_activeCheckoutItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your checkout is empty.')),
      );
      return;
    }

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address.')),
      );
      return;
    }

    if (_isAddressOutOfCoverage) {
      _showOutOfCoverageBottomSheet(_selectedAddress!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text(
            _coverageErrorMessage ??
                'The delivery address is out of service coverage so change to an address that service coverage covers.',
          ),
          action: SnackBarAction(
            label: 'Change',
            textColor: Colors.white,
            onPressed: _openDeliverToScreen,
          ),
        ),
      );
      return;
    }

    if (_selectedPayment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Please sign in to place an order.');
      }
      final uid = user.uid;

      final customerDoc = await _firestore.collection('customers').doc(uid).get();
      if (customerDoc.exists) {
        final cData = customerDoc.data() ?? {};
        if (cData['status'] == 'suspended') {
          final reason = cData['suspensionReason'] ?? 'Policy Violation';
          throw Exception('Your account is currently suspended ($reason). Please contact support@martfood.com to appeal.');
        }
      }

      final effectiveVendorId = _vendorId ??
          (_activeCheckoutItems.isNotEmpty
              ? _activeCheckoutItems.first['vendorId']?.toString()
              : null);

      if (effectiveVendorId != null && effectiveVendorId.isNotEmpty) {
        final vendorDoc = await _firestore.collection('vendors').doc(effectiveVendorId).get();
        if (vendorDoc.exists) {
          final vendorData = vendorDoc.data() ?? {};
          final isRestricted = vendorData['isRestricted'] == true;
          final isBanned = vendorData['isBanned'] == true;
          final isSuspended = vendorData['status'] == 'suspended';
          if (isRestricted || isBanned || isSuspended) {
            throw Exception('This vendor is currently suspended and unable to accept new orders. Please try another restaurant.');
          }

          final systemSettingsSnap = await _firestore.collection('settings').doc('system_settings').get();
          if (systemSettingsSnap.exists) {
            final sysData = systemSettingsSnap.data() ?? {};
            final enabledStates = List<String>.from(sysData['enabledStates'] ?? []);
            final enabledLgas = List<String>.from(sysData['enabledLgas'] ?? []);

            final customerAddrObj = _selectedAddress?['address'];
            String customerAddrStr = '';
            if (customerAddrObj is Map) {
              customerAddrStr = (customerAddrObj['address'] ?? customerAddrObj['street'] ?? '').toString();
            } else if (customerAddrObj != null) {
              customerAddrStr = customerAddrObj.toString();
            }

            final vendorAddrObj = vendorData['address'] ?? vendorData['location'];
            String vendorAddrStr = '';
            if (vendorAddrObj is Map) {
              vendorAddrStr = (vendorAddrObj['address'] ?? vendorAddrObj['street'] ?? '').toString();
            } else if (vendorAddrObj != null) {
              vendorAddrStr = vendorAddrObj.toString();
            }

            final combinedAddrStr = '$customerAddrStr $vendorAddrStr';

            if (enabledStates.isNotEmpty || enabledLgas.isNotEmpty) {
              bool matchFound = false;
              final addrLower = combinedAddrStr.toLowerCase();

              for (final lga in enabledLgas) {
                for (final state in enabledStates) {
                  if (addrLower.contains(lga.toLowerCase().trim()) && addrLower.contains(state.toLowerCase().trim())) {
                    matchFound = true;
                    break;
                  }
                }
                if (matchFound) break;
              }

              if (!matchFound) {
                for (final lga in enabledLgas) {
                  if (addrLower.contains(lga.toLowerCase().trim())) {
                    matchFound = true;
                    break;
                  }
                }
              }

              if (!matchFound) {
                for (final state in enabledStates) {
                  if (addrLower.contains(state.toLowerCase().trim())) {
                    matchFound = true;
                    break;
                  }
                }
              }

              if (!matchFound) {
                throw Exception("We're sorry, our services are not available at your delivery location yet.");
              }
            }
          }
        }
      }

      // ── Pre-order Stock Availability Validation ─────────────────────────────
      final List<Map<String, dynamic>> resolvedItemTargets = [];
      final collectionsToCheck = [
        'resturantPosts',
        'grocerytPosts',
        'pharmacytPosts',
        'bakerytPosts'
      ];

      for (final checkoutItem in _activeCheckoutItems) {
        final itemId = checkoutItem['id']?.toString() ?? '';
        final itemTitle = checkoutItem['title']?.toString() ?? 'Item';
        final int reqQuantity = (checkoutItem['quantity'] as num?)?.toInt() ?? 1;

        DocumentSnapshot? foundDoc;
        String? foundCollection;

        for (final coll in collectionsToCheck) {
          if (itemId.isNotEmpty) {
            final docSnap = await _firestore.collection(coll).doc(itemId).get();
            if (docSnap.exists) {
              foundDoc = docSnap;
              foundCollection = coll;
              break;
            }
          }
        }

        if (foundDoc == null) {
          for (final coll in collectionsToCheck) {
            final qSnap = await _firestore
                .collection(coll)
                .where('name', isEqualTo: itemTitle)
                .where('vendorId', isEqualTo: effectiveVendorId)
                .limit(1)
                .get();
            if (qSnap.docs.isNotEmpty) {
              foundDoc = qSnap.docs.first;
              foundCollection = coll;
              break;
            }
          }
        }

        if (foundDoc != null && foundDoc.exists && foundCollection != null) {
          final data = foundDoc.data() as Map<String, dynamic>? ?? {};
          final inStock = data['inStock'] ?? true;
          final stockQty = data['quantity'] as num?;

          if (inStock == false || (stockQty != null && stockQty <= 0)) {
            throw Exception('"$itemTitle" is currently out of stock.');
          }

          if (stockQty != null && stockQty < reqQuantity) {
            throw Exception(
              'Only $stockQty of "$itemTitle" currently available in stock (requested $reqQuantity).',
            );
          }

          resolvedItemTargets.add({
            'collection': foundCollection,
            'docId': foundDoc.id,
            'title': itemTitle,
            'quantityToDeduct': reqQuantity,
            'currentQuantity': stockQty?.toInt(),
          });
        }
      }

      if (_selectedPromo != null) {
        final promoId = _selectedPromo!['id'].toString();

        final customerOrdersSnap = await _firestore
            .collection('orders')
            .where('customerId', isEqualTo: uid)
            .where('promo.id', isEqualTo: promoId)
            .get();
        final customerUsageCount = customerOrdersSnap.docs.length;

        final totalOrdersSnap = await _firestore
            .collection('orders')
            .where('promo.id', isEqualTo: promoId)
            .get();
        final totalUsageCount = totalOrdersSnap.docs.length;

        final promoDoc = await _firestore.collection('promos').doc(promoId).get();
        if (promoDoc.exists) {
          final promoData = promoDoc.data()!;
          final customerLimit = promoData['usagePerCustomer'];
          final availabilityLimit = promoData['offerAvailability'];

          if (customerLimit != 'unlimited' && customerLimit != null) {
            final limitVal = int.tryParse(customerLimit.toString()) ?? 1;
            if (customerUsageCount >= limitVal) {
              throw Exception('You have reached the maximum usage limit for this promo code.');
            }
          }

          if (availabilityLimit != 'unlimited' && availabilityLimit != null) {
            final limitVal = int.tryParse(availabilityLimit.toString()) ?? 0;
            if (totalUsageCount >= limitVal) {
              throw Exception('This promo code is no longer available (fully redeemed).');
            }
          }
        }
      }

      final orderTotal = _totalPrice;
      final paymentType = _selectedPayment!['type']?.toString() ?? 'wallet';
      final custRef = _firestore.collection('customers').doc(uid);

      if (paymentType == 'wallet') {
        if (_walletBalance < orderTotal) {
          throw Exception('Insufficient wallet balance. Please top up.');
        }

        await _firestore.runTransaction((tx) async {
          final snap = await tx.get(custRef);
          final currentBal = _toDouble(snap.data()?['balance']);
          if (currentBal < orderTotal) {
            throw Exception('Insufficient wallet balance. Please top up.');
          }
          tx.update(custRef, {'balance': currentBal - orderTotal});
        });

        await custRef.collection('transactions').add({
          'title': 'Order Checkout Payment',
          'amount': orderTotal,
          'type': 'Orders',
          'isExpense': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (paymentType == 'card') {
        final card = _selectedPayment!['card'] as Map<String, dynamic>?;
        final authCode = card?['authorizationCode']?.toString();

        if (authCode == null || authCode.isEmpty) {
          throw Exception('Saved card details are incomplete.');
        }

        final paySuccess = await PaystackService.chargeSavedCard(
          email: _customerEmail,
          amountInNaira: orderTotal,
          authorizationCode: authCode,
        );

        if (!paySuccess) {
          throw Exception(
            'Card charge failed. Please try another card or wallet.',
          );
        }

        await custRef.collection('transactions').add({
          'title': 'Order Checkout Payment (Card)',
          'amount': orderTotal,
          'type': 'Orders',
          'isExpense': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (paymentType == 'bank') {
        final bankAcc = await PaystackService.createBankTransferAccount(
          email: _customerEmail,
          amountInNaira: orderTotal,
        );

        if (!mounted) return;

        if (bankAcc == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not generate bank transfer account. Please enable "Pay with Transfer" on your Paystack dashboard or try another payment method.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
          throw Exception('Paystack bank transfer account generation failed.');
        }

        final bool? paymentVerified = await _showBankTransferBottomSheet(
          bankName: bankAcc['bank_name'] ?? 'N/A',
          accountName: bankAcc['account_name'] ?? 'N/A',
          accountNumber: bankAcc['account_number'] ?? 'N/A',
          amount: orderTotal,
          reference: bankAcc['reference'] ?? '',
        );

        if (paymentVerified != true) {
          throw Exception('Bank transfer payment cancelled or failed.');
        }

        await custRef.collection('transactions').add({
          'title': 'Order Checkout Payment (Bank Transfer)',
          'amount': orderTotal,
          'type': 'Orders',
          'isExpense': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final orderRef = _firestore.collection('orders').doc();
      final deliveryPin = _generateDeliveryPin();
      final String initialStatus = (paymentType == 'someone') ? 'awaiting_payment' : 'pending';
      final String paymentStatus = (paymentType == 'someone') ? 'unpaid' : 'paid';
      String? paymentToken;
      DateTime? expiresAt;

      if (paymentType == 'someone') {
        paymentToken = 'ps_${const Uuid().v4().replaceAll('-', '')}';
        expiresAt = DateTime.now().add(const Duration(hours: 24));
        await _firestore.collection('payment_sessions').doc(paymentToken).set({
          'id': paymentToken,
          'token': paymentToken,
          'orderId': orderRef.id,
          'customerId': uid,
          'customerName': _customerName,
          'customerEmail': _customerEmail,
          'payerName': '',
          'payerEmail': '',
          'relationship': 'Anyone',
          'amount': orderTotal,
          'status': 'active',
          'hideOrderDetails': _hideOrderDetailsForSomeone,
          'expiresAt': Timestamp.fromDate(expiresAt),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await orderRef.set({
        'orderNumber': orderRef.id,
        'customerId': uid,
        'customerName': _customerName,
        'customerEmail': _customerEmail,
        'customerPhone': _customerPhone,
        'items': _activeCheckoutItems.map((item) {
          return {
            'id': item['id'],
            'title': item['title'],
            'price': _toDouble(item['price']),
            'basePrice': _toDouble(item['basePrice'] ?? item['price']),
            'quantity': item['quantity'] ?? 1,
            'imageUrl': item['imageUrl'],
            'selectedChoices':
                List<Map<String, dynamic>>.from(item['selectedChoices'] ?? []),
            'selectedAddOns':
                List<Map<String, dynamic>>.from(item['selectedAddOns'] ?? []),
          };
        }).toList(),
        'subtotal': _subtotal,
        'vendorSubtotal': _vendorSubtotal,
        'deliveryFee': _deliveryFee,
        'platformFee': _platformFee,
        'discount': _discountAmount,
        'total': orderTotal,
        'promo': _selectedPromo == null
            ? null
            : {
                'id': _selectedPromo!['id'],
                'discountPercentage': _selectedPromo!['discountPercentage'],
                'appliedOn': _selectedPromo!['appliedOn'],
                'description': _selectedPromo!['description'] ?? _selectedPromo!['code'],
              },
        'paymentMethod': _selectedPayment,
        if (paymentToken != null) 'paymentToken': paymentToken,
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
        'hideOrderDetails': _hideOrderDetailsForSomeone,
        'deliveryAddress': _selectedAddress,
        'restaurantNote': _restaurantNote,
        'riderNote': _riderNote,
        'vendorId': effectiveVendorId,
        'restaurantName': _restaurantName,
        'restaurantAddress': _restaurantAddress,
        if (_restaurantType != null) 'restaurantType': _restaurantType,
        'deliveryPin': deliveryPin,
        'status': initialStatus,
        'paymentStatus': paymentStatus,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── Dispatch Push Notification to Vendor ──────────────────────────────
      if (effectiveVendorId != null && effectiveVendorId.isNotEmpty) {
        final orderNum = orderRef.id.length >= 6 ? orderRef.id.substring(0, 6).toUpperCase() : orderRef.id;
        NotificationService.sendPushToVendor(
          vendorId: effectiveVendorId,
          title: 'New Order Received! 🛍️',
          body: 'Order #$orderNum (${_activeCheckoutItems.length} items - ₦${orderTotal.toStringAsFixed(0)}) placed by $_customerName',
          data: {
            'orderId': orderRef.id,
            'type': 'order',
          },
        );
      }

      // ── Decrement Stock Inventory for Purchased Items ───────────────────────
      for (final target in resolvedItemTargets) {
        try {
          final coll = target['collection'] as String;
          final docId = target['docId'] as String;
          final deductQty = target['quantityToDeduct'] as int;
          final curQty = target['currentQuantity'] as int?;

          final postRef = _firestore.collection(coll).doc(docId);
          if (curQty != null) {
            final int newQty = (curQty - deductQty) > 0 ? (curQty - deductQty) : 0;
            await postRef.update({
              'quantity': newQty,
              'stockQuantity': newQty,
              if (newQty <= 0) 'inStock': false,
            });
          } else {
            await postRef.update({
              'quantity': FieldValue.increment(-deductQty),
              'stockQuantity': FieldValue.increment(-deductQty),
            });
          }
        } catch (err) {
          debugPrint('Error decrementing stock for item: $err');
        }
      }

      try {
        final emailSubject = 'Order Confirmed - #${orderRef.id}';
        final emailHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Order Confirmed - MartFood</title>
</head>
<body style="font-family: sans-serif; background-color: #f8fafc; padding: 20px; color: #334155; line-height: 1.6;">
  <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; padding: 0; border: 1px solid #e2e8f0; overflow: hidden;">
    <div style="background-color: #7C3AED; padding: 24px; text-align: center;">
      <h2 style="color: #ffffff; margin: 0; font-size: 22px;">Order Confirmed! 🍔</h2>
    </div>
    <div style="padding: 24px;">
      <p>Hi $_customerName,</p>
      <p>Your order at <strong>$_restaurantName</strong> has been received successfully.</p>
      <div style="background-color: #F5F3FF; padding: 16px; border-radius: 8px; margin: 20px 0; border: 1px solid #C4B5FD;">
        <h3 style="margin-top: 0; font-size: 16px; color: #0f172a;">Order Details</h3>
        <p style="margin: 4px 0;"><strong>Order ID:</strong> #${orderRef.id}</p>
        <p style="margin: 4px 0;"><strong>Restaurant:</strong> $_restaurantName</p>
        <p style="margin: 4px 0;"><strong>Total Paid:</strong> ₦${orderTotal.toStringAsFixed(2)}</p>
        <p style="margin: 4px 0;"><strong>Status:</strong> ${initialStatus == 'awaiting_payment' ? 'Awaiting payment from sponsor' : 'Pending vendor confirmation'}</p>
      </div>
      <p>You can track the progress of your order in the app real-time.</p>
      <br/>
      <p>Best Regards,</p>
      <p><strong>The MartFood Team</strong></p>
    </div>
    <div style="background-color: #f8fafc; padding: 16px; text-align: center; border-top: 1px solid #e2e8f0; font-size: 12px; color: #94a3b8;">
      &copy; 2026 MartFood Technologies. All rights reserved.
    </div>
  </div>
</body>
</html>
''';

        NotificationService.sendEmail(
          to: _customerEmail,
          subject: emailSubject,
          htmlContent: emailHtml,
        );
      } catch (_) {}

      await _removePurchasedCartItems(uid);

      if (!mounted) return;
      setState(() => _isLoading = false);
      if (paymentType == 'someone') {
        context.go('/orders?payForMeSuccess=true&orderId=${orderRef.id}&token=${paymentToken ?? ''}');
      } else {
        context.go('/orders?showSuccess=true');
      }
    } catch (e) {
      debugPrint('Error placing order: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _showRestaurantNoteBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    _restaurantNoteController.text = _restaurantNote;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20.w,
            16.h,
            20.w,
            MediaQuery.of(context).viewInsets.bottom + 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Leave a note for the restaurant',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'This will be shared with $_restaurantName along with your order.',
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightInputFill,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: TextField(
                  controller: _restaurantNoteController,
                  maxLines: 5,
                  minLines: 4,
                  maxLength: 150,
                  onChanged: (_) => setSheetState(() {}),
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Extra spicy, Please. I like it with extra mayo too',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_restaurantNoteController.text.length}/150',
                  style: TextStyle(
                    color: mutedTextColor,
                    fontSize: AppTypography.font(AppFontSizes.caption),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _restaurantNote = _restaurantNoteController.text.trim();
                    });
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    elevation: 0,
                  ),
                  child: Text(
                    'Add Note',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRiderNoteBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    _riderNoteController.text = _riderNote;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20.w,
            16.h,
            20.w,
            MediaQuery.of(context).viewInsets.bottom + 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Leave a note for the rider',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Delivery landmarks or instructions for the rider.',
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightInputFill,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: TextField(
                  controller: _riderNoteController,
                  maxLines: 5,
                  minLines: 4,
                  maxLength: 150,
                  onChanged: (_) => setSheetState(() {}),
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Please ring the bell or leave at the front desk',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_riderNoteController.text.length}/150',
                  style: TextStyle(
                    color: mutedTextColor,
                    fontSize: AppTypography.font(AppFontSizes.caption),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _riderNote = _riderNoteController.text.trim();
                    });
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    elevation: 0,
                  ),
                  child: Text(
                    'Add Note',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOptionTile({
    required String title,
    String? subtext,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color surfaceColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required Color purpleColor,
    required Color borderColor,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isSelected ? purpleColor : borderColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: primaryTextColor,
                size: 22.sp,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtext != null && subtext.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subtext,
                        style: TextStyle(
                          color: mutedTextColor,
                          fontSize: AppTypography.font(AppFontSizes.caption),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? purpleColor : Colors.grey[400]!,
                    width: isSelected ? 6.w : 1.5.w,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChoosePaymentMethodBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    String tempSelectedType = _selectedPayment?['type']?.toString() ?? 'wallet';
    String? tempSelectedCardCode = _selectedPayment?['card']?['authorizationCode']?.toString();
    bool tempHideOrderDetails = _hideOrderDetailsForSomeone;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20.w,
            16.h,
            20.w,
            MediaQuery.of(context).viewInsets.bottom + 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Choose Payment Method',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                "Select how you'd like to pay for this order.",
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16.h),

              // Wallet Option
              _buildPaymentOptionTile(
                title: 'MartFood Wallet',
                subtext: 'Balance: ${_formatCurrency(_walletBalance)}',
                icon: LucideIcons.wallet,
                isSelected: tempSelectedType == 'wallet',
                onTap: () {
                  setSheetState(() {
                    tempSelectedType = 'wallet';
                    tempSelectedCardCode = null;
                  });
                },
                isDark: isDark,
                surfaceColor: surfaceColor,
                primaryTextColor: primaryTextColor,
                mutedTextColor: mutedTextColor,
                purpleColor: purpleColor,
                borderColor: borderColor,
              ),

              // Bank Transfer Option
              _buildPaymentOptionTile(
                title: 'Bank Transfer',
                subtext: 'Instant bank transfer via Paystack',
                icon: LucideIcons.landmark,
                isSelected: tempSelectedType == 'bank',
                onTap: () {
                  setSheetState(() {
                    tempSelectedType = 'bank';
                    tempSelectedCardCode = null;
                  });
                },
                isDark: isDark,
                surfaceColor: surfaceColor,
                primaryTextColor: primaryTextColor,
                mutedTextColor: mutedTextColor,
                purpleColor: purpleColor,
                borderColor: borderColor,
              ),

              // Have Someone Pay Option
              _buildPaymentOptionTile(
                title: 'Have Someone Pay',
                subtext: 'Share payment request link with a friend or sponsor',
                icon: LucideIcons.users,
                isSelected: tempSelectedType == 'someone',
                onTap: () {
                  setSheetState(() {
                    tempSelectedType = 'someone';
                    tempSelectedCardCode = null;
                  });
                },
                isDark: isDark,
                surfaceColor: surfaceColor,
                primaryTextColor: primaryTextColor,
                mutedTextColor: mutedTextColor,
                purpleColor: purpleColor,
                borderColor: borderColor,
              ),

              // Hide Order Details Toggle when Have Someone Pay is selected
              if (tempSelectedType == 'someone') ...[
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightInputFill,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: purpleColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          tempHideOrderDetails ? LucideIcons.eyeOff : LucideIcons.eye,
                          color: purpleColor,
                          size: 18.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hide order details',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Conceal food items and choices from the payment link',
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: AppTypography.font(11),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: tempHideOrderDetails,
                        activeTrackColor: purpleColor,
                        onChanged: (val) {
                          setSheetState(() {
                            tempHideOrderDetails = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 8.h),
              Text(
                'Debit / Credit Card',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10.h),

              // Saved Cards List
              if (_savedCards.isNotEmpty) ...[
                ..._savedCards.map((card) {
                  final authCode = card['authorizationCode']?.toString() ?? '';
                  final isCardSelected =
                      tempSelectedType == 'card' && tempSelectedCardCode == authCode;
                  final brand = card['brand']?.toString() ?? 'Card';
                  final last4 = card['last4']?.toString() ?? '••••';

                  return _buildPaymentOptionTile(
                    title: '$brand (•••• $last4)',
                    subtext: 'Saved Card',
                    icon: LucideIcons.creditCard,
                    isSelected: isCardSelected,
                    onTap: () {
                      setSheetState(() {
                        tempSelectedType = 'card';
                        tempSelectedCardCode = authCode;
                      });
                    },
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    primaryTextColor: primaryTextColor,
                    mutedTextColor: mutedTextColor,
                    purpleColor: purpleColor,
                    borderColor: borderColor,
                  );
                }),
              ],

              // Add New Card Option
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _addNewCard();
                },
                icon: Icon(LucideIcons.plus, size: 18.sp, color: purpleColor),
                label: Text(
                  _savedCards.isEmpty ? 'Add Debit / Credit Card' : 'Add a New Card',
                  style: TextStyle(
                    color: purpleColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48.h),
                  side: BorderSide(color: purpleColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
              ),

              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (tempSelectedType == 'wallet') {
                      setState(() {
                        _selectedPayment = {
                          'type': 'wallet',
                          'name': 'MartFood Wallet',
                        };
                      });
                    } else if (tempSelectedType == 'bank') {
                      setState(() {
                        _selectedPayment = {
                          'type': 'bank',
                          'name': 'Bank Transfer',
                        };
                      });
                    } else if (tempSelectedType == 'someone') {
                      setState(() {
                        _selectedPayment = {
                          'type': 'someone',
                          'name': 'Have Someone Pay',
                        };
                        _hideOrderDetailsForSomeone = tempHideOrderDetails;
                      });
                    } else if (tempSelectedType == 'card') {
                      final selectedCard = _savedCards.firstWhere(
                        (c) => c['authorizationCode']?.toString() == tempSelectedCardCode,
                        orElse: () => _savedCards.isNotEmpty ? _savedCards.first : {},
                      );
                      if (selectedCard.isNotEmpty) {
                        setState(() {
                          _selectedPayment = {
                            'type': 'card',
                            'name':
                                "${selectedCard['brand'] ?? 'Card'} (•••• ${selectedCard['last4'] ?? '••••'})",
                            'card': selectedCard,
                          };
                        });
                      } else {
                        Navigator.pop(sheetContext);
                        _addNewCard();
                        return;
                      }
                    }
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    elevation: 0,
                  ),
                  child: Text(
                    'Choose Method',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showBankTransferBottomSheet({
    required String bankName,
    required String accountName,
    required String accountNumber,
    required double amount,
    required String reference,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final cardBgColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF3F4F6);

    bool isVerifying = false;
    String? verificationError;

    return showModalBottomSheet<bool>(
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
                  'Bank Transfer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(24),
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Complete your payment by transferring the exact amount to the account below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    fontWeight: FontWeight.w500,
                    color: mutedTextColor,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 24.h),

                // Account Details Box
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(20.r),
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
                      SizedBox(height: 16.h),
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
                      SizedBox(height: 16.h),
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
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: accountNumber));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Account number copied to clipboard!'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: Icon(
                                LucideIcons.copy,
                                size: 18.sp,
                                color: purpleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
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
                        _formatCurrency(amount),
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),

                // Verification Error Banner
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
                            verificationError ?? '',
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

                // Primary Button: I've Made the Transfer
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
                              Navigator.pop(sheetContext, true);
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

                // Secondary Action: Cancel Payment
                TextButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  icon: Icon(
                    LucideIcons.xCircle,
                    size: 20.sp,
                    color: mutedTextColor,
                  ),
                  label: Text(
                    'Cancel Payment',
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

  void _duplicatePackItem(int index) {
    if (index >= 0 && index < _activeCheckoutItems.length) {
      final copy = Map<String, dynamic>.from(_activeCheckoutItems[index]);
      setState(() {
        _activeCheckoutItems.insert(index + 1, copy);
      });
    }
  }

  void _deletePackItem(int index) {
    if (index >= 0 && index < _activeCheckoutItems.length) {
      setState(() {
        _activeCheckoutItems.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              LucideIcons.arrowLeft,
              color: purpleColor,
              size: 22.sp,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: purpleColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.all(8.w),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                LucideIcons.arrowLeft,
                color: isDark ? Colors.white : purpleColor,
                size: 18.sp,
              ),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Text(
          'Order Review',
          style: TextStyle(
            color: purpleColor,
            fontSize: AppTypography.font(AppFontSizes.bodyLarge),
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: purpleColor,
          indicatorWeight: 2.5,
          labelColor: purpleColor,
          unselectedLabelColor: mutedTextColor,
          labelStyle: TextStyle(
            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Order'),
            Tab(text: 'Payment'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderTab(
            isDark: isDark,
            surfaceColor: surfaceColor,
            primaryTextColor: primaryTextColor,
            mutedTextColor: mutedTextColor,
            purpleColor: purpleColor,
            borderColor: borderColor,
          ),
          _buildPaymentTab(
            isDark: isDark,
            surfaceColor: surfaceColor,
            primaryTextColor: primaryTextColor,
            mutedTextColor: mutedTextColor,
            purpleColor: purpleColor,
            borderColor: borderColor,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTab({
    required bool isDark,
    required Color surfaceColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required Color purpleColor,
    required Color borderColor,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary Title & Vendor Row
                Text(
                  'Order Summary',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    ClipOval(
                      child: _vendorAvatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _vendorAvatarUrl,
                              width: 32.w,
                              height: 32.w,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 32.w,
                                height: 32.w,
                                color: purpleColor.withValues(alpha: 0.12),
                                child: Icon(
                                  Icons.storefront_rounded,
                                  color: purpleColor,
                                  size: 18.sp,
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 32.w,
                                height: 32.w,
                                color: purpleColor.withValues(alpha: 0.12),
                                child: Icon(
                                  Icons.storefront_rounded,
                                  color: purpleColor,
                                  size: 18.sp,
                                ),
                              ),
                            )
                          : Container(
                              width: 32.w,
                              height: 32.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: purpleColor.withValues(alpha: 0.12),
                              ),
                              child: Icon(
                                Icons.storefront_rounded,
                                color: purpleColor,
                                size: 18.sp,
                              ),
                            ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        _restaurantName,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {},
                      child: Row(
                        children: [
                          Text(
                            'View details',
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: AppTypography.font(AppFontSizes.caption),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            LucideIcons.chevronDown,
                            color: mutedTextColor,
                            size: 16.sp,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                // List of Packs / Items
                if (_activeCheckoutItems.isEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: Center(
                      child: Text(
                        'No items in checkout.',
                        style: TextStyle(
                          color: mutedTextColor,
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  ...List.generate(_activeCheckoutItems.length, (index) {
                    final item = _activeCheckoutItems[index];
                    final packTitle = 'Pack ${index + 1}';
                    final qty = (item['quantity'] ?? 1) as int;
                    final price = _toDouble(item['price']);
                    final itemChoices = List<dynamic>.from(item['selectedChoices'] ?? []);
                    final itemAddOns = List<dynamic>.from(item['selectedAddOns'] ?? []);

                    return Container(
                      margin: EdgeInsets.only(bottom: 16.h),
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pack Header with duplicate and delete buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                packTitle,
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: AppTypography.font(
                                      AppFontSizes.bodyMedium),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _duplicatePackItem(index),
                                    child: Container(
                                      width: 34.w,
                                      height: 34.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[100],
                                      ),
                                      child: Icon(
                                        LucideIcons.copy,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                        size: 16.sp,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  GestureDetector(
                                    onTap: () => _deletePackItem(index),
                                    child: Container(
                                      width: 34.w,
                                      height: 34.w,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFFFEBEE),
                                      ),
                                      child: Icon(
                                        LucideIcons.trash2,
                                        color: const Color(0xFFEF5350),
                                        size: 16.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 14.h),

                          // Item Info Row
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16.r),
                                child: (item['imageUrl'] != null &&
                                        item['imageUrl'].toString().isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: item['imageUrl'].toString(),
                                        width: 72.w,
                                        height: 72.w,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            _buildFoodFallback(purpleColor, isDark),
                                      )
                                    : _buildFoodFallback(purpleColor, isDark),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (item['title'] ?? item['name'] ?? 'Food Item')
                                          .toString(),
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: AppTypography.font(
                                            AppFontSizes.bodyMedium),
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      _formatCurrency(price),
                                      style: TextStyle(
                                        color: mutedTextColor,
                                        fontSize: AppTypography.font(
                                            AppFontSizes.bodySmall),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (itemChoices.isNotEmpty) ...[
                                      SizedBox(height: 3.h),
                                      Text(
                                        itemChoices
                                            .map((c) => c['label'] ?? '')
                                            .where((l) => l.toString().isNotEmpty)
                                            .join(' • '),
                                        style: TextStyle(
                                          color: mutedTextColor,
                                          fontSize: AppTypography.font(AppFontSizes.caption),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (itemAddOns.isNotEmpty) ...[
                                      SizedBox(height: 2.h),
                                      Text(
                                        'Add-ons: ${itemAddOns.map((a) => ((a['quantity'] as num?)?.toInt() ?? 1) > 1 ? '${a['name'] ?? a['title']} (x${a['quantity']})' : '${a['name'] ?? a['title']}').where((n) => n.isNotEmpty).join(', ')}',
                                        style: TextStyle(
                                          color: mutedTextColor,
                                          fontSize: AppTypography.font(AppFontSizes.caption),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Circular Quantity Stepper
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (qty > 1) {
                                          item['quantity'] = qty - 1;
                                        } else {
                                          _activeCheckoutItems.removeAt(index);
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 28.w,
                                      height: 28.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[100],
                                      ),
                                      child: Icon(
                                        LucideIcons.minus,
                                        color: primaryTextColor,
                                        size: 14.sp,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 10.w),
                                    child: Text(
                                      '$qty',
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: AppTypography.font(
                                            AppFontSizes.bodyMedium),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        item['quantity'] = qty + 1;
                                      });
                                    },
                                    child: Container(
                                      width: 28.w,
                                      height: 28.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[100],
                                      ),
                                      child: Icon(
                                        LucideIcons.plus,
                                        color: primaryTextColor,
                                        size: 14.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                SizedBox(height: 12.h),
                Divider(color: borderColor, height: 1),
                SizedBox(height: 16.h),

                // Leave a note for the restaurant Section
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leave a note for the restaurant',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: AppTypography.font(
                                  AppFontSizes.bodyMedium),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _restaurantNote.isNotEmpty
                                ? _restaurantNote
                                : 'Optional message to the vendor',
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize:
                                  AppTypography.font(AppFontSizes.bodySmall),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _showRestaurantNoteBottomSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : const Color(0xFFF3F4F6),
                        foregroundColor: primaryTextColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        padding: EdgeInsets.symmetric(
                            horizontal: 20.w, vertical: 8.h),
                        elevation: 0,
                      ),
                      child: Text(
                        _restaurantNote.isNotEmpty ? 'Edit' : 'Add',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Sticky Bottom Action Button: Proceed Payment
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _tabController.animateTo(1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                elevation: 0,
              ),
              child: Text(
                'Proceed payment of ${_formatCurrency(_totalPrice)}',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTab({
    required bool isDark,
    required Color surfaceColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required Color purpleColor,
    required Color borderColor,
  }) {
    final addressText = _selectedAddress != null
        ? (_selectedAddress!['address']?.toString() ??
            _selectedAddress!['street']?.toString() ??
            'Selected Address')
        : 'Select delivery address';

    final paymentName = _selectedPayment?['name']?.toString() ?? 'MartFood Wallet';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Deliver to Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Deliver to',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_isCheckingCoverage)
                      Row(
                        children: [
                          SizedBox(
                            width: 13.w,
                            height: 13.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: purpleColor,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Checking coverage...',
                            style: TextStyle(
                              color: purpleColor,
                              fontSize: AppTypography.font(AppFontSizes.caption),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else if (_isAddressOutOfCoverage)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'Out of Coverage',
                          style: TextStyle(
                            color: const Color(0xFFDC2626),
                            fontSize: AppTypography.font(10),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else if (_deliveryDistanceKm > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'In Coverage · ${_deliveryDistanceKm.toStringAsFixed(1)} km',
                          style: TextStyle(
                            color: const Color(0xFF15803D),
                            fontSize: AppTypography.font(10),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12.h),
                InkWell(
                  onTap: _openDeliverToScreen,
                  borderRadius: BorderRadius.circular(16.r),
                  child: Row(
                    children: [
                      Icon(
                        _isAddressOutOfCoverage
                            ? LucideIcons.mapPinOff
                            : LucideIcons.mapPin,
                        color: _isAddressOutOfCoverage
                            ? const Color(0xFFDC2626)
                            : purpleColor,
                        size: 22.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          addressText,
                          style: TextStyle(
                            color: _isAddressOutOfCoverage
                                ? const Color(0xFFDC2626)
                                : primaryTextColor,
                            fontSize:
                                AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronRight,
                        color: mutedTextColor,
                        size: 20.sp,
                      ),
                    ],
                  ),
                ),
                if (_isAddressOutOfCoverage) ...[
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A1515) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.alertCircle,
                          color: const Color(0xFFDC2626),
                          size: 18.sp,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery Address Out of Coverage',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                _coverageErrorMessage ??
                                    'The delivery address is out of service coverage so change to an address that service coverage covers.',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C),
                                  fontSize: AppTypography.font(AppFontSizes.caption),
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        InkWell(
                          onTap: _openDeliverToScreen,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: purpleColor,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              'Change',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AppTypography.font(AppFontSizes.caption),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 16.h),
                Divider(color: borderColor, height: 1),
                SizedBox(height: 16.h),

                // Leave a note for the rider Section
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leave a note for the rider',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: AppTypography.font(
                                  AppFontSizes.bodyMedium),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _riderNote.isNotEmpty
                                ? _riderNote
                                : 'Delivery landmarks or instructions',
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize:
                                  AppTypography.font(AppFontSizes.bodySmall),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _showRiderNoteBottomSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : const Color(0xFFF3F4F6),
                        foregroundColor: primaryTextColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        padding: EdgeInsets.symmetric(
                            horizontal: 20.w, vertical: 8.h),
                        elevation: 0,
                      ),
                      child: Text(
                        _riderNote.isNotEmpty ? 'Edit' : 'Add',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Divider(color: borderColor, height: 1),
                SizedBox(height: 16.h),

                // Payment Method Card
                InkWell(
                  onTap: _showChoosePaymentMethodBottomSheet,
                  borderRadius: BorderRadius.circular(16.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.creditCard,
                          color: primaryTextColor,
                          size: 22.sp,
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Method',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: AppTypography.font(
                                      AppFontSizes.bodyMedium),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (paymentName.isNotEmpty) ...[
                                SizedBox(height: 2.h),
                                Text(
                                  paymentName,
                                  style: TextStyle(
                                    color: mutedTextColor,
                                    fontSize: AppTypography.font(
                                        AppFontSizes.caption),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          color: mutedTextColor,
                          size: 20.sp,
                        ),
                      ],
                    ),
                  ),
                ),

                // Privacy Toggle when Have Someone Pay is active
                if (_selectedPayment?['type'] == 'someone') ...[
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.lightInputFill,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: purpleColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _hideOrderDetailsForSomeone ? LucideIcons.eyeOff : LucideIcons.eye,
                            color: purpleColor,
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hide order details',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Conceal food items and choices from the payment link',
                                style: TextStyle(
                                  color: mutedTextColor,
                                  fontSize: AppTypography.font(11),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _hideOrderDetailsForSomeone,
                          activeTrackColor: purpleColor,
                          onChanged: (val) {
                            setState(() {
                              _hideOrderDetailsForSomeone = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 16.h),
                Divider(color: borderColor, height: 1),
                SizedBox(height: 20.h),

                // Payment Summary Section
                Text(
                  'Payment Summary',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 16.h),

                // Special Offers & Promo Banner
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPromo != null
                                  ? '${_selectedPromo!['discountPercentage'] ?? 0}% discount applied'
                                  : 'discount available',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize:
                                    AppTypography.font(AppFontSizes.caption),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Special Offers & Promo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AppTypography.font(
                                    AppFontSizes.bodyMedium),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAB308),
                                borderRadius: BorderRadius.circular(999.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.wine_bar_rounded,
                                    color: Colors.black87,
                                    size: 14.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    _selectedPromo != null
                                        ? (_selectedPromo!['description'] ??
                                                _selectedPromo!['code'] ??
                                                'Promo Applied')
                                            .toString()
                                        : 'Select a promo or special offer',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: AppTypography.font(
                                          AppFontSizes.caption),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final res = await context.push('/special_offers');
                          if (res is Map<String, dynamic>) {
                            setState(() {
                              _selectedPromo = res;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 18.w, vertical: 8.h),
                          elevation: 0,
                        ),
                        child: Text(
                          _selectedPromo != null ? 'Change' : 'Add',
                          style: TextStyle(
                            fontSize:
                                AppTypography.font(AppFontSizes.bodySmall),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),

                // Fee Breakdown Lines
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sub-total ($_totalItemCount items)',
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatCurrency(_subtotal),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Fee',
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _isAddressOutOfCoverage
                          ? 'Out of coverage'
                          : _formatCurrency(_deliveryFee),
                      style: TextStyle(
                        color: _isAddressOutOfCoverage
                            ? const Color(0xFFDC2626)
                            : primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Platform Fee',
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatCurrency(_platformFee),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (_discountAmount > 0) ...[
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Promo Discount (${_selectedPromo?['code'] ?? 'Promo'})',
                        style: TextStyle(
                          color: const Color(0xFF16A34A),
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '-${_formatCurrency(_discountAmount)}',
                        style: TextStyle(
                          color: const Color(0xFF16A34A),
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _formatCurrency(_totalPrice),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Sticky Bottom Action Button: Place Order
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_isAddressOutOfCoverage
                      ? () => _showOutOfCoverageBottomSheet(_selectedAddress ?? {})
                      : _placeOrder),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAddressOutOfCoverage
                    ? const Color(0xFFDC2626)
                    : purpleColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _isAddressOutOfCoverage
                          ? 'Change Address (Out of Coverage)'
                          : 'Place Order',
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodFallback(Color purpleColor, bool isDark) {
    return Container(
      width: 72.w,
      height: 72.w,
      color: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Icon(
        Icons.fastfood_rounded,
        color: purpleColor,
        size: 28.sp,
      ),
    );
  }
}
