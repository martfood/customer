import 'package:flutter/material.dart';
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
