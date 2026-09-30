import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Bottom navigation for the MartFood rider app (Home, Orders, Chat, Wallet, Profile).
class RiderBottomNavBar extends StatelessWidget {
  /// Currently selected tab index (0–4).
  final int currentIndex;

  /// Called when a tab is selected.
  final ValueChanged<int> onTap;

  /// Optional explicit unread message/chat count override.
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

  Widget _buildBadgedIcon(Widget iconWidget, int count, Color badgeColor, Color surfaceColor) {
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
            padding: EdgeInsets.symmetric(
              horizontal: count > 9 ? 5 : 4,
              vertical: 1.5,
            ),
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: surfaceColor, width: 1.5),
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
                  fontSize: AppTypography.font(AppFontSizes.caption),
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _getChatUnreadCount(Map<String, dynamic> data, String userId) {
    int unread = 0;
    final rawCounts = data['unreadCount'];
    if (rawCounts is Map) {
      final userVal = rawCounts[userId];
      if (userVal is num && userVal > 0) {
        unread = math.max(unread, userVal.toInt());
      } else if (userVal is String) {
        final parsed = int.tryParse(userVal) ?? 0;
        if (parsed > 0) unread = math.max(unread, parsed);
      }

      final riderId = data['riderId']?.toString();
      if (riderId == null || riderId == userId || riderId.isEmpty) {
        final roleVal = rawCounts['rider_unread'];
        if (roleVal is num && roleVal > 0) {
          unread = math.max(unread, roleVal.toInt());
        } else if (roleVal is String) {
          final parsed = int.tryParse(roleVal) ?? 0;
          if (parsed > 0) unread = math.max(unread, parsed);
        }
      }
    } else if (rawCounts is num && rawCounts > 0) {
      final lastSenderId = data['lastSenderId']?.toString() ?? data['senderId']?.toString();
      if (lastSenderId != userId) {
        unread = math.max(unread, rawCounts.toInt());
      }
    }

    final topRider = data['rider_unread'];
    if (topRider is num && topRider > 0) {
      unread = math.max(unread, topRider.toInt());
    }

    final topUid = data['unreadCount_$userId'] ?? data['unread_$userId'];
    if (topUid is num && topUid > 0) {
      unread = math.max(unread, topUid.toInt());
    }

    return unread;
  }

  @override
  Widget build(BuildContext context) {
    if (unreadMessageCount != null) {
      return _buildNavBar(context, unreadMessageCount!);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        final currentUser = authSnapshot.data ?? FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          return _buildNavBar(context, 0);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('members', arrayContains: currentUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            int unreadChatsCount = 0;
            if (snapshot.hasData && snapshot.data != null) {
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>?;
                if (data != null) {
                  final unread = _getChatUnreadCount(data, currentUser.uid);
                  if (unread > 0) {
                    unreadChatsCount++;
                  }
                }
              }
            }
            return _buildNavBar(context, unreadChatsCount);
          },
        );
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
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: _buildBadgedIcon(
              _buildNavIcon(iconName: 'message', isSelected: false),
              unreadCount,
              selectedColor,
              surfaceColor,
            ),
            activeIcon: _buildBadgedIcon(
              _buildNavIcon(iconName: 'message', isSelected: true),
              unreadCount,
              selectedColor,
              surfaceColor,
            ),
            label: 'Chat',
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
