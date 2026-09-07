import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final Map<String, dynamic> vendorData;
  final double size;

  const VerificationBadge({
    super.key,
    required this.vendorData,
    this.size = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final bpComplete = vendorData['businessProfileComplete']?.toString() == 'true';
    
    final physicalVerification = vendorData['physicalVerification'];
    final physicalVerified = (physicalVerification is Map)
        ? physicalVerification['status']?.toString() == 'verified'
        : false;
    
    final docComplete = vendorData['verificationDocumentsComplete']?.toString() == 'true';

    // Prioritize Tier 3 (Gold) > Tier 2 (Green) > Tier 1 (Grey)
    if (physicalVerified) {
      return Icon(
        Icons.verified_rounded,
        color: const Color(0xFFFFB300), // Gold
        size: size,
      );
    } else if (docComplete) {
      return Icon(
        Icons.verified_rounded,
        color: const Color(0xFF34C759), // Green
        size: size,
      );
    } else if (bpComplete) {
      return Icon(
        Icons.verified_rounded,
        color: const Color(0xFF8E8E93), // Grey
        size: size,
      );
    }
    
    return const SizedBox.shrink();
  }
}
