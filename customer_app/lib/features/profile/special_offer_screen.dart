import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SpecialOfferScreen extends StatefulWidget {
  final String? vendorId;
  final String? restaurantType;

  const SpecialOfferScreen({
    super.key,
    this.vendorId,
    this.restaurantType,
  });

  @override
  State<SpecialOfferScreen> createState() => _SpecialOfferScreenState();
}

class _SpecialOfferScreenState extends State<SpecialOfferScreen> {
  int _selectedIndex = 0;
  late final Stream<QuerySnapshot> _promosStream;
  final Map<String, Future<Map<String, int>>> _usagesCache = {};
  bool _isValidating = false;

  Future<Map<String, int>> _getPromoUsages(String promoId) {
    return _usagesCache.putIfAbsent(promoId, () async {
      final user = FirebaseAuth.instance.currentUser;
      int customerCount = 0;
      if (user != null) {
        final snap = await FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user.uid)
            .where('promo.id', isEqualTo: promoId)
            .get();
        customerCount = snap.docs.length;
      }
      final totalSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where('promo.id', isEqualTo: promoId)
          .get();
      final totalCount = totalSnap.docs.length;
      return {
        'customer': customerCount,
        'total': totalCount,
      };
    });
  }

  @override
  void initState() {
    super.initState();
    _promosStream = FirebaseFirestore.instance
        .collection('promos')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextColor),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Special Offers & Promo',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _promosStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: purpleColor),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final now = DateTime.now();

          // Filter out expired promos or those not matching vendor/restaurantType scope
          final promos = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).where((promo) {
            // Guard: isActive flag (Firestore query already filters, but belt-and-braces)
            if (promo['isActive'] == false) return false;

            // Check active start date if specified
            if (promo['startDate'] != null &&
                promo['startDate'].toString().isNotEmpty) {
              try {
                final start = DateTime.parse(promo['startDate']);
                if (start.isAfter(now)) return false;
              } catch (_) {}
            }

            // Check expiry date if specified
            if (promo['endDate'] != null && promo['endDate'].toString().isNotEmpty) {
              try {
                final end = DateTime.parse(promo['endDate']);
                if (end.isBefore(now)) return false;
              } catch (_) {}
            }

            // Check restaurantType scope
            final scopeType = promo['restaurantType'] ?? 'all';
            if (scopeType != 'all' && widget.restaurantType != null) {
              if (scopeType.toString().toLowerCase() != widget.restaurantType!.toLowerCase()) {
                return false;
              }
            }

            // Check vendor scope
            final scopeVendor = promo['vendorId'] ?? 'all';
            if (scopeVendor != 'all' && widget.vendorId != null) {
              if (scopeVendor.toString() != widget.vendorId) {
                return false;
              }
            }

            return true;
          }).toList();

          if (promos.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72.w,
                      height: 72.w,
                      decoration: BoxDecoration(
                        color: purpleColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(22.r),
                      ),
                      child: Icon(
                        Icons.percent,
                        color: purpleColor,
                        size: 30.sp,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'No active discounts',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'There are no promo offers available for this order right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_selectedIndex >= promos.length) {
            _selectedIndex = 0;
          }

          return SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
                    children: [
                      Text(
                        'Available promos',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Select one offer to apply to this order.',
                        style: TextStyle(
                          color: mutedTextColor,
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      ...List.generate(promos.length, (index) {
                        final promo = promos[index];
                        final isSelected = _selectedIndex == index;
                        final title = '${promo['discountPercentage']}% OFF';
                        final description = promo['description'] ?? 'Special Promo';
                        final imageUrl = promo['imageUrl'] ?? '';
                        final appliedOn = promo['appliedOn'] == 'delivery_fee'
                            ? 'Applied on Delivery Fee'
                            : 'Applied on Total Order';

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == promos.length - 1 ? 0 : 16.h,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() => _selectedIndex = index),
                              borderRadius: BorderRadius.circular(24.r),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(24.r),
                                  border: Border.all(
                                    color: isSelected
                                        ? purpleColor
                                        : borderColor,
                                    width: isSelected ? 1.6 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24.r),
                                      ),
                                      child: imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              width: double.infinity,
                                              height: 170.h,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  _promoImagePlaceholder(purpleColor),
                                            )
                                          : _promoImagePlaceholder(purpleColor),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(18.w),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        title,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: AppTypography.font(
                                                            AppFontSizes.headlineSmall,
                                                          ),
                                                          color: primaryTextColor,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      Container(
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: 10.w,
                                                          vertical: 5.h,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: purpleColor
                                                              .withValues(alpha: 0.10),
                                                          borderRadius:
                                                              BorderRadius.circular(999.r),
                                                        ),
                                                        child: Text(
                                                          'Selected',
                                                          style: TextStyle(
                                                            color: purpleColor,
                                                            fontSize: AppTypography.font(
                                                              AppFontSizes.caption,
                                                            ),
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                SizedBox(height: 8.h),
                                                Text(
                                                  description,
                                                  style: TextStyle(
                                                    color: mutedTextColor,
                                                    fontSize: AppTypography.font(
                                                      AppFontSizes.bodyMedium,
                                                    ),
                                                    fontWeight: FontWeight.w500,
                                                    height: 1.4,
                                                  ),
                                                ),
                                                SizedBox(height: 12.h),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 12.w,
                                                    vertical: 7.h,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: purpleColor
                                                        .withValues(alpha: 0.10),
                                                    borderRadius:
                                                        BorderRadius.circular(999.r),
                                                  ),
                                                  child: Text(
                                                    appliedOn,
                                                    style: TextStyle(
                                                      color: purpleColor,
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: AppTypography.font(
                                                        AppFontSizes.caption,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                FutureBuilder<Map<String, int>>(
                                                  future: _getPromoUsages(promo['id'].toString()),
                                                  builder: (context, usageSnap) {
                                                    if (!usageSnap.hasData) return const SizedBox.shrink();
                                                    final usage = usageSnap.data!;
                                                    final customerLimit = promo['usagePerCustomer'];
                                                    final availabilityLimit = promo['offerAvailability'];

                                                    bool isCustomerLimitReached = false;
                                                    bool isAvailabilityLimitReached = false;

                                                    if (customerLimit != 'unlimited' && customerLimit != null) {
                                                      final limitVal = int.tryParse(customerLimit.toString()) ?? 1;
                                                      if (usage['customer']! >= limitVal) {
                                                        isCustomerLimitReached = true;
                                                      }
                                                    }

                                                    if (availabilityLimit != 'unlimited' && availabilityLimit != null) {
                                                      final limitVal = int.tryParse(availabilityLimit.toString()) ?? 0;
                                                      if (usage['total']! >= limitVal) {
                                                        isAvailabilityLimitReached = true;
                                                      }
                                                    }

                                                    if (isCustomerLimitReached) {
                                                      return Padding(
                                                        padding: EdgeInsets.only(top: 8.h),
                                                        child: Text(
                                                          'Limit reached for this account',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize: AppTypography.font(AppFontSizes.caption),
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                    }

                                                    if (isAvailabilityLimitReached) {
                                                      return Padding(
                                                        padding: EdgeInsets.only(top: 8.h),
                                                        child: Text(
                                                          'Fully redeemed (no longer available)',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize: AppTypography.font(AppFontSizes.caption),
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                    }

                                                    return const SizedBox.shrink();
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Icon(
                                            isSelected
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                            color: isSelected
                                                ? purpleColor
                                                : AppTheme.hintColorFor(isDark),
                                            size: 22.sp,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(
                      top: BorderSide(
                        color: borderColor,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: ElevatedButton(
                      onPressed: _isValidating ? null : () async {
                        if (promos.isEmpty) return;
                        final selectedPromo = promos[_selectedIndex];
                        final promoId = selectedPromo['id'].toString();

                        setState(() => _isValidating = true);

                        try {
                          final usage = await _getPromoUsages(promoId);
                          if (!context.mounted) return;

                          final customerLimit = selectedPromo['usagePerCustomer'];
                          final availabilityLimit = selectedPromo['offerAvailability'];

                          if (customerLimit != 'unlimited' && customerLimit != null) {
                            final limitVal = int.tryParse(customerLimit.toString()) ?? 1;
                            if (usage['customer']! >= limitVal) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('You have reached the maximum usage limit for this promo code.')),
                              );
                              return;
                            }
                          }

                          if (availabilityLimit != 'unlimited' && availabilityLimit != null) {
                            final limitVal = int.tryParse(availabilityLimit.toString()) ?? 0;
                            if (usage['total']! >= limitVal) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('This promo code is no longer available (fully redeemed).')),
                              );
                              return;
                            }
                          }

                          context.pop(selectedPromo);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error validating promo: $e')),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isValidating = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 58.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isValidating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Apply Promo',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                              ),
                            ),
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

  Widget _promoImagePlaceholder(Color purpleColor) {
    return Container(
      width: double.infinity,
      height: 170.h,
      color: purpleColor.withValues(alpha: 0.10),
      child: Icon(Icons.percent, color: purpleColor, size: 40.sp),
    );
  }
}
