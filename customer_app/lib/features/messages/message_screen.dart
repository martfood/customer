import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/bottom_nav_bar.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (difference.inDays == 1 ||
        (now.day - date.day == 1 && date.month == now.month)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    } else {
      return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.lock,
                size: 48.sp,
                color: purpleColor,
              ),
              SizedBox(height: 16.h),
              Text(
                "Please log in to view messages",
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  elevation: 0,
                ),
                child: const Text('Log In'),
              ),
            ],
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
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : const Color(0xFF15161A)),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Messages',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Responsive.maxContainer(
          context: context,
          maxWidth: 750,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              // ── Search Bar Filter ──────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 16.h),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.search,
                        color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                        size: 20.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() => _searchQuery = val.trim().toLowerCase());
                          },
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search conversations...',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : const Color(0xFF6E7191),
                              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color:
                                isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                            size: 20.sp,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Active Chats Stream List ────────────────────────────────────────
              Expanded(
                child: _buildActiveChatsList(currentUser.uid, isDark, purpleColor),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MartFoodBottomNavBar(
        currentIndex: 4,
        onTap: (index) {
          if (index == 0) context.go('/home');
          if (index == 1) context.go('/search');
          if (index == 2) context.go('/orders');
          if (index == 3) context.go('/profile/customer-service');
          if (index == 4) context.go('/profile');
        },
      ),
    );
  }

  Widget _buildActiveChatsList(String userId, bool isDark, Color purpleColor) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('members', arrayContains: userId)
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
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: purpleColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.messageSquare,
                      size: 48.sp,
                      color: purpleColor,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'No Messages Yet',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.titleLarge),
                      color: primaryTextColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'When you place an order or message your rider, your active chats will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                      color: mutedTextColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        var chatList =
            docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

        // Client-side search filtering
        if (_searchQuery.isNotEmpty) {
          chatList = chatList.where((chat) {
            final riderName =
                (chat['riderName'] ?? '').toString().toLowerCase();
            final vendorName =
                (chat['vendorName'] ?? '').toString().toLowerCase();
            final lastMsg =
                (chat['lastMessage'] ?? '').toString().toLowerCase();
            return riderName.contains(_searchQuery) ||
                vendorName.contains(_searchQuery) ||
                lastMsg.contains(_searchQuery);
          }).toList();
        }

        chatList.sort((a, b) {
          final t1 = a['lastMessageTime'] as Timestamp?;
          final t2 = b['lastMessageTime'] as Timestamp?;
          if (t1 == null) return 1;
          if (t2 == null) return -1;
          return t2.compareTo(t1);
        });

        if (chatList.isEmpty) {
          return Center(
            child: Text(
              'No conversations match "$_searchQuery"',
              style: TextStyle(
                color: mutedTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          itemCount: chatList.length,
          separatorBuilder: (context, index) => SizedBox(height: 10.h),
          itemBuilder: (context, index) {
            final chat = chatList[index];
            final members = (chat['members'] as List<dynamic>?) ?? [];
            final otherMemberId = members
                .firstWhere((m) => m.toString() != userId, orElse: () => '')
                .toString();
            final riderId =
                (chat['riderId'] ?? chat['driverId'] ?? otherMemberId).toString();
            final displayName = chat['riderName'] ??
                chat['vendorName'] ??
                'Rider / Delivery Partner';
            final photoUrl = chat['riderPhoto'] ?? chat['vendorPhoto'] ?? '';
            final lastMsg = chat['lastMessage'] ?? 'No messages yet';
            final lastTime = chat['lastMessageTime'] as Timestamp?;
            final unread =
                (chat['unreadCount'] as Map<String, dynamic>?)?[userId] ?? 0;
            final formattedTime = _formatTimestamp(lastTime);

            return Material(
              color: cardBg,
              borderRadius: BorderRadius.circular(18.r),
              child: InkWell(
                onTap: () => context.push(
                  '/conversation/$riderId',
                  extra: {
                    'riderName': displayName,
                    'riderPhotoUrl': photoUrl,
                  },
                ),
                borderRadius: BorderRadius.circular(18.r),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      // Avatar with Online Badge Indicator
                      Stack(
                        children: [
                          Container(
                            width: 52.w,
                            height: 52.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: purpleColor.withValues(alpha: 0.12),
                              image: photoUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(photoUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: photoUrl.isEmpty
                                ? Icon(
                                    LucideIcons.user,
                                    color: purpleColor,
                                    size: 24.sp,
                                  )
                                : null,
                          ),
                          if (riderId.isNotEmpty)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: _RiderOnlineBadge(
                                riderId: riderId,
                                cardBg: cardBg,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: 14.w),

                      // Name and Message Preview
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize:
                                    AppTypography.font(AppFontSizes.bodyLarge),
                                fontWeight: unread > 0
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              lastMsg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppTypography.font(
                                    AppFontSizes.bodySmall + 1),
                                color: unread > 0
                                    ? primaryTextColor
                                    : mutedTextColor,
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),

                      // Time & Unread Badge Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize:
                                  AppTypography.font(AppFontSizes.caption),
                              color: unread > 0 ? purpleColor : mutedTextColor,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          if (unread > 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: purpleColor,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                '$unread',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize:
                                      AppTypography.font(AppFontSizes.caption),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          else
                            Icon(
                              LucideIcons.checkCheck,
                              size: 16.sp,
                              color: purpleColor.withValues(alpha: 0.6),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RiderOnlineBadge extends StatelessWidget {
  final String riderId;
  final Color cardBg;

  const _RiderOnlineBadge({
    required this.riderId,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    if (riderId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('riders')
          .doc(riderId)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic>? data;
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          data = snapshot.data!.data() as Map<String, dynamic>?;
        }

        if (data == null) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(riderId)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData ||
                  userSnapshot.data == null ||
                  !userSnapshot.data!.exists) {
                return const SizedBox.shrink();
              }
              final uData = userSnapshot.data!.data() as Map<String, dynamic>?;
              return _renderDot(uData, cardBg);
            },
          );
        }

        return _renderDot(data, cardBg);
      },
    );
  }

  Widget _renderDot(Map<String, dynamic>? data, Color cardBg) {
    if (data == null) return const SizedBox.shrink();

    final status = (data['status'] ?? '').toString().toLowerCase().trim();
    final isOnlineFlag = data['isOnline'] == true ||
        data['isOnline']?.toString().toLowerCase() == 'true';

    final bool isOnline =
        (status == 'online' || isOnlineFlag) && status != 'offline';

    if (!isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 13.w,
      height: 13.w,
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        shape: BoxShape.circle,
        border: Border.all(
          color: cardBg,
          width: 2,
        ),
      ),
    );
  }
}
