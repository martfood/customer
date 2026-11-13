import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Displays a red rectangle promo badge for a vendor:
/// - `'-XX% whole menu'` when an active admin promo applies to all or this vendor
/// - `'-XX% select items'` for the highest vendor product promo discount
class VendorPromoBadge extends StatelessWidget {
  final String vendorId;
  final EdgeInsetsGeometry? margin;

  const VendorPromoBadge({
    super.key,
    required this.vendorId,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (vendorId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('promos')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, promoSnap) {
        int maxAdminPercent = 0;

        if (promoSnap.hasData) {
          for (final doc in promoSnap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final applyToAll = data['applyToAll'] == true;
            final vendorIds = (data['vendorIds'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const <String>[];
            if (!applyToAll && !vendorIds.contains(vendorId)) continue;

            final discountType =
                (data['discountType'] ?? 'percentage').toString().toLowerCase();
            if (discountType == 'percentage' || discountType == 'percent') {
              final rawVal = data['discountValue'] ??
                  data['discountPercent'] ??
                  data['percentage'] ??
                  0;
              final pct = (rawVal is num) ? rawVal.round() : 0;
              if (pct > maxAdminPercent) maxAdminPercent = pct;
            }
          }
        }

        if (maxAdminPercent > 0) {
          return _buildBadge('-$maxAdminPercent% whole menu');
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('vendors')
              .doc(vendorId)
              .collection('products')
              .snapshots(),
          builder: (context, prodSnap) {
            if (!prodSnap.hasData) return const SizedBox.shrink();

            int maxItemPercent = 0;
            for (final doc in prodSnap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['isAvailable'] == false) continue;
              final price = (data['price'] as num?)?.toDouble() ?? 0;
              final promoPrice = (data['promoPrice'] as num?)?.toDouble() ?? 0;
              if (promoPrice > 0 && price > promoPrice) {
                final pct = (((price - promoPrice) / price) * 100).round();
                if (pct > maxItemPercent) maxItemPercent = pct;
              }
            }

            if (maxItemPercent <= 0) return const SizedBox.shrink();
            return _buildBadge('-$maxItemPercent% select items');
          },
        );
      },
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

