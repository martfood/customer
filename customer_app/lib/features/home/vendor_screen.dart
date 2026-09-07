import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_widgets/widgets/skeleton_loader.dart';
import 'package:shared_widgets/widgets/verification_badge.dart';
import 'package:shared_widgets/widgets/food_card_horizontal.dart';
import '../../core/services/price_helper.dart';
import 'vendor_ratings_screen.dart';

class VendorScreen extends StatefulWidget {
  final String vendorId;
  const VendorScreen({super.key, required this.vendorId});

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  int _selectedTab = 0;
  late Stream<DocumentSnapshot> _vendorStream;
  Stream<QuerySnapshot>? _postsStream;
  String? _cachedCategory;
  String? _cachedCollectionName;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _vendorStream = FirebaseFirestore.instance
        .collection('vendors')
        .doc(widget.vendorId)
        .snapshots();
    _loadCustomerPosition();
  }

  Future<void> _loadCustomerPosition() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      if (mounted) setState(() => _currentPosition = pos);
    } catch (_) {}
  }

  bool _isVendorOpen(Map<String, dynamic>? operatingHours) {
    if (operatingHours == null) return true;
    final now = DateTime.now();
    final weekday = now.weekday;

    const weekdayKeys = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    final dayKey = weekdayKeys[weekday];
    if (dayKey == null) return true;

    final dayConfig = operatingHours[dayKey] as Map<String, dynamic>?;
    if (dayConfig == null) return true;

    final bool isClosedToday = dayConfig['closed'] == true;
    if (isClosedToday) return false;

    final String? openStr = dayConfig['open'] as String?;
    final String? closeStr = dayConfig['close'] as String?;
    if (openStr == null ||
        openStr.isEmpty ||
        closeStr == null ||
        closeStr.isEmpty) {
      return true;
    }

    try {
      final openParts = openStr.split(':');
      final closeParts = closeStr.split(':');

      if (openParts.length < 2 || closeParts.length < 2) return true;

      final openHour = int.parse(openParts[0]);
      final openMin = int.parse(openParts[1]);
      final closeHour = int.parse(closeParts[0]);
      final closeMin = int.parse(closeParts[1]);

      final openMinutes = openHour * 60 + openMin;
      final closeMinutes = closeHour * 60 + closeMin;
      final nowMinutes = now.hour * 60 + now.minute;

      if (closeMinutes >= openMinutes) {
        return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
      } else {
        return nowMinutes >= openMinutes || nowMinutes <= closeMinutes;
      }
    } catch (e) {
      debugPrint("Error parsing operating hours: $e");
      return true;
    }
  }

  String _getTodayOperatingHoursText(Map<String, dynamic>? operatingHours) {
    if (operatingHours == null) return 'Open 24/7';
    final now = DateTime.now();
    final weekday = now.weekday;

    const weekdayKeys = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    final dayKey = weekdayKeys[weekday];
    if (dayKey == null) return 'Open today';

    final dayConfig = operatingHours[dayKey] as Map<String, dynamic>?;
    if (dayConfig == null) return 'Open today';

    final bool isClosedToday = dayConfig['closed'] == true;
    if (isClosedToday) return 'Closed today';

    final String? openStr = dayConfig['open'] as String?;
    final String? closeStr = dayConfig['close'] as String?;
    if (openStr == null ||
        openStr.isEmpty ||
        closeStr == null ||
        closeStr.isEmpty) {
      return 'Open today';
    }

    return 'Open till $closeStr • Mon - Sat';
  }

  String _fmt(double price) {
    final s = price
        .toInt()
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '₦$s';
  }

  String _getCollectionName(String? category) {
    if (category == 'Restaurant') return 'resturantPosts';
    if (category == 'Pharmacy') return 'pharmacytPosts';
    if (category == 'Grocery') return 'grocerytPosts';
    if (category == 'Bakery') return 'bakerytPosts';
    return 'resturantPosts';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkSurface : Colors.white;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final cardBackgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return StreamBuilder<DocumentSnapshot>(
      stream: _vendorStream,
      builder: (context, vendorSnapshot) {
        if (vendorSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: backgroundColor,
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 220.h,
                  pinned: true,
                  backgroundColor: backgroundColor,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: SkeletonLoader(
                        width: double.infinity, height: 220.h, borderRadius: 0),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(
                            width: 200.w, height: 26.h, borderRadius: 4.r),
                        SizedBox(height: 10.h),
                        SkeletonLoader(
                            width: 150.w, height: 14.h, borderRadius: 4.r),
                        SizedBox(height: 20.h),
                        SkeletonLoader(
                            width: double.infinity,
                            height: 80.h,
                            borderRadius: 16.r),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!vendorSnapshot.hasData || !vendorSnapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Store profile not found.')),
          );
        }

        final vendorData = vendorSnapshot.data!.data() as Map<String, dynamic>;
        final profile = vendorData['businessProfile'] as Map<String, dynamic>?;
        final physicalVerification = vendorData['physicalVerification'];
        final physicalStatus = (physicalVerification is Map)
            ? (physicalVerification['status']?.toString() ?? 'pending')
            : 'pending';
        final name = profile?['businessName'] ?? 'Store';
        final tagline = profile?['tagline'] ?? '';
        final category = profile?['category'] ?? 'Restaurant';
        final coverImageUrl =
            profile?['coverImageUrl'] ?? profile?['logoUrl'] ?? '';
        final deliveryFeeVal = vendorData['deliveryFee'] ?? 0;
        final baseFee =
            (deliveryFeeVal is num) ? deliveryFeeVal.toDouble() : 0.0;
        final prepTime = vendorData['preparationTime'] ??
            vendorData['prepTime'] ??
            '22 - 32 min';

        final geoPoint = profile?['currentvendorLocation'] as GeoPoint?;
        double distanceKm = 0.0;
        if (_currentPosition != null && geoPoint != null) {
          distanceKm = Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                geoPoint.latitude,
                geoPoint.longitude,
              ) /
              1000.0;
        }
        final formattedFee = baseFee == 0 ? 'Free' : _fmt(baseFee);

        final isStoreOpen = _isVendorOpen(
            vendorData['operatingHours'] as Map<String, dynamic>?);

        final bpComplete =
            vendorData['businessProfileComplete']?.toString() == 'true';
        final docComplete =
            vendorData['verificationDocumentsComplete']?.toString() == 'true';
        String? verificationTier;
        if (physicalStatus == 'verified') {
          verificationTier = 'gold';
        } else if (docComplete) {
          verificationTier = 'standard';
        } else if (bpComplete) {
          verificationTier = 'basic';
        }

        if (_postsStream == null || _cachedCategory != category) {
          _cachedCategory = category;
          final collectionName = _getCollectionName(category);
          _cachedCollectionName = collectionName;
          _postsStream = FirebaseFirestore.instance
              .collection(collectionName)
              .where('vendorId', isEqualTo: widget.vendorId)
              .snapshots();
        }

        return Scaffold(
          backgroundColor: backgroundColor,
          bottomNavigationBar: StreamBuilder<QuerySnapshot>(
            stream: FirebaseAuth.instance.currentUser != null
                ? FirebaseFirestore.instance
                    .collection('customers')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('cart')
                    .snapshots()
                : null,
            builder: (context, cartSnapshot) {
              final cartDocs = cartSnapshot.data?.docs ?? [];
              if (cartDocs.isEmpty) return const SizedBox.shrink();

              double totalCartSubtotal = 0.0;
              for (var d in cartDocs) {
                final data = d.data() as Map<String, dynamic>;
                final p = (data['price'] ?? 0.0) as num;
                final q = (data['quantity'] ?? 1) as num;
                totalCartSubtotal += (p * q);
              }

              if (totalCartSubtotal <= 0) return const SizedBox.shrink();

              return Container(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(
                    top: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () => context.push('/cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        'Proceed payment of ${_fmt(totalCartSubtotal)}',
                        style: TextStyle(
                          fontSize: AppTypography.font(15),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _postsStream,
            builder: (context, postsSnapshot) {
              final postsLoading =
                  postsSnapshot.connectionState == ConnectionState.waiting;
              final docs =
                  !postsLoading ? (postsSnapshot.data?.docs ?? []) : [];

              final Map<String, List<Map<String, dynamic>>> groupedSections =
                  {};
              if (!postsLoading) {
                for (var doc in docs) {
                  final item = <String, dynamic>{
                    ...((doc.data() as Map<String, dynamic>)),
                    'id': doc.id,
                    'sourceCollection': _cachedCollectionName,
                  };
                  final isVisible = item['visibleOnMenu'] != false &&
                      item['isVisible'] != false &&
                      item['visible'] != false;
                  if (!isVisible) continue;

                  final sectionName =
                      item['mealCategory'] ?? item['category'] ?? 'General';
                  if (!groupedSections.containsKey(sectionName)) {
                    groupedSections[sectionName] = [];
                  }
                  groupedSections[sectionName]!.add(item);
                }
              }

              final List<String> sectionTitles = groupedSections.keys.toList();
              if (sectionTitles.contains('Promotional')) {
                sectionTitles.remove('Promotional');
                sectionTitles.insert(0, 'Promotional');
              }

              final List<String> categoryTabs = ['All', ...sectionTitles];

              if (_selectedTab >= categoryTabs.length) {
                _selectedTab = 0;
              }

              List<Map<String, dynamic>> itemsToDisplay = [];
              if (_selectedTab == 0) {
                itemsToDisplay =
                    groupedSections.values.expand((e) => e).toList();
              } else {
                final selectedCategory = categoryTabs[_selectedTab];
                itemsToDisplay = groupedSections[selectedCategory] ?? [];
              }

              return CustomScrollView(
                slivers: [
                  // ── Hero Header Section with Overlapping Vendor Card ─────
                  SliverToBoxAdapter(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Cover photo container
                        Container(
                          height: 260.h,
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 120.h),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              coverImageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: coverImageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: isDark
                                            ? AppTheme.darkSurface
                                            : Colors.grey[300],
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color:
                                            purpleColor.withValues(alpha: 0.2),
                                        child: Icon(LucideIcons.image,
                                            size: 40.sp, color: purpleColor),
                                      ),
                                    )
                                  : Container(
                                      color:
                                          purpleColor.withValues(alpha: 0.15),
                                      child: Icon(LucideIcons.store,
                                          size: 48.sp, color: purpleColor),
                                    ),
                              Positioned(
                                top: MediaQuery.of(context).padding.top + 8.h,
                                left: 16.w,
                                right: 16.w,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 38.w,
                                      height: 38.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? Colors.black
                                                .withValues(alpha: 0.5)
                                            : Colors.white
                                                .withValues(alpha: 0.85),
                                        border: Border.all(
                                            color: borderColor, width: 1),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: Icon(LucideIcons.arrowLeft,
                                            color: primaryTextColor,
                                            size: 18.sp),
                                        onPressed: () => context.pop(),
                                      ),
                                    ),
                                    Text(
                                      category,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: AppTypography.font(18),
                                        fontWeight: FontWeight.bold,
                                        shadows: const [
                                          Shadow(
                                              color: Colors.black54,
                                              blurRadius: 6),
                                        ],
                                      ),
                                    ),
                                    StreamBuilder<DocumentSnapshot>(
                                      stream:
                                          FirebaseAuth.instance.currentUser !=
                                                  null
                                              ? FirebaseFirestore.instance
                                                  .collection('customers')
                                                  .doc(FirebaseAuth.instance
                                                      .currentUser!.uid)
                                                  .snapshots()
                                              : null,
                                      builder: (context, customerSnapshot) {
                                        final customerData =
                                            customerSnapshot.data?.data()
                                                as Map<String, dynamic>?;
                                        final favorites = List<String>.from(
                                            customerData?[
                                                    'favoriteRestaurants'] ??
                                                []);
                                        final isFav =
                                            favorites.contains(widget.vendorId);
                                        return Container(
                                          width: 38.w,
                                          height: 38.w,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDark
                                                ? Colors.black
                                                    .withValues(alpha: 0.5)
                                                : Colors.white
                                                    .withValues(alpha: 0.85),
                                            border: Border.all(
                                                color: borderColor, width: 1),
                                          ),
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: Icon(
                                              isFav
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: isFav
                                                  ? Colors.red
                                                  : primaryTextColor,
                                              size: 18.sp,
                                            ),
                                            onPressed: () async {
                                              final uid = FirebaseAuth
                                                  .instance.currentUser?.uid;
                                              if (uid == null) return;
                                              final docRef = FirebaseFirestore
                                                  .instance
                                                  .collection('customers')
                                                  .doc(uid);
                                              if (isFav) {
                                                await docRef.update({
                                                  'favoriteRestaurants':
                                                      FieldValue.arrayRemove(
                                                          [widget.vendorId])
                                                });
                                              } else {
                                                await docRef.update({
                                                  'favoriteRestaurants':
                                                      FieldValue.arrayUnion(
                                                          [widget.vendorId])
                                                });
                                              }
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Vendor Card Positioned directly ON TOP of the lower section of cover photo
                        Positioned(
                          left: 16.w,
                          right: 16.w,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(24.r),
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Vendor Header Row ──────────────────────────
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontSize:
                                                    AppTypography.font(18.sp),
                                                fontWeight: FontWeight.w800,
                                                color: primaryTextColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (verificationTier != null) ...[
                                            SizedBox(width: 6.w),
                                            GestureDetector(
                                              onTap: () =>
                                                  _showVerificationInfoDialog(
                                                context,
                                                verificationTier!,
                                                isDark,
                                              ),
                                              child: VerificationBadge(
                                                vendorData: vendorData,
                                                size: 18.sp,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    // Info Action Button
                                    GestureDetector(
                                      onTap: () => context.push(
                                          '/vendor-detail/${widget.vendorId}'),
                                      child: Container(
                                        width: 32.w,
                                        height: 32.w,
                                        decoration: BoxDecoration(
                                          color: purpleColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(LucideIcons.info,
                                            color: Colors.white, size: 16.sp),
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    // Arrow right to Ratings Screen
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => VendorRatingsScreen(
                                              vendorId: widget.vendorId,
                                              vendorName: name,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Icon(LucideIcons.chevronRight,
                                          color: mutedTextColor, size: 20.sp),
                                    ),
                                  ],
                                ),

                                if (tagline.isNotEmpty) ...[
                                  SizedBox(height: 4.h),
                                  Text(
                                    tagline,
                                    style: TextStyle(
                                      fontSize: AppTypography.font(13),
                                      color: mutedTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],

                                SizedBox(height: 6.h),
                                Row(
                                  children: [
                                    Icon(
                                      LucideIcons.clock,
                                      size: 14.sp,
                                      color: isStoreOpen
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      _getTodayOperatingHoursText(
                                          vendorData['operatingHours']
                                              as Map<String, dynamic>?),
                                      style: TextStyle(
                                        fontSize: AppTypography.font(12),
                                        fontWeight: FontWeight.w600,
                                        color: isStoreOpen
                                            ? (isDark
                                                ? Colors.greenAccent
                                                : Colors.green[700])
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 14.h),

                                // ── Store Stats Box ───────────────────────────────
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : AppTheme.lightInputFill,
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                        color: borderColor, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      // Delivery Fee
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Delivery Fee',
                                              style: TextStyle(
                                                fontSize:
                                                    AppTypography.font(10.sp),
                                                color: mutedTextColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(height: 3.h),
                                            Text(
                                              formattedFee,
                                              style: TextStyle(
                                                fontSize:
                                                    AppTypography.font(13.sp),
                                                fontWeight: FontWeight.bold,
                                                color: primaryTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                          height: 24.h,
                                          width: 1,
                                          color: borderColor),
                                      // Preparation Time
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 10.w),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Preparation time',
                                                style: TextStyle(
                                                  fontSize:
                                                      AppTypography.font(10.sp),
                                                  color: mutedTextColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              SizedBox(height: 3.h),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(LucideIcons.clock,
                                                      size: 12.sp,
                                                      color: purpleColor),
                                                  SizedBox(width: 4.w),
                                                  Flexible(
                                                    child: Text(
                                                      prepTime.toString(),
                                                      style: TextStyle(
                                                        fontSize:
                                                            AppTypography.font(
                                                                12.sp),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: primaryTextColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                          height: 24.h,
                                          width: 1,
                                          color: borderColor),
                                      // Ratings
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 10.w),
                                          child: StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('vendors')
                                                .doc(widget.vendorId)
                                                .collection('reviews')
                                                .snapshots(),
                                            builder:
                                                (context, reviewsSnapshot) {
                                              final reviews =
                                                  reviewsSnapshot.data?.docs ??
                                                      [];
                                              double avgRating = 0.0;
                                              if (reviews.isNotEmpty) {
                                                avgRating = reviews
                                                        .map((r) => ((r.data()
                                                                    as Map<
                                                                        String,
                                                                        dynamic>)[
                                                                'rating'] as num? ??
                                                            0))
                                                        .reduce((a, b) => a + b) /
                                                    reviews.length;
                                              }
                                              final ratingLabel = reviews
                                                      .isEmpty
                                                  ? 'New'
                                                  : '${avgRating.toStringAsFixed(1)} (${reviews.length})';

                                              return GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          VendorRatingsScreen(
                                                        vendorId:
                                                            widget.vendorId,
                                                        vendorName: name,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Ratings',
                                                      style: TextStyle(
                                                        fontSize:
                                                            AppTypography.font(
                                                                10.sp),
                                                        color: mutedTextColor,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    SizedBox(height: 3.h),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.star_rounded,
                                                            size: 14.sp,
                                                            color:
                                                                Colors.amber),
                                                        SizedBox(width: 3.w),
                                                        Flexible(
                                                          child: Text(
                                                            ratingLabel,
                                                            style: TextStyle(
                                                              fontSize:
                                                                  AppTypography
                                                                      .font(12
                                                                          .sp),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  primaryTextColor,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
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
                      ],
                    ),
                  ),

                  // ── Category Pills Filter ───────────────────────────────
                  if (postsLoading)
                    SliverAppBar(
                      pinned: true,
                      automaticallyImplyLeading: false,
                      toolbarHeight: 0,
                      backgroundColor: backgroundColor,
                      elevation: 0,
                      bottom: PreferredSize(
                        preferredSize: Size.fromHeight(
                            (MediaQuery.of(context).size.width >= 600 ||
                                    MediaQuery.of(context).size.shortestSide >=
                                        600)
                                ? 56.h
                                : 48.h),
                        child: Container(
                          color: backgroundColor,
                          height: (MediaQuery.of(context).size.width >= 600 ||
                                  MediaQuery.of(context).size.shortestSide >=
                                      600)
                              ? 56.h
                              : 48.h,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: Row(
                              children: List.generate(
                                4,
                                (index) => Padding(
                                  padding: EdgeInsets.only(right: 8.w),
                                  child: SkeletonLoader(
                                      width: 70.w,
                                      height:
                                          (MediaQuery.of(context).size.width >=
                                                      600 ||
                                                  MediaQuery.of(context)
                                                          .size
                                                          .shortestSide >=
                                                      600)
                                              ? 40.h
                                              : 36.h,
                                      borderRadius: 24.r),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (categoryTabs.isNotEmpty)
                    SliverAppBar(
                      pinned: true,
                      automaticallyImplyLeading: false,
                      toolbarHeight: 0,
                      backgroundColor: backgroundColor,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      bottom: PreferredSize(
                        preferredSize: Size.fromHeight(
                            (MediaQuery.of(context).size.width >= 600 ||
                                    MediaQuery.of(context).size.shortestSide >=
                                        600)
                                ? 56.h
                                : 48.h),
                        child: Container(
                          color: backgroundColor,
                          height: (MediaQuery.of(context).size.width >= 600 ||
                                  MediaQuery.of(context).size.shortestSide >=
                                      600)
                              ? 56.h
                              : 48.h,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical:
                                    (MediaQuery.of(context).size.width >= 600 ||
                                            MediaQuery.of(context)
                                                    .size
                                                    .shortestSide >=
                                                600)
                                        ? 6.h
                                        : 4.h),
                            itemCount: categoryTabs.length,
                            itemBuilder: (context, i) {
                              final isSelected = _selectedTab == i;
                              final isTablet =
                                  MediaQuery.of(context).size.width >= 600 ||
                                      MediaQuery.of(context)
                                              .size
                                              .shortestSide >=
                                          600;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedTab = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: EdgeInsets.only(right: 8.w),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                      vertical: isTablet ? 6.h : 8.h),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected ? purpleColor : surfaceColor,
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: isSelected
                                          ? purpleColor
                                          : borderColor,
                                      width: 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    categoryTabs[i],
                                    style: TextStyle(
                                      fontSize: AppTypography.font(12),
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : primaryTextColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                  // ── Product Cards 2x2 Grid ──────────────────────────────
                  if (postsLoading)
                    SliverPadding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 0,
                          crossAxisSpacing: 14.w,
                          childAspectRatio: 0.77,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              SkeletonLoader.foodMenuItem(context: context),
                          childCount: 4,
                        ),
                      ),
                    )
                  else if (itemsToDisplay.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'No products available in this store yet.',
                          style: TextStyle(
                              color: mutedTextColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width >= 900
                                  ? 4
                                  : (MediaQuery.of(context).size.width >= 600
                                      ? 3
                                      : 2),
                          mainAxisSpacing: 12.h,
                          crossAxisSpacing: 14.w,
                          childAspectRatio: MediaQuery.of(context).size.width >=
                                  600
                              ? 0.78 // <-- Tablet card aspect ratio (increase to make shorter, e.g. 0.78 or 0.80)
                              : 0.70, // <-- Phone card aspect ratio
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, idx) {
                            final item = itemsToDisplay[idx];
                            final title = item['name'] ?? 'Product';
                            final photoUrl = item['photoUrl'] ?? '';
                            final basePriceRaw =
                                (item['basePrice'] ?? 0).toDouble();
                            final originalPriceRaw =
                                item['originalPrice'] != null
                                    ? (item['originalPrice'] as num).toDouble()
                                    : null;
                            final price = PriceHelper.applyMarkup(basePriceRaw,
                                item['sourceCollection'] ?? category);
                            final originalPrice = originalPriceRaw != null
                                ? PriceHelper.applyMarkup(originalPriceRaw,
                                    item['sourceCollection'] ?? category)
                                : null;
                            final mealCategory =
                                item['mealCategory'] ?? item['category'] ?? '';
                            final inStock = item['inStock'] ?? true;
                            final quantity = item['quantity'] as num?;
                            final isOutOfStock = inStock == false ||
                                (quantity != null && quantity <= 0);

                            return FoodCardHorizontal(
                              width: double.infinity,
                              backgroundColor: cardBackgroundColor,
                              title: title,
                              imageUrl: photoUrl,
                              rating:
                                  (item['rating'] as num?)?.toDouble() ?? 0.0,
                              reviewsCount:
                                  (item['reviewsCount'] as num?)?.toInt() ?? 0,
                              distanceKm: distanceKm,
                              basePrice: price,
                              promoPrice: originalPrice,
                              isPromo: originalPrice != null &&
                                  originalPrice > price,
                              categoryName: mealCategory.isNotEmpty
                                  ? mealCategory
                                  : category,
                              vendorName: null,
                              isClosed: !isStoreOpen,
                              isOutOfStock: isOutOfStock,
                              vendorData: vendorData,
                              onTap: () {
                                if (!isStoreOpen) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Ordering is disabled as this store is currently closed.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                context.push('/food-details/$title', extra: {
                                  'vendorId': widget.vendorId,
                                  'docId': item['id'],
                                  'sourceCollection': _cachedCollectionName,
                                });
                              },
                              onFavoriteTap: () {},
                              onAddTap: () {
                                if (!isStoreOpen) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Ordering is disabled as this store is currently closed.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                context.push('/food-details/$title', extra: {
                                  'vendorId': widget.vendorId,
                                  'docId': item['id'],
                                  'sourceCollection': _cachedCollectionName,
                                });
                              },
                            );
                          },
                          childCount: itemsToDisplay.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showVerificationInfoDialog(
      BuildContext context, String tier, bool isDark) {
    Color tierColor;
    String title;
    String subtitle;
    String description;
    IconData icon;

    if (tier == 'gold') {
      tierColor = Colors.amber[700]!;
      title = 'Gold Verification';
      subtitle = 'Official MartFood Partner';
      description =
          "This merchant is a fully verified, premier MartFood partner. We have completed a comprehensive verification suite, including in-person physical address audits, full regulatory corporate compliance checks, and signed operational excellence agreements. Shop with absolute confidence.";
      icon = Icons.stars_rounded;
    } else if (tier == 'standard') {
      tierColor = Colors.green;
      title = 'Standard Verification';
      subtitle = 'Verified & Trusted Business';
      description =
          "This is a verified and highly trusted MartFood merchant. We have completed comprehensive checks on their official Corporate Affairs Commission (CAC) registrations and government-issued business identities. Verification of their physical storefront/address is currently in progress.";
      icon = Icons.verified_user_rounded;
    } else {
      tierColor = Colors.grey;
      title = 'Basic Verification';
      subtitle = 'Starter Business';
      description =
          "This merchant has completed our initial verification phase. We have successfully authenticated their contact details and banking information to ensure safe transactions. While CAC documentation is still pending, they are fully authorized to trade within standard operational limits.";
      icon = Icons.verified_rounded;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => Padding(
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
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tierColor, size: 48.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              style: TextStyle(
                fontSize: AppTypography.font(20),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: AppTypography.font(14),
                fontWeight: FontWeight.w600,
                color: tierColor,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(14),
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.5,
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tierColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }
}
