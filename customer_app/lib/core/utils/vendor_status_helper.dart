import 'package:cloud_firestore/cloud_firestore.dart';

class VendorStatusHelper {
  /// Evaluates whether a vendor is currently open based on Firestore fields
  /// (isOpen, isStoreOpen, storeStatus) and operating hours.
  static bool isStoreOpen(Map<String, dynamic>? data) {
    if (data == null) return true;

    // Direct toggle checks
    if (data['isOpen'] != null) {
      final val = data['isOpen'];
      if (val == false || val == 'false') return false;
    }
    if (data['isStoreOpen'] != null) {
      final val = data['isStoreOpen'];
      if (val == false || val == 'false') return false;
    }
    if (data['storeStatus'] != null) {
      if (data['storeStatus'].toString().toLowerCase() == 'closed') return false;
    }

    // Operating hours check
    final operatingHours = data['operatingHours'] as Map<String, dynamic>?;
    if (operatingHours != null) {
      final now = DateTime.now();
      const weekdayKeys = {
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
        7: 'Sun',
      };
      final dayKey = weekdayKeys[now.weekday];
      if (dayKey != null) {
        final dayConfig = operatingHours[dayKey] as Map<String, dynamic>?;
        if (dayConfig != null) {
          if (dayConfig['closed'] == true || dayConfig['closed'] == 'true') {
            return false;
          }
          final String? openStr = dayConfig['open'] as String?;
          final String? closeStr = dayConfig['close'] as String?;
          if (openStr != null &&
              openStr.isNotEmpty &&
              closeStr != null &&
              closeStr.isNotEmpty) {
            try {
              final openParts = openStr.split(':');
              final closeParts = closeStr.split(':');
              if (openParts.length >= 2 && closeParts.length >= 2) {
                final openMin =
                    int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
                final closeMin =
                    int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
                final nowMin = now.hour * 60 + now.minute;
                if (closeMin >= openMin) {
                  return nowMin >= openMin && nowMin <= closeMin;
                } else {
                  return nowMin >= openMin || nowMin <= closeMin;
                }
              }
            } catch (_) {}
          }
        }
      }
    }

    return true;
  }

  /// Streams real-time open status of a vendor by ID or business name.
  static Stream<bool> streamVendorOpenStatus({
    String? vendorId,
    String? vendorName,
  }) {
    final firestore = FirebaseFirestore.instance;
    if (vendorId != null && vendorId.isNotEmpty) {
      return firestore
          .collection('vendors')
          .doc(vendorId)
          .snapshots()
          .map((snap) => isStoreOpen(snap.data()));
    }

    if (vendorName != null && vendorName.isNotEmpty) {
      return firestore
          .collection('vendors')
          .where('businessName', isEqualTo: vendorName)
          .limit(1)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) return true;
        return isStoreOpen(snap.docs.first.data());
      });
    }

    return Stream.value(true);
  }
}
