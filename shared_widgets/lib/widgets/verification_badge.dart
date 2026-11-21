import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'verification_badge_sheet.dart';

class VerificationBadge extends StatelessWidget {
  final Map<String, dynamic> vendorData;
  final double size;
  final VoidCallback? onTap;
  final bool interactive;

  const VerificationBadge({
    super.key,
    required this.vendorData,
    this.size = 18.0,
    this.onTap,
    this.interactive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bpComplete =
        vendorData['businessProfileComplete']?.toString() == 'true';

    final physicalVerification = vendorData['physicalVerification'];
    final physicalVerified = (physicalVerification is Map)
        ? physicalVerification['status']?.toString() == 'verified'
        : false;

    final docComplete =
        vendorData['verificationDocumentsComplete']?.toString() == 'true';

    Widget iconWidget;

    // Prioritize Tier 3 (Gold) > Tier 2 (Green) > Tier 1 (Grey)
    if (physicalVerified) {
      iconWidget = Icon(
        Icons.verified_rounded,
        color: const Color(0xFFFFB300), // Gold
        size: size,
      );
    } else if (docComplete) {
      iconWidget = Icon(
        Icons.verified_rounded,
        color: const Color(0xFF34C759), // Green
        size: size,
      );
    } else if (bpComplete) {
      iconWidget = Icon(
        Icons.verified_rounded,
        color: const Color(0xFF8E8E93), // Grey
        size: size,
      );
    } else {
      return const SizedBox.shrink();
    }

    if (onTap != null || interactive) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ??
            () => showVerificationBadgeBottomSheet(context, vendorData),
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

class VendorVerificationBadge extends StatelessWidget {
  final String vendorId;
  final Map<String, dynamic> fallbackData;
  final double size;

  const VendorVerificationBadge({
    super.key,
    required this.vendorId,
    required this.fallbackData,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    if (vendorId.isEmpty) {
      return _buildFallback();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists) {
          final vendorData =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final bpComplete =
              vendorData['businessProfileComplete']?.toString() == 'true';
          final physicalVerification = vendorData['physicalVerification'];
          final physicalVerified = (physicalVerification is Map)
              ? physicalVerification['status']?.toString() == 'verified'
              : false;
          final docComplete =
              vendorData['verificationDocumentsComplete']?.toString() == 'true';

          if (physicalVerified || docComplete || bpComplete) {
            return VerificationBadge(vendorData: vendorData, size: size);
          }

          final isVerified = vendorData['isVerified'] == true ||
              vendorData['isVerified']?.toString() == 'true' ||
              vendorData['isVendorVerified'] == true;
          if (isVerified) {
            return Icon(Icons.verified_rounded,
                color: const Color(0xFF34C759), size: size);
          }
        }
        return _buildFallback();
      },
    );
  }

  Widget _buildFallback() {
    final vendorMap = fallbackData['vendorData'] is Map
        ? Map<String, dynamic>.from(fallbackData['vendorData'])
        : fallbackData;
    final bpComplete =
        vendorMap['businessProfileComplete']?.toString() == 'true';
    final physicalVerification = vendorMap['physicalVerification'];
    final physicalVerified = (physicalVerification is Map)
        ? physicalVerification['status']?.toString() == 'verified'
        : false;
    final docComplete =
        vendorMap['verificationDocumentsComplete']?.toString() == 'true';

    if (physicalVerified || docComplete || bpComplete) {
      return VerificationBadge(vendorData: vendorMap, size: size);
    }

    return Icon(Icons.verified_rounded,
        color: const Color(0xFF34C759), size: size);
  }
}
