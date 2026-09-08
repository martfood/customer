import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class DeliverToScreen extends StatefulWidget {
  const DeliverToScreen({super.key});

  @override
  State<DeliverToScreen> createState() => _DeliverToScreenState();
}

class _DeliverToScreenState extends State<DeliverToScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            "Please log in to view addresses",
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: purpleColor),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Deliver to',
          style: TextStyle(
            color: purpleColor,
            fontSize: AppTypography.font(AppFontSizes.headlineMedium),
            fontWeight: FontWeight.bold,
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: purpleColor),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No addresses saved yet',
                    style: TextStyle(color: mutedTextColor),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () async {
                      final res = await context.push('/profile/address/add');
                      if (res is Map<String, dynamic> && context.mounted) {
                        context.pop(res);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Add Address'),
                  ),
                ],
              ),
            );
          }

          // Bound selected index range
          if (_selectedIndex >= docs.length) {
            _selectedIndex = 0;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.all(20.w),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => SizedBox(height: 16.h),
                  itemBuilder: (context, index) {
                    final addrDoc = docs[index];
                    final addr = addrDoc.data() as Map<String, dynamic>;
                    final isSelected = _selectedIndex == index;
                    final title = addr['title'] ?? 'Address';
                    final address = addr['address'] ?? '';
                    final isDefault = addr['isDefault'] ?? false;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = index),
                      child: Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(24.r),
                          boxShadow: null,
                          border: Border.all(
                            color: isSelected ? purpleColor : borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: purpleColor.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.location_on,
                                color: purpleColor,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      if (isDefault) ...[
                                        SizedBox(width: 8.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6.w,
                                            vertical: 2.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4.r),
                                          ),
                                          child: Text(
                                            'Default',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: AppTypography.font(AppFontSizes.caption),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    address,
                                    style: TextStyle(
                                      color: mutedTextColor,
                                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // ignore: deprecated_member_use
                            Radio<int>(
                              value: index,
                              // ignore: deprecated_member_use
                              groupValue: _selectedIndex,
                              activeColor: purpleColor,
                              // ignore: deprecated_member_use
                              onChanged: (val) =>
                                  setState(() => _selectedIndex = val!),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final res = await context.push('/profile/address/add');
                        if (res is Map<String, dynamic> && context.mounted) {
                          context.pop(res);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColor.withValues(alpha: 0.1),
                        foregroundColor: purpleColor,
                        minimumSize: Size(double.infinity, 56.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32.r),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Add New Address',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () {
                        final selectedDoc = docs[_selectedIndex];
                        final selectedData =
                            selectedDoc.data() as Map<String, dynamic>;
                        selectedData['id'] = selectedDoc.id;
                        context.pop(selectedData);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 56.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32.r),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Apply Address',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
