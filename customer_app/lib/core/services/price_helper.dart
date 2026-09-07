import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PriceHelper {
  static double restaurantMarkup = 15.0;
  static double groceryMarkup = 5.0;
  static double bakeryMarkup = 8.0;
  static double pharmacyMarkup = 3.0;

  // Dynamic delivery fee tiers
  static double deliveryFreeZoneKm = 2.0;
  static double deliveryTier1MaxKm = 5.0;
  static double deliveryTier2MaxKm = 10.0;
  static double deliveryRateTier1 = 50.0;   // ₦/km from freeZone to tier1Max
  static double deliveryRateTier2 = 75.0;   // ₦/km from tier1Max to tier2Max
  static double deliveryRateTier3 = 100.0;  // ₦/km beyond tier2Max
  static double maxDeliveryDistance = 15.0; // max range to filter out-of-range vendors

  // Location Cache
  static Position? _currentPosition;
  static String? _currentAddress;
  static String? _fullAddress;

  static final LocationUpdateNotifier locationNotifier = LocationUpdateNotifier();

  static Position? get currentPosition => _currentPosition;
  static set currentPosition(Position? val) {
    _currentPosition = val;
    locationNotifier.notify();
  }

  static String? get currentAddress => _currentAddress;
  static set currentAddress(String? val) {
    _currentAddress = val;
    // Notify listeners so screens update their address text/coverage check
    locationNotifier.notify();
  }

  static String? get fullAddress => _fullAddress;
  static set fullAddress(String? val) {
    _fullAddress = val;
    locationNotifier.notify();
  }



  static Future<void> preFetchLocation() async {
    try {
      // 1. Try to fetch default address from firestore if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snap = await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .collection('addresses')
            .get();

        if (snap.docs.isNotEmpty) {
          final defaultIdx = snap.docs.indexWhere((doc) => doc.data()['isDefault'] == true);
          final defaultDoc = defaultIdx >= 0 ? snap.docs[defaultIdx] : snap.docs.first;
          final data = defaultDoc.data();
          final addrStr = (data['address'] ?? '').toString();
          final titleStr = (data['title'] ?? '').toString();
          final double? lat = data['latitude'] != null ? (data['latitude'] as num).toDouble() : null;
          final double? lng = data['longitude'] != null ? (data['longitude'] as num).toDouble() : null;

          if (addrStr.isNotEmpty) {
            _currentAddress = titleStr;
            _fullAddress = addrStr;
            if (lat != null && lng != null) {
              currentPosition = Position(
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
            } else {
              await _geocodeAddressBackground(addrStr);
            }
            return; // Successfully loaded saved address, bypass GPS!
          }
        }
      }

      // 2. Fallback to GPS location if no default address is found/logged in
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        currentPosition = lastKnown;
        _reverseGeocodeBackground(lastKnown.latitude, lastKnown.longitude);
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      );
      currentPosition = position;
      _reverseGeocodeBackground(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error pre-fetching location: $e');
    }
  }

  static Future<void> _geocodeAddressBackground(String addressStr) async {
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
          currentPosition = Position(
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
        }
      }
    } catch (e) {
      debugPrint('Background geocoding error: $e');
    }
  }

  static Future<void> _reverseGeocodeBackground(double latitude, double longitude) async {
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
          currentAddress = shortAddress;
          fullAddress = formattedAddress;
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
  }

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('settings')
          .doc('customer_settings')
          .get();

      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null) {
          restaurantMarkup = _toDouble(data['restaurantMarkup']) ?? restaurantMarkup;
          groceryMarkup = _toDouble(data['groceryMarkup']) ?? groceryMarkup;
          bakeryMarkup = _toDouble(data['bakeryMarkup']) ?? bakeryMarkup;
          pharmacyMarkup = _toDouble(data['pharmacyMarkup']) ?? pharmacyMarkup;

          deliveryFreeZoneKm = _toDouble(data['deliveryFreeZoneKm']) ?? deliveryFreeZoneKm;
          deliveryTier1MaxKm = _toDouble(data['deliveryTier1MaxKm']) ?? deliveryTier1MaxKm;
          deliveryTier2MaxKm = _toDouble(data['deliveryTier2MaxKm']) ?? deliveryTier2MaxKm;
          deliveryRateTier1 = _toDouble(data['deliveryRateTier1']) ?? deliveryRateTier1;
          deliveryRateTier2 = _toDouble(data['deliveryRateTier2']) ?? deliveryRateTier2;
          deliveryRateTier3 = _toDouble(data['deliveryRateTier3']) ?? deliveryRateTier3;
          maxDeliveryDistance = _toDouble(data['maxDeliveryDistance']) ?? maxDeliveryDistance;
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint("Error initializing PriceHelper: $e");
    }
  }

  /// Forces a re-fetch of settings from Firestore (useful after admin changes).
  static Future<void> refresh() async {
    _isInitialized = false;
    await initialize();
  }

  static double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  static double getMarkupForCategory(String? categoryOrCollection) {
    if (categoryOrCollection == null) return 0.0;
    
    final name = categoryOrCollection.toLowerCase();
    
    if (name.contains('restaurant') || name.contains('resturant')) {
      return restaurantMarkup;
    }
    if (name.contains('grocery') || name.contains('groceries')) {
      return groceryMarkup;
    }
    if (name.contains('bakery') || name.contains('bakeries')) {
      return bakeryMarkup;
    }
    if (name.contains('pharmacy') || name.contains('pharmacies')) {
      return pharmacyMarkup;
    }
    
    return 0.0;
  }

  /// Calculates marked-up price rounded up to the nearest 100
  static double applyMarkup(double basePrice, String? categoryOrCollection) {
    if (basePrice <= 0) return 0.0;
    final markup = getMarkupForCategory(categoryOrCollection);
    if (markup <= 0) return basePrice;
    
    final inflated = basePrice * (1 + (markup / 100.0));
    // Round up to nearest 100
    final rounded = (inflated / 100.0).ceil() * 100.0;
    return rounded;
  }

  /// Calculates the distance-based delivery surcharge in ₦.
  /// Uses tiered pricing configured by admin in CustomerSettingsPage.
  ///
  /// Example (defaults): 
  ///   0–2 km → ₦0 | 2–5 km → ₦50/km | 5–10 km → ₦75/km | >10 km → ₦100/km
  static double calculateDeliverySurcharge(double distanceKm) {
    if (distanceKm <= deliveryFreeZoneKm) return 0.0;

    double surcharge = 0.0;

    // Tier 1: freeZone → tier1Max
    if (distanceKm > deliveryFreeZoneKm) {
      final tier1Distance = (distanceKm.clamp(deliveryFreeZoneKm, deliveryTier1MaxKm)) - deliveryFreeZoneKm;
      surcharge += tier1Distance * deliveryRateTier1;
    }

    // Tier 2: tier1Max → tier2Max
    if (distanceKm > deliveryTier1MaxKm) {
      final tier2Distance = (distanceKm.clamp(deliveryTier1MaxKm, deliveryTier2MaxKm)) - deliveryTier1MaxKm;
      surcharge += tier2Distance * deliveryRateTier2;
    }

    // Tier 3: beyond tier2Max
    if (distanceKm > deliveryTier2MaxKm) {
      final tier3Distance = distanceKm - deliveryTier2MaxKm;
      surcharge += tier3Distance * deliveryRateTier3;
    }

    return surcharge;
  }

  /// Returns the total dynamic delivery fee: vendor base fee + distance surcharge.
  /// [baseFee]: The vendor's configured base delivery fee.
  /// [distanceKm]: Straight-line distance from vendor to customer in kilometers.
  static double calculateDynamicDeliveryFee(double baseFee, double distanceKm) {
    final surcharge = calculateDeliverySurcharge(distanceKm);
    return baseFee + surcharge;
  }

  /// Returns only the surcharge component as a formatted string breakdown.
  /// e.g. "₦150 (3.0 km × ₦50/km)"
  static String describeSurcharge(double distanceKm) {
    final surcharge = calculateDeliverySurcharge(distanceKm);
    if (surcharge <= 0) return 'Free';
    final rounded = surcharge.toStringAsFixed(0);
    final dist = distanceKm.toStringAsFixed(1);
    return '₦$rounded ($dist km)';
  }

  /// Returns the corresponding distance tier label for UI badges
  static String getDistanceTierLabel(double distanceKm) {
    if (distanceKm < 2.0) {
      return 'Nearby (< 2km)';
    } else if (distanceKm <= 5.0) {
      return 'Short Distance (2–5km)';
    } else {
      return 'Longer Distance (> 5km)';
    }
  }
}

class LocationUpdateNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

