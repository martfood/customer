import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Displays up to 2 red rectangle promo badges for a vendor:
/// - Bike icon + `Free` when an active admin promo has `appliedOn == 'delivery_fee'` and `discountPercentage == 100`
/// - `'-XX% whole menu'` for the highest active admin `full_order` promo
/// - `'-XX% select items'` for the highest vendor `resturantPosts` promo (if no whole-menu promo)
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
        bool hasFreeDelivery = false;
        int maxWholeMenuPercent = 0;

        if (promoSnap.hasData) {
          for (final doc in promoSnap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final targetVendorId = data['vendorId']?.toString() ?? '';
            if (targetVendorId != 'all' && targetVendorId != vendorId) continue;

            final appliedOn =
                (data['appliedOn'] ?? 'full_order').toString().toLowerCase();
            final rawVal = data['discountPercentage'] ??
                data['discountValue'] ??
                data['discountPercent'] ??
                0;
            final pct = (rawVal is num) ? rawVal.round() : 0;

            if (appliedOn == 'delivery_fee') {
              if (pct >= 100) hasFreeDelivery = true;
            } else {
              if (pct > maxWholeMenuPercent) maxWholeMenuPercent = pct;
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('resturantPosts')
              .where('vendorId', isEqualTo: vendorId)
              .where('isPromotion', isEqualTo: true)
              .snapshots(),
          builder: (context, postSnap) {
            int maxSelectItemsPercent = 0;
            if (postSnap.hasData) {
              for (final doc in postSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['isAvailable'] == false) continue;
                final price =
                    ((data['price'] ?? data['basePrice']) as num?)?.toDouble() ??
                        0;
                final promoPrice =
                    (data['promoPrice'] as num?)?.toDouble() ?? 0;
                if (promoPrice > 0 && price > promoPrice) {
                  final pct = (((price - promoPrice) / price) * 100).round();
                  if (pct > maxSelectItemsPercent) maxSelectItemsPercent = pct;
                }
              }
            }

            final List<Widget> badges = [];
            if (hasFreeDelivery) {
              badges.add(_buildFreeDeliveryBadge());
            }
            if (maxWholeMenuPercent > 0) {
              badges.add(_buildTextBadge('-$maxWholeMenuPercent% whole menu'));
            } else if (maxSelectItemsPercent > 0) {
              badges.add(_buildTextBadge('-$maxSelectItemsPercent% select items'));
            }

            if (badges.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: margin ?? EdgeInsets.zero,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: badges.take(2).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFreeDeliveryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_bike, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Free',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBadge(String label) {
    return Container(
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
