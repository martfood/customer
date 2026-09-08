import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'add_address_bottom_sheet.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  String? _selectedAddressId;

  Future<void> _setDefaultAddress(String addressId) async {
    final user = _auth.currentUser;
    if (user != null) {
      final batch = _firestore.batch();
      final addressRef = _firestore
          .collection('customers')
          .doc(user.uid)
          .collection('addresses');

      final allAddresses = await addressRef.get();
      for (var doc in allAddresses.docs) {
        if (doc.id == addressId) {
          batch.update(doc.reference, {'isDefault': true});
        } else {
          batch.update(doc.reference, {'isDefault': false});
        }
      }
      await batch.commit();
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('customers')
          .doc(user.uid)
          .collection('addresses')
          .doc(addressId)
          .delete();
    }
  }

  void _showAddressOptionsBottomSheet(String addressId, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (context) => Padding(
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
            Text(
              (data['title'] ?? 'Address').toString(),
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              (data['address'] ?? '').toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _setDefaultAddress(addressId);
              },
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text('Set as Default Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 54.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
                elevation: 0,
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _deleteAddress(addressId);
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Delete Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF27272A)
                    : const Color(0xFFF3F4F7),
                foregroundColor: Colors.red,
                minimumSize: Size(double.infinity, 54.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Please log in to view addresses',
            style: TextStyle(
              color: primaryTextColor,
              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

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
              border: Border.all(
                color: isDark ? Colors.grey[800]! : const Color(0xFFE9EAF0),
                width: 1,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back, color: purpleColor, size: 20.sp),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Delivery Address',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('customers')
            .doc(user.uid)
            .collection('addresses')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: purpleColor),
            );
          }

          final allDocs = snapshot.data!.docs;

          // Set default selected address ID from Firestore default if not set manually
          if (_selectedAddressId == null && allDocs.isNotEmpty) {
            final defaultDocs = allDocs.where(
              (doc) => (doc.data() as Map<String, dynamic>)['isDefault'] == true,
            );
            _selectedAddressId =
                defaultDocs.isNotEmpty ? defaultDocs.first.id : allDocs.first.id;
          }

          return SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
                    children: [
                      // Saved Addresses Header Row with Add Address Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Saved Addresses',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => showAddNewAddressBottomSheet(context: context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,
                                vertical: 10.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24.r),
                              ),
                            ),
                            child: Text(
                              'Add Address',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      if (allDocs.isEmpty)
                        _buildEmptyState(context)
                      else
                        ...List.generate(allDocs.length, (index) {
                          final doc = allDocs[index];
                          final docId = doc.id;
                          final data = doc.data() as Map<String, dynamic>;
                          final isSelected = _selectedAddressId == docId;
                          final isDefault = data['isDefault'] ?? false;
                          final title = (data['title'] ?? 'Home').toString();
                          final address = (data['address'] ?? '').toString();

                          final selectedCardBg = isDark
                              ? purpleColor.withValues(alpha: 0.18)
                              : const Color(0xFFECE3F8);

                          return Padding(
                            padding: EdgeInsets.only(bottom: 16.h),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedAddressId = docId;
                                  });
                                },
                                borderRadius: BorderRadius.circular(24.r),
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: isSelected ? selectedCardBg : cardBg,
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: isSelected
                                          ? purpleColor
                                          : borderColor,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 8.h),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title,
                                                    style: TextStyle(
                                                      color: primaryTextColor,
                                                      fontSize: AppTypography.font(
                                                        AppFontSizes.bodyLarge,
                                                      ),
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  SizedBox(height: 6.h),
                                                  Text(
                                                    address,
                                                    style: TextStyle(
                                                      color: mutedTextColor,
                                                      fontSize: AppTypography.font(
                                                        AppFontSizes.bodySmall,
                                                      ),
                                                      fontWeight: FontWeight.w500,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 12.w),
                                            Icon(
                                              isSelected || isDefault
                                                  ? Icons.check_circle
                                                  : Icons.circle_outlined,
                                              color: isSelected || isDefault
                                                  ? purpleColor
                                                  : AppTheme.hintColorFor(isDark),
                                              size: 22.sp,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          GestureDetector(
                                            onTap: () =>
                                                _showAddressOptionsBottomSheet(docId, data),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 22.w,
                                                vertical: 10.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: purpleColor,
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(20.r),
                                                  bottomRight: Radius.circular(24.r),
                                                ),
                                              ),
                                              child: Text(
                                                'Change Address',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: AppTypography.font(
                                                    AppFontSizes.bodySmall,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
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

                // Deliver to this Address Button
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
                      onPressed: () async {
                        final router = GoRouter.of(context);
                        if (_selectedAddressId != null) {
                          await _setDefaultAddress(_selectedAddressId!);
                        }
                        if (mounted) {
                          router.pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 56.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Deliver to this Address',
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

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 58.w,
            height: 58.w,
            decoration: BoxDecoration(
              color: purpleColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(
              Icons.location_on_outlined,
              color: purpleColor,
              size: 26.sp,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'No addresses saved yet',
            style: TextStyle(
              color: primaryTextColor,
              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Add a new address so your deliveries get to the right place quickly.',
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
    );
  }
}
