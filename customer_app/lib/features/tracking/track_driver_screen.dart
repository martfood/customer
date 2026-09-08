import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/verification_badge.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class TrackDriverScreen extends StatefulWidget {
  const TrackDriverScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<TrackDriverScreen> createState() => _TrackDriverScreenState();
}

class _TrackDriverScreenState extends State<TrackDriverScreen> {
  bool _isTimelineExpanded = true;

  static const List<Map<String, String>> _steps = [
    {
      'title': 'Order Received',
      'subtitle': 'Waiting for vendor to confirm your order',
    },
    {
      'title': 'Preparing your order',
      'subtitle': 'The vendor is getting your order ready',
    },
    {
      'title': 'Rider accepted your order',
      'subtitle': 'Your order has been assigned to a rider',
    },
    {
      'title': 'Rider at restaurant',
      'subtitle': 'Your rider is picking up the order',
    },
    {
      'title': 'Order in transit',
      'subtitle': 'Your rider is on the way to your location',
    },
    {
      'title': 'Order has arrived',
      'subtitle': 'Your order has been delivered successfully',
    },
  ];

  int _currentStepFromStatus(String status) {
    switch (status) {
      case 'pending':
      case 'pending_verification':
        return 0;
      case 'preparing':
        return 1;
      case 'accepted':
      case 'rider_assigned':
        return 2;
      case 'at_restaurant':
        return 3;
      case 'in_transit':
        return 4;
      case 'arrived':
      case 'ready':
      case 'delivered':
        return 5;
      default:
        return 0;
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatCurrency(double value) {
    final formatted = value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '₦$formatted';
  }

  String _formatEstimatedTime(dynamic createdAtRaw) {
    DateTime start;
    if (createdAtRaw is Timestamp) {
      start = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      start = createdAtRaw;
    } else {
      start = DateTime.now();
    }

    final etaMin = start.add(const Duration(minutes: 25));
    final etaMax = start.add(const Duration(minutes: 45));

    final timeFmt = DateFormat('hh:mm a');
    return '${timeFmt.format(etaMin)} - ${timeFmt.format(etaMax)}';
  }

  String _formatAddress(dynamic rawAddress) {
    if (rawAddress == null) return 'Delivery Location';
    if (rawAddress is Map) {
      final street = (rawAddress['street'] ?? rawAddress['address'] ?? rawAddress['addressLine1'] ?? '').toString();
      final city = (rawAddress['city'] ?? rawAddress['state'] ?? '').toString();
      if (street.isNotEmpty && city.isNotEmpty) return '$street, $city';
      if (street.isNotEmpty) return street;
      if (city.isNotEmpty) return city;
      final vals = rawAddress.values.where((v) => v != null && v.toString().isNotEmpty && !v.toString().startsWith('{')).join(', ');
      return vals.isNotEmpty ? vals : 'Delivery Location';
    }
    var str = rawAddress.toString().trim();
    if (str.startsWith('{')) {
      str = str.replaceAll(RegExp(r'^\{|\}$'), '');
      str = str.replaceAll(RegExp(r'\b\w+:\s*'), '');
    }
    return str.isNotEmpty ? str : 'Delivery Location';
  }

  void _showRiderUnassignedBottomSheet(BuildContext context, {required bool isCall}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
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
            SizedBox(height: 24.h),
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                color: purpleColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.notebook,
                color: purpleColor,
                size: 38.sp,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Rider Not Assigned Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.headlineLarge),
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              isCall
                  ? 'You will be able to call your delivery rider directly as soon as one has been assigned to your order.'
                  : 'You will be able to message and chat with your delivery rider as soon as one has been assigned to your order.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                color: mutedTextColor,
                height: 1.5,
              ),
            ),
            SizedBox(height: 28.h),
            ElevatedButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 54.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Got It',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.all(8.w),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back, color: purpleColor, size: 20.sp),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Text(
          'Track Order',
          style: TextStyle(
            color: purpleColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: widget.orderId.isEmpty
          ? const Center(child: Text('No order selected for tracking'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .doc(widget.orderId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  );
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(
                    child: Text('This order could not be found.'),
                  );
                }

                final order = snapshot.data!.data()! as Map<String, dynamic>;
                final status = (order['status'] ?? 'pending').toString();
                final currentStep = _currentStepFromStatus(status);
                final deliveryPin = (order['deliveryPin'] ?? '----').toString();
                final pinDigits = deliveryPin.padLeft(4, '0').split('');
                final etaText = _formatEstimatedTime(order['createdAt']);

                final riderName = (order['riderName'] ?? '').toString();
                final riderPhotoUrl = (order['riderPhotoUrl'] ?? '').toString();
                final riderPhone = (order['riderPhone'] ?? '').toString();
                final riderId = (order['riderId'] ?? '').toString();

                final vendorName = (order['restaurantName'] ?? order['vendorName'] ?? 'Store').toString();
                final deliveryAddress = _formatAddress(order['deliveryAddress'] ?? order['address'] ?? order['customerAddress']);

                final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
                final subtotal = items.fold<double>(
                  0.0,
                  (acc, item) => acc + (_toDouble(item['price']) * (item['quantity'] ?? 1)),
                );
                final deliveryFee = _toDouble(order['deliveryFee']);
                final platformFee = _toDouble(order['platformFee']);
                final totalCost = _toDouble(order['total']);
                final paymentMethod = (order['paymentMethod'] is Map)
                    ? (order['paymentMethod']['label'] ?? 'Wallet').toString()
                    : (order['paymentMethod'] ?? 'Wallet').toString();

                return SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Estimated Arrival Time ────────────────────
                              Text(
                                'Estimated Arrival Time',
                                style: TextStyle(
                                  fontSize: AppTypography.font(16),
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                etaText,
                                style: TextStyle(
                                  fontSize: AppTypography.font(13),
                                  color: mutedTextColor,
                                ),
                              ),
                              SizedBox(height: 16.h),
                              Divider(color: borderColor, height: 1),
                              SizedBox(height: 16.h),

                              // ── Delivery PIN Row ──────────────────────────
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Delivery PIN',
                                          style: TextStyle(
                                            fontSize: AppTypography.font(AppFontSizes.caption),
                                            color: mutedTextColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          'Show this code\nto your rider',
                                          style: TextStyle(
                                            fontSize: AppTypography.font(14),
                                            fontWeight: FontWeight.bold,
                                            color: primaryTextColor,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: pinDigits.map((digit) {
                                      return Container(
                                        margin: EdgeInsets.only(left: 8.w),
                                        width: 44.w,
                                        height: 44.w,
                                        decoration: BoxDecoration(
                                          color: isDark ? AppTheme.darkSurface : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(12.r),
                                          border: Border.all(color: borderColor, width: 1),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          digit,
                                          style: TextStyle(
                                            fontSize: AppTypography.font(18),
                                            fontWeight: FontWeight.w800,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              Divider(color: borderColor, height: 1),
                              SizedBox(height: 16.h),

                              // ── Rider Contact Box ────────────────────────
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(color: borderColor, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22.r,
                                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                      backgroundImage: riderPhotoUrl.isNotEmpty
                                          ? CachedNetworkImageProvider(riderPhotoUrl)
                                          : null,
                                      child: riderPhotoUrl.isEmpty
                                          ? Icon(LucideIcons.user, color: purpleColor, size: 20.sp)
                                          : null,
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            riderName.isNotEmpty ? riderName : 'Assigning Rider...',
                                            style: TextStyle(
                                              fontSize: AppTypography.font(14),
                                              fontWeight: FontWeight.bold,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            'Your Rider',
                                            style: TextStyle(
                                              fontSize: AppTypography.font(12),
                                              color: mutedTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Chat Button
                                    GestureDetector(
                                      onTap: () {
                                        if (riderId.isNotEmpty) {
                                          context.push(
                                            '/conversation/$riderId',
                                            extra: {
                                              'riderName': riderName,
                                              'riderPhotoUrl': riderPhotoUrl,
                                            },
                                          );
                                        } else {
                                          _showRiderUnassignedBottomSheet(context, isCall: false);
                                        }
                                      },
                                      child: Container(
                                        width: 36.w,
                                        height: 36.w,
                                        decoration: BoxDecoration(
                                          color: purpleColor.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(LucideIcons.mail, color: purpleColor, size: 18.sp),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    // Call Button
                                    GestureDetector(
                                      onTap: () async {
                                        if (riderPhone.isNotEmpty) {
                                          final uri = Uri(scheme: 'tel', path: riderPhone);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri);
                                          }
                                        } else {
                                          _showRiderUnassignedBottomSheet(context, isCall: true);
                                        }
                                      },
                                      child: Container(
                                        width: 36.w,
                                        height: 36.w,
                                        decoration: BoxDecoration(
                                          color: purpleColor.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(LucideIcons.phone, color: purpleColor, size: 18.sp),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // ── Route Origin & Destination Card ─────────
                              Container(
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(color: borderColor, width: 1),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(LucideIcons.disc, color: purpleColor, size: 18.sp),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  vendorName,
                                                  style: TextStyle(
                                                    fontSize: AppTypography.font(14),
                                                    fontWeight: FontWeight.w600,
                                                    color: primaryTextColor,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              SizedBox(width: 6.w),
                                              VendorVerificationBadge(
                                                vendorId: (order['vendorId'] ?? order['restaurantId'] ?? '').toString(),
                                                fallbackData: order,
                                                size: 16.sp,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.h),
                                      child: Divider(color: borderColor, height: 1),
                                    ),
                                    Row(
                                      children: [
                                        Icon(LucideIcons.mapPin, color: mutedTextColor, size: 18.sp),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Text(
                                            deliveryAddress,
                                            style: TextStyle(
                                              fontSize: AppTypography.font(13),
                                              color: mutedTextColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 20.h),

                              // ── View Order Timeline Accordion Header ──────
                              GestureDetector(
                                onTap: () => setState(() => _isTimelineExpanded = !_isTimelineExpanded),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8.w,
                                          height: 8.w,
                                          decoration: BoxDecoration(
                                            color: purpleColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          'View Order timeline',
                                          style: TextStyle(
                                            fontSize: AppTypography.font(15),
                                            fontWeight: FontWeight.bold,
                                            color: purpleColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      _isTimelineExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                                      color: purpleColor,
                                      size: 20.sp,
                                    ),
                                  ],
                                ),
                              ),
                              if (_isTimelineExpanded) ...[
                                SizedBox(height: 16.h),
                                _buildStatusTimeline(
                                  context,
                                  isDark,
                                  currentStep,
                                  primaryTextColor,
                                  mutedTextColor,
                                  purpleColor,
                                ),
                              ],
                              SizedBox(height: 24.h),
                              Divider(color: borderColor, height: 1),
                              SizedBox(height: 24.h),

                              // ── Order Summary ─────────────────────────────
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order summary',
                                    style: TextStyle(
                                      fontSize: AppTypography.font(16),
                                      fontWeight: FontWeight.bold,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    '#${widget.orderId.substring(0, widget.orderId.length > 8 ? 8 : widget.orderId.length).toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: AppTypography.font(14),
                                      fontWeight: FontWeight.bold,
                                      color: purpleColor,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),

                              // Items list
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                                itemBuilder: (context, idx) {
                                  final item = items[idx];
                                  final title = (item['title'] ?? item['name'] ?? 'Product').toString();
                                  final qty = item['quantity'] ?? 1;
                                  final photoUrl = (item['imageUrl'] ?? item['photoUrl'] ?? '').toString();
                                  final priceVal = _toDouble(item['price']) * qty;

                                  return Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10.r),
                                        child: photoUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: photoUrl,
                                                width: 50.w,
                                                height: 50.w,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => Container(color: Colors.grey[200]),
                                                errorWidget: (_, __, ___) => Container(
                                                  color: purpleColor.withValues(alpha: 0.1),
                                                  child: Icon(LucideIcons.utensils, color: purpleColor, size: 20.sp),
                                                ),
                                              )
                                            : Container(
                                                width: 50.w,
                                                height: 50.w,
                                                color: purpleColor.withValues(alpha: 0.1),
                                                child: Icon(LucideIcons.utensils, color: purpleColor, size: 20.sp),
                                              ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Text(
                                          '$title X $qty',
                                          style: TextStyle(
                                            fontSize: AppTypography.font(14),
                                            fontWeight: FontWeight.w600,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(priceVal),
                                        style: TextStyle(
                                          fontSize: AppTypography.font(14),
                                          fontWeight: FontWeight.bold,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              SizedBox(height: 20.h),

                              // Financial Breakdown
                              _buildSummaryRow('Sub-total', _formatCurrency(subtotal), primaryTextColor, mutedTextColor),
                              SizedBox(height: 10.h),
                              _buildSummaryRow('Delivery Fee', _formatCurrency(deliveryFee), primaryTextColor, mutedTextColor),
                              SizedBox(height: 10.h),
                              _buildSummaryRow('Platform Fee', _formatCurrency(platformFee), primaryTextColor, mutedTextColor),
                              SizedBox(height: 10.h),
                              _buildSummaryRow(
                                'Total',
                                _formatCurrency(totalCost),
                                primaryTextColor,
                                mutedTextColor,
                                isBold: true,
                              ),
                              SizedBox(height: 10.h),
                              _buildSummaryRow('Payment Method', paymentMethod, primaryTextColor, mutedTextColor),
                            ],
                          ),
                        ),
                      ),
                      if (status == 'delivered')
                        Container(
                          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            border: Border(
                              top: BorderSide(
                                color: borderColor,
                              ),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => context.push('/rate_rider', extra: {
                                  'orderId': widget.orderId,
                                  'riderId': order['riderId'] ?? '',
                                  'riderName': order['riderName'] ?? 'Rider',
                                  'riderPhotoUrl': order['riderPhotoUrl'] ?? '',
                                }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: purpleColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 54.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('Rate Rider'),
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

  Widget _buildSummaryRow(
    String label,
    String value,
    Color primaryTextColor,
    Color mutedTextColor, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? primaryTextColor : mutedTextColor,
            fontSize: AppTypography.font(14),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: primaryTextColor,
            fontSize: AppTypography.font(14),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTimeline(
    BuildContext context,
    bool isDark,
    int currentStep,
    Color primaryTextColor,
    Color mutedTextColor,
    Color purpleColor,
  ) {
    return Column(
      children: List.generate(
        _steps.length,
        (index) => _buildTimelineStep(context, index, isDark, currentStep, primaryTextColor, mutedTextColor, purpleColor),
      ),
    );
  }

  Widget _buildTimelineStep(
    BuildContext context,
    int index,
    bool isDark,
    int currentStep,
    Color primaryTextColor,
    Color mutedTextColor,
    Color purpleColor,
  ) {
    final isCompleted = index < currentStep;
    final isActive = index == currentStep;
    final isLast = index == _steps.length - 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30.w,
            child: Column(
              children: [
                Container(
                  width: 20.w,
                  height: 20.w,
                  margin: EdgeInsets.only(top: 2.h),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive ? purpleColor : (isDark ? Colors.grey[800] : Colors.grey[300]),
                      shape: BoxShape.circle,
                      border: isActive
                          ? Border.all(color: isDark ? AppTheme.darkSurface : Colors.white, width: 3)
                          : null,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.w,
                      margin: EdgeInsets.symmetric(vertical: 2.h),
                      color: isCompleted
                          ? purpleColor
                          : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _steps[index]['title']!,
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      fontWeight: (isCompleted || isActive) ? FontWeight.bold : FontWeight.w500,
                      color: (isCompleted || isActive) ? purpleColor : mutedTextColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _steps[index]['subtitle']!,
                    style: TextStyle(
                      fontSize: AppTypography.font(12),
                      color: mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
      stream: FirebaseFirestore.instance.collection('vendors').doc(vendorId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final vendorData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final bpComplete = vendorData['businessProfileComplete']?.toString() == 'true';
          final physicalVerification = vendorData['physicalVerification'];
          final physicalVerified = (physicalVerification is Map)
              ? physicalVerification['status']?.toString() == 'verified'
              : false;
          final docComplete = vendorData['verificationDocumentsComplete']?.toString() == 'true';

          if (physicalVerified || docComplete || bpComplete) {
            return VerificationBadge(vendorData: vendorData, size: size);
          }

          final isVerified = vendorData['isVerified'] == true ||
              vendorData['isVerified']?.toString() == 'true' ||
              vendorData['isVendorVerified'] == true;
          if (isVerified) {
            return Icon(Icons.verified_rounded, color: const Color(0xFF34C759), size: size);
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
    final bpComplete = vendorMap['businessProfileComplete']?.toString() == 'true';
    final physicalVerification = vendorMap['physicalVerification'];
    final physicalVerified = (physicalVerification is Map)
        ? physicalVerification['status']?.toString() == 'verified'
        : false;
    final docComplete = vendorMap['verificationDocumentsComplete']?.toString() == 'true';

    if (physicalVerified || docComplete || bpComplete) {
      return VerificationBadge(vendorData: vendorMap, size: size);
    }

    return Icon(Icons.verified_rounded, color: const Color(0xFF34C759), size: size);
  }
}
