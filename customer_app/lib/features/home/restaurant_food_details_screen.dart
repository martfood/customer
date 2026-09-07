import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/skeleton_loader.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/widgets/verification_badge.dart';
import 'package:shared_widgets/core/utils/meal_time_helper.dart';
import '../../core/services/price_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

/// A single option in a menu group (e.g. "Coca Cola 35cl – free" or "+₦1,500").
class _MenuOption {
  final String label;
  final double extraPrice; // 0 means no extra charge

  const _MenuOption({required this.label, this.extraPrice = 0});
}

/// A group of radio options (e.g. "Style", "Drinks", "Packaging").
class _MenuGroup {
  final String title;
  final String subtitle; // e.g. "Choose 1 item"
  final bool required;
  final List<_MenuOption> options;

  const _MenuGroup({
    required this.title,
    this.subtitle = 'Choose 1 item',
    this.required = false,
    required this.options,
  });
}

/// A single optional extra add-on item (e.g. "Plantain", "Extra Cheese").
class _AddOnOption {
  final String id;
  final String name;
  final double rawPrice;
  final double price; // Marked up price

  const _AddOnOption({
    required this.id,
    required this.name,
    required this.rawPrice,
    required this.price,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class RestaurantFoodDetailsScreen extends StatefulWidget {
  final String title;
  final String? vendorId;
  final String? docId;
  final String? sourceCollection;

  const RestaurantFoodDetailsScreen({
    super.key,
    required this.title,
    this.vendorId,
    this.docId,
    this.sourceCollection,
  });

  @override
  State<RestaurantFoodDetailsScreen> createState() =>
      _RestaurantFoodDetailsScreenState();
}

class _RestaurantFoodDetailsScreenState
    extends State<RestaurantFoodDetailsScreen> {
  bool _loading = true;
  String? _errorMsg;

  // Real data fields
  double _basePrice = 0;
  double _basePriceRaw = 0;
  double? _originalBasePrice;
  bool _isPromotion = false;
  String _description = '';
  List<String> _imageUrls = [];
  int _currentImagePage = 0;
  List<_MenuGroup> _menuGroups = [];
  Map<String, dynamic>? _rawDocData;
  Map<String, dynamic>? _vendorData;
  String _restaurantName = '';

  // Per-group selected index (-1 = none selected)
  List<int> _selectedIndex = [];

  // Add-ons list and map of selected add-on quantities (id -> quantity)
  List<_AddOnOption> _addOns = [];
  final Map<String, int> _selectedAddOnQuantities = {};
  Set<String> get _selectedAddOnIds => _selectedAddOnQuantities.entries
      .where((e) => e.value > 0)
      .map((e) => e.key)
      .toSet();

  // Full restaurant post metadata fields
  String _orderType = 'single';
  int? _prepTimeMinutes;
  int? _spicyLevel;
  List<String> _allergens = [];
  List<String> _dietaryTags = [];
  String _mealCategory = '';
  String _restaurantType = '';

  int _quantity = 1;
  int? _stockQuantity;
  bool _addedToCart = false;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _loadMeal();
  }

  Future<Map<String, dynamic>?> _fetchMealDetails(String title) async {
    final firestore = FirebaseFirestore.instance;
    final collections = [
      'resturantPosts',
      'grocerytPosts',
      'pharmacytPosts',
      'bakerytPosts'
    ];

    for (final coll in collections) {
      try {
        final querySnap = await firestore
            .collection(coll)
            .where('name', isEqualTo: title)
            .limit(1)
            .get();

        if (querySnap.docs.isNotEmpty) {
          final docData = querySnap.docs.first.data();
          docData['id'] = querySnap.docs.first.id;
          docData['sourceCollection'] = coll;
          return docData;
        }
      } catch (e) {
        debugPrint('Error searching $coll: $e');
      }
    }
    return null;
  }

  Future<void> _loadMeal() async {
    Map<String, dynamic>? docData;
    if ((widget.sourceCollection ?? '').isNotEmpty &&
        (widget.docId ?? '').isNotEmpty) {
      try {
        final docSnap = await FirebaseFirestore.instance
            .collection(widget.sourceCollection!)
            .doc(widget.docId!)
            .get();
        if (docSnap.exists) {
          docData = docSnap.data() as Map<String, dynamic>;
          docData['id'] = docSnap.id;
          docData['sourceCollection'] = widget.sourceCollection;
        }
      } catch (e) {
        debugPrint('Error loading item by docId: $e');
      }
    }

    docData ??= await _fetchMealDetails(widget.title);
    if (!mounted) return;

    if (docData == null) {
      setState(() {
        _loading = false;
        _errorMsg = "Meal details not found.";
      });
      return;
    }

    _rawDocData = docData;
    final firestore = FirebaseFirestore.instance;
    final vendorId = widget.vendorId ?? docData['vendorId'];
    if (vendorId != null) {
      try {
        final vendorSnap =
            await firestore.collection('vendors').doc(vendorId).get();
        if (vendorSnap.exists && mounted) {
          final vendorData = vendorSnap.data();
          final profile =
              vendorData?['businessProfile'] as Map<String, dynamic>?;
          _restaurantName = profile?['restaurantName'] ??
              profile?['businessName'] ??
              vendorData?['restaurantName'] ??
              vendorData?['businessName'] ??
              '';
          _vendorData = vendorData;
        }
      } catch (e) {
        debugPrint('Error loading vendor profile: $e');
      }
    }

    // Check if this item is already in the user's cart in Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final cartSnap = await firestore
            .collection('customers')
            .doc(user.uid)
            .collection('cart')
            .doc(widget.title)
            .get();
        if (cartSnap.exists && mounted) {
          _addedToCart = true;
        }
      } catch (e) {
        debugPrint('Error checking cart status: $e');
      }
    }

    final isPromotion = docData['isPromotion'] ?? false;
    final promoPriceVal = (docData['promoPrice'] ?? 0).toDouble();
    final basePriceVal = (docData['basePrice'] ?? 0).toDouble();

    double activePriceRaw;
    double? originalBasePriceRaw;
    if (isPromotion && promoPriceVal > 0 && basePriceVal > promoPriceVal) {
      activePriceRaw = promoPriceVal;
      originalBasePriceRaw = basePriceVal;
    } else {
      activePriceRaw = basePriceVal > 0 ? basePriceVal : promoPriceVal;
    }

    final sourceColl = docData['sourceCollection'] ?? widget.sourceCollection;
    final double activePrice =
        PriceHelper.applyMarkup(activePriceRaw, sourceColl);
    final double? originalBasePrice = originalBasePriceRaw != null
        ? PriceHelper.applyMarkup(originalBasePriceRaw, sourceColl)
        : null;

    final String descriptionVal = docData['description'] ?? '';

    final List<String> imageUrlsList = [];
    final rawImageUrls = docData['imageUrls'];
    if (rawImageUrls is List && rawImageUrls.isNotEmpty) {
      for (var item in rawImageUrls) {
        final str = item?.toString().trim() ?? '';
        if (str.isNotEmpty && !imageUrlsList.contains(str)) {
          imageUrlsList.add(str);
        }
      }
    } else if (rawImageUrls is String && rawImageUrls.trim().isNotEmpty) {
      imageUrlsList.add(rawImageUrls.trim());
    }

    final fallbacks = [
      docData['photoUrl'],
      docData['imageUrl'],
      docData['image'],
    ];
    for (var fb in fallbacks) {
      if (fb != null && fb.toString().trim().isNotEmpty) {
        final str = fb.toString().trim();
        if (!imageUrlsList.contains(str)) {
          imageUrlsList.add(str);
        }
      }
    }

    final List<dynamic>? rawGroups = docData['customOptionGroups'];
    final List<_MenuGroup> parsedGroups = [];
    if (rawGroups != null) {
      for (var rg in rawGroups) {
        final groupMap = rg as Map<String, dynamic>;
        final groupName = groupMap['name'] ?? 'Options';
        final required = groupMap['required'] ?? false;
        final maxSelect = groupMap['maxSelect'] ?? 1;
        final subtitle = 'Choose up to $maxSelect item(s)';

        final List<dynamic>? choices = groupMap['choices'];
        final List<_MenuOption> parsedOptions = [];
        if (choices != null) {
          for (var ch in choices) {
            final choiceMap = ch as Map<String, dynamic>;
            final label = choiceMap['label'] ?? '';
            final rawPrice =
                (choiceMap['priceDelta'] ?? choiceMap['price'] ?? 0).toDouble();
            final extraPrice = PriceHelper.applyMarkup(rawPrice, sourceColl);
            parsedOptions
                .add(_MenuOption(label: label, extraPrice: extraPrice));
          }
        }
        parsedGroups.add(_MenuGroup(
          title: groupName,
          subtitle: subtitle,
          required: required,
          options: parsedOptions,
        ));
      }
    }

    // Variants list (e.g. from vendor_app)
    final rawVariants = docData['variants'];
    if (rawVariants is List && rawVariants.isNotEmpty) {
      final List<_MenuOption> variantOptions = [];
      for (var v in rawVariants) {
        if (v is Map) {
          final label = (v['label'] ?? v['name'] ?? '').toString().trim();
          final rawPrice =
              (v['priceDelta'] ?? v['price'] ?? 0).toDouble();
          final extraPrice = PriceHelper.applyMarkup(rawPrice, sourceColl);
          if (label.isNotEmpty) {
            variantOptions
                .add(_MenuOption(label: label, extraPrice: extraPrice));
          }
        }
      }
      if (variantOptions.isNotEmpty) {
        parsedGroups.insert(
          0,
          _MenuGroup(
            title: 'Variants',
            subtitle: 'Choose an option',
            required: true,
            options: variantOptions,
          ),
        );
      }
    }

    final rawAddOns = docData['addOns'] ?? docData['addons'];
    final List<_AddOnOption> parsedAddOns = [];
    if (rawAddOns is List && rawAddOns.isNotEmpty) {
      for (var item in rawAddOns) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final id = (map['id'] ?? '').toString();
          final name =
              (map['name'] ?? map['title'] ?? map['label'] ?? '')
                  .toString()
                  .trim();
          if (name.isNotEmpty) {
            final rawPrice =
                (map['price'] ?? map['priceDelta'] ?? 0).toDouble();
            final price = PriceHelper.applyMarkup(rawPrice, sourceColl);
            parsedAddOns.add(_AddOnOption(
              id: id.isNotEmpty ? id : name,
              name: name,
              rawPrice: rawPrice,
              price: price,
            ));
          }
        }
      }
    }

    final inStock = docData['inStock'] ?? true;
    final stockQtyNum = docData['quantity'] as num?;
    final int? stockQty = stockQtyNum?.toInt();
    final bool isOutOfStock = inStock == false || (stockQty != null && stockQty <= 0);
    bool isAvail = inStock && !isOutOfStock;
    if (isAvail) {
      final orderType = docData['orderType'] ?? 'single';
      if (orderType == 'bulk' || docData['isBulkMeal'] == true) {
        final startTimeStr =
            (docData['orderStartTime'] ?? docData['orderStarttime'])?.toString();
        final closeTimeStr = (docData['orderEndTime'] ??
                docData['orderClosetime'] ??
                docData['orderTimeClose'])
            ?.toString();
        final start = MealTimeHelper.parseTime(startTimeStr);
        final close = MealTimeHelper.parseTime(closeTimeStr);
        if (close != null) {
          final now = DateTime.now();
          final nowMinutes = now.hour * 60 + now.minute;
          final closeMinutes = close.hour * 60 + close.minute;
          final startMinutes =
              start != null ? (start.hour * 60 + start.minute) : null;
          if (startMinutes != null) {
            if (closeMinutes >= startMinutes) {
              isAvail = nowMinutes >= startMinutes && nowMinutes <= closeMinutes;
            } else {
              isAvail = nowMinutes >= startMinutes || nowMinutes <= closeMinutes;
            }
          } else {
            isAvail = nowMinutes <= closeMinutes;
          }
        }
      }
    }

    final String orderTypeVal =
        (docData['orderType'] ?? 'single').toString().trim();
    final int? prepTimeVal = docData['prepTimeMinutes'] != null
        ? (docData['prepTimeMinutes'] as num).toInt()
        : null;
    final int? spicyLevelVal = docData['spicyLevel'] != null
        ? (docData['spicyLevel'] as num).toInt()
        : null;
    final List<String> allergensVal = (docData['allergens'] as List?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final List<String> dietaryVal = (docData['dietaryTags'] as List?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final String mealCategoryVal =
        (docData['mealCategory'] ?? '').toString().trim();
    final String restaurantTypeVal =
        (docData['restaurantType'] ?? '').toString().trim();

    setState(() {
      _basePrice = activePrice;
      _basePriceRaw = activePriceRaw;
      _originalBasePrice = originalBasePrice;
      _isPromotion = isPromotion;
      _description = descriptionVal;
      _imageUrls = imageUrlsList;
      _menuGroups = parsedGroups;
      _selectedIndex = _menuGroups.map((g) => g.required ? 0 : -1).toList();
      _addOns = parsedAddOns;
      _selectedAddOnQuantities.clear();
      _orderType = orderTypeVal;
      _prepTimeMinutes = prepTimeVal;
      _spicyLevel = spicyLevelVal;
      _allergens = allergensVal;
      _dietaryTags = dietaryVal;
      _mealCategory = mealCategoryVal;
      _restaurantType = restaurantTypeVal;
      _stockQuantity = stockQty;
      _isAvailable = isAvail;
      _loading = false;
    });
  }

  // ── Computed total ──────────────────────────────────────────────────────────

  double get _totalPrice {
    double extra = 0;
    for (int g = 0; g < _menuGroups.length; g++) {
      final sel = _selectedIndex[g];
      if (sel >= 0 && sel < _menuGroups[g].options.length) {
        extra += _menuGroups[g].options[sel].extraPrice;
      }
    }
    for (final addon in _addOns) {
      final qty = _selectedAddOnQuantities[addon.id] ?? 0;
      if (qty > 0) {
        extra += addon.price * qty;
      }
    }
    return (_basePrice + extra) * _quantity;
  }


  String _fmt(double price) {
    final formatted = price.toInt().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '₦$formatted.00';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    if (_loading) {
      return SkeletonLoader.foodDetails(context: context);
    }

    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8.h,
                left: 16.w,
                child: IconButton(
                  icon: Icon(LucideIcons.arrowLeft, color: primaryTextColor),
                  onPressed: () => context.pop(),
                ),
              ),
              Center(
                child: Text(
                  _errorMsg!,
                  style: TextStyle(
                      color: mutedTextColor,
                      fontSize: AppTypography.font(AppFontSizes.bodyLarge)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // ── Scrollable content ──
          CustomScrollView(
            slivers: [
              // Edge-to-edge Flat Product Image(s) touching top, left, and right completely
              SliverToBoxAdapter(
                child: _buildTopImageHeader(isDark),
              ),

              // Name, price, description
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title.isNotEmpty
                            ? widget.title
                            : 'Product Details',
                        style: TextStyle(
                          fontSize:
                              AppTypography.font(AppFontSizes.headlineLarge),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      if (_restaurantName.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _restaurantName,
                                style: TextStyle(
                                  fontSize: AppTypography.font(14),
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : const Color(0xFF4A4A68),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_vendorData != null) ...[
                              SizedBox(width: 5.w),
                              VerificationBadge(
                                vendorData: _vendorData!,
                                size: 15.sp,
                              ),
                            ],
                          ],
                        ),
                      ],
                      SizedBox(height: 10.h),
                      // Price row: displays basePrice beside promo price if discount
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _fmt(_basePrice),
                            style: TextStyle(
                              fontSize: AppTypography.font(
                                  AppFontSizes.headlineMedium),
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.primaryPurple,
                            ),
                          ),
                          if (_originalBasePrice != null &&
                              _originalBasePrice! > _basePrice) ...[
                            SizedBox(width: 8.w),
                            Text(
                              _fmt(_originalBasePrice!),
                              style: TextStyle(
                                fontSize:
                                    AppTypography.font(AppFontSizes.bodyLarge),
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : mutedTextColor,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          if (_isPromotion) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: purpleColor,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'PROMO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AppTypography.font(10),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          if (!_isAvailable) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Out of Stock',
                                style: TextStyle(
                                  fontSize: AppTypography.font(11),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_description.isNotEmpty) ...[
                        SizedBox(height: 14.h),
                        Text(
                          _description,
                          style: TextStyle(
                            fontSize:
                                AppTypography.font(AppFontSizes.bodyMedium),
                            color: mutedTextColor,
                            height: 1.5,
                          ),
                        ),
                      ],
                      _buildRestaurantPostInfo(
                        isDark,
                        surfaceColor,
                        borderColor,
                        primaryTextColor,
                        mutedTextColor,
                        purpleColor,
                      ),
                      if (_rawDocData != null) ...[
                        Builder(builder: (context) {
                          final orderType = _rawDocData!['orderType'] ?? '';
                          final isBulkMeal = orderType == 'bulk' ||
                              _rawDocData!['isBulkMeal'] == true ||
                              _rawDocData!['mealCategory'] == 'Bulk Meals' ||
                              (_rawDocData!['category'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains('bulk') ||
                              (_rawDocData!['category'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains('schedule') ||
                              _rawDocData!['orderStartTime'] != null ||
                              _rawDocData!['orderStarttime'] != null ||
                              _rawDocData!['deliveryStartTime'] != null ||
                              _rawDocData!['deliveryStarttime'] != null;

                          if (!isBulkMeal) return const SizedBox.shrink();

                          final rawOrderStart = _rawDocData!['orderStartTime'] ??
                              _rawDocData!['orderStarttime'];
                          final rawOrderClose = _rawDocData!['orderEndTime'] ??
                              _rawDocData!['orderClosetime'] ??
                              _rawDocData!['orderTimeClose'];
                          final rawDeliveryStart =
                              _rawDocData!['deliveryStartTime'] ??
                                  _rawDocData!['deliveryStarttime'];
                          final rawDeliveryClose =
                              _rawDocData!['deliveryEndTime'] ??
                                  _rawDocData!['deliveryClosetime'];

                          final orderWindow = MealTimeHelper.formatTimeWindow(
                            rawOrderStart?.toString(),
                            rawOrderClose?.toString(),
                          );
                          final deliveryWindow =
                              MealTimeHelper.formatTimeWindow(
                            rawDeliveryStart?.toString(),
                            rawDeliveryClose?.toString(),
                          );
                          final rawClosesText =
                              (_rawDocData!['orderClosesText'] ?? '')
                                  .toString()
                                  .trim();
                          final orderClosesText = rawClosesText.isNotEmpty
                              ? rawClosesText
                              : MealTimeHelper.calculateOrderClosesText(
                                  startTimeStr: rawOrderStart?.toString(),
                                  closeTimeStr: rawOrderClose?.toString(),
                                );

                          if (orderWindow.isEmpty &&
                              deliveryWindow.isEmpty &&
                              orderClosesText.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: EdgeInsets.only(top: 16.h),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 14.h),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkSurface
                                    : const Color(0xFFF6F7FB),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.darkBorder
                                      : const Color(0xFFEBECEF),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // ── Order time row ──
                                  if (orderWindow.isNotEmpty) ...[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.clock,
                                              size: 16.sp,
                                              color: isDark
                                                  ? Colors.grey[300]
                                                  : const Color(0xFF333333),
                                            ),
                                            SizedBox(width: 8.w),
                                            Text(
                                              'Order time',
                                              style: TextStyle(
                                                fontSize:
                                                    AppTypography.font(13.5),
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? Colors.grey[300]
                                                    : const Color(0xFF333333),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          orderWindow,
                                          style: TextStyle(
                                            fontSize:
                                                AppTypography.font(13.5),
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.grey[300]
                                                : const Color(0xFF333333),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (orderWindow.isNotEmpty &&
                                      deliveryWindow.isNotEmpty)
                                    SizedBox(height: 10.h),
                                  // ── Delivery time row ──
                                  if (deliveryWindow.isNotEmpty) ...[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.calendar,
                                              size: 16.sp,
                                              color: isDark
                                                  ? Colors.grey[300]
                                                  : const Color(0xFF333333),
                                            ),
                                            SizedBox(width: 8.w),
                                            Text(
                                              'Delivery time',
                                              style: TextStyle(
                                                fontSize:
                                                    AppTypography.font(13.5),
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? Colors.grey[300]
                                                    : const Color(0xFF333333),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          deliveryWindow,
                                          style: TextStyle(
                                            fontSize:
                                                AppTypography.font(13.5),
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.grey[300]
                                                : const Color(0xFF333333),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  // ── Order Closes Banner Pill ──
                                  if (orderClosesText.isNotEmpty) ...[
                                    SizedBox(height: 12.h),
                                    Container(
                                      width: double.infinity,
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8.h),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? purpleColor.withValues(alpha: 0.18)
                                            : const Color(0xFFF3E8FF),
                                        borderRadius:
                                            BorderRadius.circular(10.r),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(LucideIcons.clock,
                                              size: 14.sp, color: purpleColor),
                                          SizedBox(width: 6.w),
                                          Text(
                                            orderClosesText,
                                            style: TextStyle(
                                              fontSize:
                                                  AppTypography.font(12.5),
                                              fontWeight: FontWeight.w600,
                                              color: purpleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),

              // Menu groups
              if (_menuGroups.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildMenuGroup(
                        index,
                        _menuGroups[index],
                        isDark,
                        primaryTextColor,
                        mutedTextColor,
                        surfaceColor,
                        borderColor,
                      ),
                      childCount: _menuGroups.length,
                    ),
                  ),
                ),

              // Add-ons section
              if (_addOns.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20.w,
                    _menuGroups.isEmpty ? 18.h : 0,
                    20.w,
                    18.h,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _buildAddOnsSection(
                      isDark,
                      primaryTextColor,
                      mutedTextColor,
                      surfaceColor,
                      borderColor,
                    ),
                  ),
                ),

              // Bottom spacing so content is not hidden behind the sticky bottom bar
              SliverToBoxAdapter(child: SizedBox(height: 100.h)),
            ],
          ),

          // ── Sticky Add button with Quantity UI on the Left ──
          _buildAddButton(context, isDark, surfaceColor, primaryTextColor),
        ],
      ),
    );
  }

  // ── Top Edge-To-Edge Image Header ─────────────────────────────────────────────

  Widget _buildTopImageHeader(bool isDark) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    if (_imageUrls.isEmpty) {
      return Container(
        height: 260.h,
        width: double.infinity,
        color: isDark ? AppTheme.darkSurface : AppTheme.lightInputFill,
        child: Stack(
          children: [
            Center(
              child:
                  Icon(LucideIcons.image, color: Colors.grey[500], size: 48.sp),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8.h,
              left: 16.w,
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurface.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : AppTheme.lightInputBorder,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    LucideIcons.arrowLeft,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    size: 20.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: 280.h,
          width: double.infinity,
          child: _imageUrls.length == 1
              ? CachedNetworkImage(
                  imageUrl: _imageUrls[0],
                  width: double.infinity,
                  height: 280.h,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color:
                        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: purpleColor, strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color:
                        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill,
                    alignment: Alignment.center,
                    child: Icon(LucideIcons.image,
                        color: Colors.grey[500], size: 40.sp),
                  ),
                )
              : PageView.builder(
                  itemCount: _imageUrls.length,
                  onPageChanged: (index) =>
                      setState(() => _currentImagePage = index),
                  itemBuilder: (context, index) => CachedNetworkImage(
                    imageUrl: _imageUrls[index],
                    width: double.infinity,
                    height: 280.h,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isDark
                          ? AppTheme.darkSurface
                          : AppTheme.lightInputFill,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: purpleColor, strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark
                          ? AppTheme.darkSurface
                          : AppTheme.lightInputFill,
                      alignment: Alignment.center,
                      child: Icon(LucideIcons.image,
                          color: Colors.grey[500], size: 40.sp),
                    ),
                  ),
                ),
        ),
        // Dots indicator if multiple images
        if (_imageUrls.length > 1)
          Positioned(
            bottom: 12.h,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _imageUrls.length,
                (index) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: _currentImagePage == index ? 20.w : 8.w,
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: _currentImagePage == index
                        ? purpleColor
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
            ),
          ),
        // Floating Back Button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8.h,
          left: 16.w,
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurface.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder,
                  width: 1,
                ),
              ),
              child: Icon(
                LucideIcons.arrowLeft,
                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                size: 20.sp,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Menu group section ──────────────────────────────────────────────────────

  Widget _buildMenuGroup(
    int groupIndex,
    _MenuGroup group,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groupIndex > 0) SizedBox(height: 16.h),
        // Group header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.title,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Text(
                  group.subtitle,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    color: mutedTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8.w),
                if (group.required)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2000)
                          : const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'Required',
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.caption),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF996600),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        SizedBox(height: 16.h),
        // Options list inside flat minimal card wrapper
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.options.length,
            separatorBuilder: (context, oi) => Divider(
              height: 2,
              color: borderColor,
            ),
            itemBuilder: (context, oi) {
              final option = group.options[oi];
              final isSelected = _selectedIndex[groupIndex] == oi;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedIndex[groupIndex] = isSelected ? -1 : oi;
                  });
                },
                borderRadius: BorderRadius.circular(16.r),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            fontSize:
                                AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      if (option.extraPrice > 0)
                        Text(
                          '+${_fmt(option.extraPrice)}',
                          style: TextStyle(
                            fontSize:
                                AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? purpleColor
                                : mutedTextColor,
                          ),
                        ),
                      SizedBox(width: 12.w),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? purpleColor
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.24)
                                    : Colors.grey[400]!),
                            width: isSelected ? 6 : 2,
                          ),
                          color: isSelected ? Colors.white : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Add-ons Section ───────────────────────────────────────────────────────

  Widget _buildAddOnsSection(
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add-ons',
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Optional extras to customize your meal',
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                color: mutedTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        // Add-ons list inside flat minimal card wrapper
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _addOns.length,
            separatorBuilder: (context, i) => Divider(
              height: 2,
              color: borderColor,
            ),
            itemBuilder: (context, i) {
              final addon = _addOns[i];
              final qty = _selectedAddOnQuantities[addon.id] ?? 0;

              return InkWell(
                onTap: () {
                  if (qty == 0) {
                    setState(() {
                      _selectedAddOnQuantities[addon.id] = 1;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(16.r),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  child: Row(
                    children: [
                      // Name and Price on the left
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              addon.name,
                              style: TextStyle(
                                fontSize:
                                    AppTypography.font(AppFontSizes.bodyMedium),
                                fontWeight:
                                    qty > 0 ? FontWeight.bold : FontWeight.w500,
                                color: primaryTextColor,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              addon.price > 0
                                  ? '+${_fmt(addon.price)}'
                                  : 'Free',
                              style: TextStyle(
                                fontSize:
                                    AppTypography.font(AppFontSizes.bodySmall),
                                fontWeight: FontWeight.w600,
                                color: qty > 0 ? purpleColor : mutedTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // - 0 + Stepper UI aligned to right side
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Decrement button (-)
                          GestureDetector(
                            onTap: qty > 0
                                ? () {
                                    setState(() {
                                      if (qty == 1) {
                                        _selectedAddOnQuantities
                                            .remove(addon.id);
                                      } else {
                                        _selectedAddOnQuantities[addon.id] =
                                            qty - 1;
                                      }
                                    });
                                  }
                                : null,
                            child: Container(
                              width: 28.w,
                              height: 28.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: qty > 0
                                    ? (isDark
                                        ? AppTheme.darkSurface
                                        : Colors.white)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.grey[100]!),
                                border: Border.all(
                                  color: qty > 0
                                      ? borderColor
                                      : borderColor.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                LucideIcons.minus,
                                size: 13.sp,
                                color: qty > 0
                                    ? (isDark
                                        ? Colors.white
                                        : const Color(0xFF1E1E1E))
                                    : (isDark
                                        ? Colors.white24
                                        : Colors.grey[400]!),
                              ),
                            ),
                          ),
                          // Quantity count
                          SizedBox(
                            width: 24.w,
                            child: Text(
                              '$qty',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: AppTypography.font(13),
                                fontWeight:
                                    qty > 0 ? FontWeight.bold : FontWeight.w600,
                                color: qty > 0
                                    ? primaryTextColor
                                    : mutedTextColor,
                              ),
                            ),
                          ),
                          // Increment button (+)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAddOnQuantities[addon.id] = qty + 1;
                              });
                            },
                            child: Container(
                              width: 28.w,
                              height: 28.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: purpleColor,
                              ),
                              child: Icon(
                                LucideIcons.plus,
                                size: 13.sp,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Restaurant Post Info (Spicy Level, Dietary Tags, Allergens) ─────────────

  Widget _buildRestaurantPostInfo(
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color primaryTextColor,
    Color mutedTextColor,
    Color purpleColor,
  ) {
    final hasTags = _dietaryTags.isNotEmpty;
    final hasAllergens = _allergens.isNotEmpty;
    final hasSpicy = _spicyLevel != null && _spicyLevel! > 0;

    if (!hasSpicy && !hasTags && !hasAllergens) {
      return const SizedBox.shrink();
    }

    String spicyLabel = '';
    if (_spicyLevel != null && _spicyLevel! > 0) {
      switch (_spicyLevel) {
        case 1:
          spicyLabel = '🌶️ Mild';
          break;
        case 2:
          spicyLabel = '🌶️🌶️ Medium';
          break;
        case 3:
          spicyLabel = '🔥 Extra Hot';
          break;
        default:
          spicyLabel = '';
      }
    }

    return Padding(
      padding: EdgeInsets.only(top: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Spicy Level Pill ──
          if (spicyLabel.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Text(
                spicyLabel,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
            ),

          // ── Dietary Tags ──
          if (hasTags) ...[
            SizedBox(height: spicyLabel.isNotEmpty ? 10.h : 0),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: _dietaryTags.map((tag) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurface
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Text(
                    '✓ $tag',
                    style: TextStyle(
                      fontSize: AppTypography.font(11),
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // ── Allergens Warning Banner ──
          if (hasAllergens) ...[
            SizedBox(height: (spicyLabel.isNotEmpty || hasTags) ? 12.h : 0),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.withValues(alpha: 0.1)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.alertCircle,
                    size: 14.sp,
                    color: Colors.amber[700],
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Allergens: Contains ${_allergens.join(', ')}',
                      style: TextStyle(
                        fontSize: AppTypography.font(11.5),
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber[300] : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sticky bottom Add button with Quantity UI on Left ───────────────────────

  Widget _buildAddButton(BuildContext context, bool isDark, Color surfaceColor,
      Color primaryTextColor) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final double currentTotal = _totalPrice;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Cart Icon Button (on the left side)
            if (_addedToCart) ...[
              Container(
                width: 48.w,
                height: 48.h,
                margin: EdgeInsets.only(right: 10.w),
                child: ElevatedButton(
                  onPressed: () => context.push('/cart'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill,
                    foregroundColor: purpleColor,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      side: BorderSide(color: borderColor, width: 1),
                    ),
                    elevation: 0,
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseAuth.instance.currentUser != null
                        ? FirebaseFirestore.instance
                            .collection('customers')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('cart')
                            .snapshots()
                        : const Stream.empty(),
                    builder: (context, snapshot) {
                      final cartCount = snapshot.data?.docs.length ?? 0;

                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 22.sp, color: purpleColor),
                          if (cartCount > 0)
                            Positioned(
                              right: -4.w,
                              top: -4.h,
                              child: Container(
                                padding: EdgeInsets.all(4.w),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 16.w,
                                  minHeight: 16.w,
                                ),
                                child: Center(
                                  child: Text(
                                    '$cartCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: AppTypography.font(9),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],

            // Quantity UI
            _QuantityPill(
              quantity: _quantity,
              isDark: isDark,
              onDecrement: () {
                if (_quantity > 1) setState(() => _quantity--);
              },
              onIncrement: () {
                if (_stockQuantity != null && _quantity >= _stockQuantity!) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Only $_stockQuantity item(s) available in stock'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                setState(() => _quantity++);
              },
            ),
            SizedBox(width: 12.w),

            // Main Action Button (Add to Cart / Checkout)
            Expanded(
              child: ElevatedButton(
                onPressed: !_isAvailable
                    ? null
                    : () async {
                        if (!_addedToCart) {
                          // Check required groups
                          for (int g = 0; g < _menuGroups.length; g++) {
                            if (_menuGroups[g].required &&
                                _selectedIndex[g] < 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please select an option for "${_menuGroups[g].title}"',
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          // Save to Firestore under customers/{uid}/cart
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            final firestore = FirebaseFirestore.instance;

                            final currentVendorId =
                                (widget.vendorId ?? _rawDocData?['vendorId'])
                                        ?.toString() ??
                                    '';
                            if (currentVendorId.isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not identify vendor for this item. Please reopen the item from the vendor page.',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }

                            // Check if cart contains items from a different vendor (bottom sheet)
                            final proceed =
                                await _checkAndHandleMultiVendorCart(
                                    context, currentVendorId, user.uid);
                            if (!proceed) return;

                            final List<Map<String, dynamic>> selectedChoices =
                                [];
                            for (int g = 0; g < _menuGroups.length; g++) {
                              final sel = _selectedIndex[g];
                              if (sel >= 0 &&
                                  sel < _menuGroups[g].options.length) {
                                selectedChoices.add({
                                  'group': _menuGroups[g].title,
                                  'label': _menuGroups[g].options[sel].label,
                                  'extraPrice':
                                      _menuGroups[g].options[sel].extraPrice,
                                });
                              }
                            }

                            final List<Map<String, dynamic>> selectedAddOns =
                                [];
                            for (final addon in _addOns) {
                              final qty =
                                  _selectedAddOnQuantities[addon.id] ?? 0;
                              if (qty > 0) {
                                selectedAddOns.add({
                                  'id': addon.id,
                                  'name': addon.name,
                                  'price': addon.price,
                                  'rawPrice': addon.rawPrice,
                                  'quantity': qty,
                                });
                              }
                            }

                            final double choicesExtra = selectedChoices.fold(
                                0.0,
                                (acc, item) =>
                                    acc + (item['extraPrice'] as double));
                            final double choicesRawExtra = selectedChoices.fold(
                                0.0,
                                (acc, item) =>
                                    acc + (item['extraPrice'] as double));
                            final double addOnsExtra = selectedAddOns.fold(
                                0.0,
                                (acc, item) =>
                                    acc +
                                    ((item['price'] as double) *
                                        ((item['quantity'] as int?) ?? 1)));
                            final double addOnsRawExtra = selectedAddOns.fold(
                                0.0,
                                (acc, item) =>
                                    acc +
                                    ((item['rawPrice'] as double) *
                                        ((item['quantity'] as int?) ?? 1)));

                            final cartItem = {
                              'id': widget.title,
                              'title': widget.title,
                              'price': _basePrice + choicesExtra + addOnsExtra,
                              'basePrice': _basePriceRaw +
                                  choicesRawExtra +
                                  addOnsRawExtra,
                              'quantity': _quantity,
                              'imageUrl':
                                  _imageUrls.isNotEmpty ? _imageUrls[0] : '',
                              'restaurant': _restaurantName,
                              'vendorId': currentVendorId,
                              'orderType': _orderType,
                              'selectedChoices': selectedChoices,
                              'selectedAddOns': selectedAddOns,
                              'addedAt': FieldValue.serverTimestamp(),
                            };

                            await firestore
                                .collection('customers')
                                .doc(user.uid)
                                .collection('cart')
                                .doc(widget.title)
                                .set(cartItem);

                            setState(() {
                              _addedToCart = true;
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('${widget.title} added to cart!')),
                              );
                            }
                          }
                        } else {
                          // Navigate to checkout with just this single order item
                          final List<Map<String, dynamic>> selectedChoices = [];
                          for (int g = 0; g < _menuGroups.length; g++) {
                            final sel = _selectedIndex[g];
                            if (sel >= 0 &&
                                sel < _menuGroups[g].options.length) {
                              selectedChoices.add({
                                'group': _menuGroups[g].title,
                                'label': _menuGroups[g].options[sel].label,
                                'extraPrice':
                                    _menuGroups[g].options[sel].extraPrice,
                              });
                            }
                          }

                          final List<Map<String, dynamic>> selectedAddOns = [];
                          for (final addon in _addOns) {
                            final qty =
                                _selectedAddOnQuantities[addon.id] ?? 0;
                            if (qty > 0) {
                              selectedAddOns.add({
                                'id': addon.id,
                                'name': addon.name,
                                'price': addon.price,
                                'rawPrice': addon.rawPrice,
                                'quantity': qty,
                              });
                            }
                          }

                          final double choicesExtra = selectedChoices.fold(
                              0.0,
                              (acc, item) =>
                                  acc + (item['extraPrice'] as double));
                          final double choicesRawExtra = selectedChoices.fold(
                              0.0,
                              (acc, item) =>
                                  acc + (item['extraPrice'] as double));
                          final double addOnsExtra = selectedAddOns.fold(
                              0.0,
                              (acc, item) =>
                                  acc +
                                  ((item['price'] as double) *
                                      ((item['quantity'] as int?) ?? 1)));
                          final double addOnsRawExtra = selectedAddOns.fold(
                              0.0,
                              (acc, item) =>
                                  acc +
                                  ((item['rawPrice'] as double) *
                                      ((item['quantity'] as int?) ?? 1)));

                          final singleOrder = {
                            'id': widget.title,
                            'title': widget.title,
                            'price': _basePrice + choicesExtra + addOnsExtra,
                            'basePrice': _basePriceRaw +
                                choicesRawExtra +
                                addOnsRawExtra,
                            'quantity': _quantity,
                            'imageUrl':
                                _imageUrls.isNotEmpty ? _imageUrls[0] : '',
                            'restaurant': _restaurantName,
                            'vendorId':
                                widget.vendorId ?? _rawDocData?['vendorId'],
                            'orderType': _orderType,
                            'selectedChoices': selectedChoices,
                            'selectedAddOns': selectedAddOns,
                          };

                          if ((singleOrder['vendorId'] ?? '')
                              .toString()
                              .isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not identify vendor for this item. Please reopen the item from the vendor page.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          context.push('/checkout', extra: {
                            'checkoutItems': [singleOrder],
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  !_isAvailable
                      ? 'Out of Stock'
                      : (_addedToCart
                          ? 'Checkout'
                          : 'Add ${_fmt(currentTotal)}'),
                  style: TextStyle(
                    fontSize: AppTypography.font(15),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkAndHandleMultiVendorCart(
      BuildContext context, String currentVendorId, String userId) async {
    final firestore = FirebaseFirestore.instance;
    try {
      final cartSnap = await firestore
          .collection('customers')
          .doc(userId)
          .collection('cart')
          .get();

      if (cartSnap.docs.isEmpty) return true;

      bool hasDifferentVendor = false;
      for (var doc in cartSnap.docs) {
        final data = doc.data();
        final itemVendorId = data['vendorId']?.toString();
        if (itemVendorId != null && itemVendorId != currentVendorId) {
          hasDifferentVendor = true;
          break;
        }
      }

      if (!hasDifferentVendor) return true;

      // Show bottom sheet screen invariant (Rule 5)
      if (!context.mounted) return false;
      final bool? shouldClear = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final purpleColor = AppTheme.primaryPurpleFor(isDark);
          final surface = isDark ? AppTheme.darkSurface : Colors.white;
          final border =
              isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
          final textClr = isDark ? Colors.white : const Color(0xFF15161A);
          final mutedClr = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

          return Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              border: Border.all(color: border, width: 1),
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
                SizedBox(height: 16.h),
                Text(
                  'Replace Cart Items?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: AppTypography.font(20),
                    color: textClr,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Your cart contains items from another restaurant. Do you want to clear your cart and start a new order with this item?',
                  style: TextStyle(
                    fontSize: AppTypography.font(14),
                    color: mutedClr,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: border, width: 1),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: mutedClr,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Clear and Add',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
              ],
            ),
          );
        },
      );

      if (shouldClear == true) {
        // Delete all items currently in cart
        final batch = firestore.batch();
        for (var doc in cartSnap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error handling multi-vendor cart check: $e');
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quantity pill widget (Left-aligned compact pill for sticky bottom bar)
// ─────────────────────────────────────────────────────────────────────────────

class _QuantityPill extends StatelessWidget {
  final int quantity;
  final bool isDark;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QuantityPill({
    required this.quantity,
    required this.isDark,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final fgColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Decrement
        GestureDetector(
          onTap: onDecrement,
          child: Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 1),
            ),
            child: Icon(Icons.remove, size: 18.sp, color: fgColor),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text(
            '$quantity',
            style: TextStyle(
              fontSize: AppTypography.font(16),
              fontWeight: FontWeight.bold,
              color: fgColor,
            ),
          ),
        ),
        // Increment
        GestureDetector(
          onTap: onIncrement,
          child: Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: purpleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add, size: 18.sp, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
