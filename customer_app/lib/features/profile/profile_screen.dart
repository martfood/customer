import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/bottom_nav_bar.dart';
import '../../core/widgets/guest_auth_prompt_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final cardBorderColor =
        isDark ? AppTheme.darkBorder : const Color(0xFFF0E6FF);
    final dividerColor =
        isDark ? AppTheme.darkBorder : const Color(0xFFF5EEFF);
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: backgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: Text(
            'Profile',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: AppTypography.font(AppFontSizes.displaySmall),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: const GuestPlaceholderView(
          icon: LucideIcons.user,
          title: 'Guest Account',
          subtitle: 'Sign in or register an account to access your profile, saved addresses, and payment methods.',
          primaryButtonText: 'Sign In / Register',
        ),
        bottomNavigationBar: MartFoodBottomNavBar(
          currentIndex: 4,
          onTap: (index) {
            if (index == 0) context.go('/home');
            if (index == 1) context.go('/search');
            if (index == 2) context.go('/orders');
            if (index == 3) context.go('/profile/customer-service');
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('customers').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            final userData =
                snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final fullName = (userData['fullName'] ?? 'User').toString();
            final profilePic = (userData['profilePic'] ?? '').toString();

            return Responsive.maxContainer(
              context: context,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
                child: Column(
                  children: [
                    // ── Centered Avatar & Full Name ──────────────────────────
                    Center(
                      child: Column(
                        children: [
                          SizedBox(height: 12.h),
                          CircleAvatar(
                            radius: 48.r,
                            backgroundColor: isDark
                                ? const Color(0xFF27272A)
                                : const Color(0xFFF3F3F5),
                            backgroundImage: profilePic.isNotEmpty
                                ? NetworkImage(profilePic)
                                : null,
                            child: profilePic.isEmpty
                                ? Icon(
                                    LucideIcons.user,
                                    size: 40.sp,
                                    color: AppTheme.primaryPurpleFor(isDark),
                                  )
                                : null,
                          ),
                          SizedBox(height: 14.h),
                          Text(
                            fullName.isNotEmpty ? fullName : 'MartFood User',
                            style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.headlineLarge),
                              fontWeight: FontWeight.w900,
                              color: primaryTextColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 28.h),
                        ],
                      ),
                    ),

                    // ── Group 1 Card: Profile details, address, favorite restaurants, wallet ──
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: cardBorderColor, width: 1),
                      ),
                      child: Column(
                        children: [
                          _buildProfileRowItem(
                            context: context,
                            svgAsset:
                                'assets/icons/bottom_nav_bar/profile_filled.svg',
                            title: 'Profile details',
                            onTap: () => context.push('/profile/edit'),
                            isDark: isDark,
                          ),
                          Divider(
                              height: 1,
                              color: dividerColor,
                              indent: 60.w,
                              endIndent: 16.w),
                          _buildProfileRowItem(
                            context: context,
                            icon: Icons.location_on,
                            title: 'Address',
                            onTap: () => context.push('/profile/address'),
                            isDark: isDark,
                          ),
                          Divider(
                              height: 1,
                              color: dividerColor,
                              indent: 60.w,
                              endIndent: 16.w),
                          _buildProfileRowItem(
                            context: context,
                            icon: Icons.favorite,
                            title: 'Favorite restaurants',
                            onTap: () => context.push('/profile/favorites'),
                            isDark: isDark,
                          ),
                          Divider(
                              height: 1,
                              color: dividerColor,
                              indent: 60.w,
                              endIndent: 16.w),
                          _buildProfileRowItem(
                            context: context,
                            icon: Icons.account_balance_wallet,
                            title: 'Wallet',
                            onTap: () => context.push('/wallet'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // ── Group 2 Card: message, settings, help/faqs, legal ──
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: cardBorderColor, width: 1),
                      ),
                      child: Column(
                        children: [
                          _buildProfileRowItem(
                            context: context,
                            icon: Icons.chat_bubble,
                            title: 'Message',
                            onTap: () => context.push('/messages'),
                            isDark: isDark,
                            trailing:
                                _buildMessagesUnreadBadge(user.uid, isDark),
                          ),
                          Divider(
                              height: 1,
                              color: dividerColor,
                              indent: 60.w,
                              endIndent: 16.w),
                          _buildProfileRowItem(
                            context: context,
                            icon: Icons.settings,
                            title: 'Settings',
                            onTap: () => context.push('/profile/appearance'),
                            isDark: isDark,
                          ),
                          Divider(
                              height: 1,
                              color: dividerColor,
                              indent: 60.w,
                              endIndent: 16.w),
                          _buildProfileRowItem(
                            context: context,
                            icon: Icons.help,
                            title: 'Help/FAQs',
                            onTap: () => context.push('/profile/help-center'),
                            isDark: isDark,
                          ),
                          Divider(
                              height: 1,
                              color: dividerColor,
                              indent: 60.w,
                              endIndent: 16.w),
                          _buildProfileRowItem(
                            context: context,
                            icon: Icons.gavel,
                            title: 'Legal',
                            onTap: () => context.push('/profile/legal'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 36.h),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: MartFoodBottomNavBar(
        currentIndex: 4,
        onTap: (index) {
          if (index == 0) context.go('/home');
          if (index == 1) context.go('/search');
          if (index == 2) context.go('/orders');
          if (index == 3) context.go('/profile/customer-service');
        },
      ),
    );
  }

  Widget _buildMessagesUnreadBadge(String userId, bool isDark) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('members', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        int totalUnread = 0;
        if (snapshot.hasData && snapshot.data != null) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null) {
              final counts = data['unreadCount'] as Map<String, dynamic>?;
              if (counts != null && counts.containsKey(userId)) {
                final unread = counts[userId];
                if (unread is int) totalUnread += unread;
                if (unread is num) totalUnread += unread.toInt();
              }
            }
          }
        }

        if (totalUnread <= 0) return const SizedBox.shrink();

        return Container(
          margin: EdgeInsets.only(right: 8.w),
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: purpleColor,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            totalUnread > 99 ? '99+' : '$totalUnread',
            style: TextStyle(
              color: Colors.white,
              fontSize: AppTypography.font(AppFontSizes.caption),
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileRowItem({
    required BuildContext context,
    IconData? icon,
    String? svgAsset,
    Widget? customIcon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    Color? textColor,
    Color? iconColor,
    Widget? trailing,
  }) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final purpleAccent = AppTheme.primaryPurpleFor(isDark);
    final pillBg = isDark
        ? const Color(0xFF27272A)
        : (iconColor != null
            ? iconColor.withValues(alpha: 0.1)
            : const Color(0xFFF6F2FC));
    final iconClr = iconColor ?? purpleAccent;

    Widget iconWidget;
    if (customIcon != null) {
      iconWidget = customIcon;
    } else if (svgAsset != null) {
      iconWidget = SvgPicture.asset(
        svgAsset,
        width: 20.w,
        height: 20.w,
        colorFilter: ColorFilter.mode(iconClr, BlendMode.srcIn),
      );
    } else {
      iconWidget = Icon(
        icon,
        size: 20.sp,
        color: iconClr,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: pillBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: iconWidget,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w600,
                    color: textColor ?? primaryTextColor,
                  ),
                ),
              ),
              if (trailing != null) trailing,
              Icon(
                LucideIcons.chevronRight,
                size: 18.sp,
                color: AppTheme.hintColorFor(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
