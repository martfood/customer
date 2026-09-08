import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Bottom navigation for the MartFood rider app (Home, Orders, Messages, Wallet, Profile).
class RiderBottomNavBar extends StatelessWidget {
  /// Currently selected tab index (0–4).
  final int currentIndex;

  /// Called when a tab is selected.
  final ValueChanged<int> onTap;

  /// Optional explicit unread message count override.
  final int? unreadMessageCount;

  const RiderBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadMessageCount,
  });

  Widget _buildNavIcon({
    required String iconName,
    required bool isSelected,
  }) {
    final folder = isSelected ? 'purple' : 'grey';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Image.asset(
        'lib/assets/icon/bottom_nav_bar/$folder/$iconName.png',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
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
          right: -6,
          top: -3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1),
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Center(
              child: Text(
                badgeText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppTypography.font(11.5),
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
    final unselectedColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

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
          fontWeight: FontWeight.w600,
        ),
        items: [
          BottomNavigationBarItem(
            icon: _buildNavIcon(iconName: 'home', isSelected: false),
            activeIcon: _buildNavIcon(iconName: 'home', isSelected: true),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(iconName: 'order', isSelected: false),
            activeIcon: _buildNavIcon(iconName: 'order', isSelected: true),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: _buildBadgedIcon(
              _buildNavIcon(iconName: 'message', isSelected: false),
              unreadCount,
              selectedColor,
            ),
            activeIcon: _buildBadgedIcon(
              _buildNavIcon(iconName: 'message', isSelected: true),
              unreadCount,
              selectedColor,
            ),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(iconName: 'wallet', isSelected: false),
            activeIcon: _buildNavIcon(iconName: 'wallet', isSelected: true),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(iconName: 'profile', isSelected: false),
            activeIcon: _buildNavIcon(iconName: 'profile', isSelected: true),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
