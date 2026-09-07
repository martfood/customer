import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theme/app_theme.dart';

class MartFoodBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int? unreadMessageCount;

  const MartFoodBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadMessageCount,
  });

  Widget _buildSvgIcon(String assetName, Color? color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: SvgPicture.asset(
        'assets/icons/bottom_nav_bar/$assetName',
        width: 22.w,
        height: 22.w,
        colorFilter:
            color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
      ),
    );
  }

  Widget _buildBadgedIcon(Widget iconWidget, int count, Color badgeColor) {
    if (count <= 0) return iconWidget;

    final badgeText = count > 99 ? '99+' : '$count';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          right: -6.w,
          top: -3.h,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Colors.white, width: 1),
            ),
            constraints: BoxConstraints(
              minWidth: 16.w,
              minHeight: 16.w,
            ),
            child: Center(
              child: Text(
                badgeText,
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
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (unreadMessageCount != null || currentUser == null) {
      return _buildNavBar(context, unreadMessageCount ?? 0);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('members', arrayContains: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int totalUnread = 0;
        if (snapshot.hasData && snapshot.data != null) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null) {
              final counts = data['unreadCount'] as Map<String, dynamic>?;
              if (counts != null && counts.containsKey(currentUser.uid)) {
                final unread = counts[currentUser.uid];
                if (unread is int) totalUnread += unread;
                if (unread is num) totalUnread += unread.toInt();
              }
            }
          }
        }
        return _buildNavBar(context, totalUnread);
      },
    );
  }

  Widget _buildNavBar(BuildContext context, int unreadCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final selectedColor = AppTheme.primaryPurpleFor(isDark);
    final unselectedColor =
        isDark ? Colors.grey[500]! : const Color(0xFF6E7191);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: surfaceColor,
        selectedItemColor: selectedColor,
        unselectedItemColor: unselectedColor,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          fontSize: AppTypography.font(AppFontSizes.bodySmall),
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: AppTypography.font(AppFontSizes.bodySmall),
          fontWeight: FontWeight.w500,
        ),
        items: [
          BottomNavigationBarItem(
            icon: _buildSvgIcon('home.svg', unselectedColor),
            activeIcon: _buildSvgIcon('home_filled.svg', selectedColor),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _buildSvgIcon('search.svg', unselectedColor),
            activeIcon: _buildSvgIcon('search_filled.svg', selectedColor),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: _buildSvgIcon('order.svg', unselectedColor),
            activeIcon: _buildSvgIcon('order_filled.svg', selectedColor),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: _buildSvgIcon('support.svg', unselectedColor),
            activeIcon: _buildSvgIcon('support_filled.svg', selectedColor),
            label: 'Support',
          ),
          BottomNavigationBarItem(
            icon: _buildBadgedIcon(
              _buildSvgIcon('profile.svg', unselectedColor),
              unreadCount,
              selectedColor,
            ),
            activeIcon: _buildBadgedIcon(
              _buildSvgIcon('profile_filled.svg', selectedColor),
              unreadCount,
              selectedColor,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
