import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer_app/core/services/notification_service.dart';

class ConversationScreen extends StatefulWidget {
  final String riderId;
  final String? riderName;
  final String? riderPhotoUrl;

  const ConversationScreen({
    super.key,
    required this.riderId,
    this.riderName,
    this.riderPhotoUrl,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String _riderName = 'Rider';
  String _riderPhoto = '';

  @override
  void initState() {
    super.initState();
    NotificationService.activeChatUserId = widget.riderId;
    if (widget.riderName != null && widget.riderName!.trim().isNotEmpty) {
      _riderName = widget.riderName!.trim();
    }
    if (widget.riderPhotoUrl != null && widget.riderPhotoUrl!.trim().isNotEmpty) {
      _riderPhoto = widget.riderPhotoUrl!.trim();
    }
    _loadMetadata();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    if (NotificationService.activeChatUserId == widget.riderId) {
      NotificationService.activeChatUserId = null;
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _customerName = 'Customer';
  String _customerPhoto = '';

  String _getChatId(String uid1, String uid2) {
    final list = [uid1.trim(), uid2.trim()]..sort();
    return 'chat_${list[0]}_${list[1]}';
  }

  Future<void> _loadMetadata() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || widget.riderId.isEmpty) return;

    try {
      // Load customer profile info
      final custDoc = await _firestore.collection('customers').doc(currentUser.uid).get();
      if (custDoc.exists && custDoc.data() != null) {
        final cData = custDoc.data()!;
        _customerName = (cData['fullName'] ?? cData['name'] ?? 'Customer').toString();
        _customerPhoto = (cData['profilePic'] ?? cData['photoUrl'] ?? '').toString();
      }

      // Load rider metadata
      var riderDoc = await _firestore.collection('riders').doc(widget.riderId).get();
      Map<String, dynamic>? data = riderDoc.data();

      if (data == null || !riderDoc.exists) {
        final userDoc = await _firestore.collection('users').doc(widget.riderId).get();
        if (userDoc.exists) {
          data = userDoc.data();
        }
      }

      if (data != null && mounted) {
        final profile = data['profile'] as Map<String, dynamic>?;

        final resolvedName = (
          data['fullName'] ??
          data['name'] ??
          data['businessName'] ??
          profile?['fullName'] ??
          profile?['name'] ??
          (data['firstName'] != null ? '${data['firstName']} ${data['lastName'] ?? ''}'.trim() : null) ??
          _riderName
        ).toString();

        final resolvedPhoto = (
          data['photoUrl'] ??
          data['profilePicture'] ??
          data['photoURL'] ??
          data['avatarUrl'] ??
          data['profileImage'] ??
          data['imageUrl'] ??
          profile?['photoUrl'] ??
          profile?['profilePicture'] ??
          _riderPhoto
        ).toString();

        setState(() {
          if (resolvedName.isNotEmpty && resolvedName != 'null') {
            _riderName = resolvedName;
          }
          if (resolvedPhoto.isNotEmpty && resolvedPhoto != 'null') {
            _riderPhoto = resolvedPhoto;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading metadata: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = _getChatId(currentUser.uid, widget.riderId);
    try {
      await _firestore.collection('chats').doc(chatId).set({
        'unreadCount': {
          currentUser.uid: 0,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error marking messages read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = _getChatId(currentUser.uid, widget.riderId);
    _messageController.clear();

    try {
      final now = FieldValue.serverTimestamp();
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'receiverId': widget.riderId,
        'text': text,
        'createdAt': now,
      });

      await _firestore.collection('chats').doc(chatId).set({
        'members': [currentUser.uid, widget.riderId],
        'lastMessage': text,
        'lastMessageTime': now,
        'customerId': currentUser.uid,
        'customerName': _customerName,
        'customerPhoto': _customerPhoto,
        'riderId': widget.riderId,
        'riderName': _riderName,
        'riderPhoto': _riderPhoto,
        'unreadCount': {
          widget.riderId: FieldValue.increment(1),
        }
      }, SetOptions(merge: true));

      await _firestore.collection('notifications').add({
        'userId': widget.riderId,
        'customerId': widget.riderId,
        'title': 'New Message from $_customerName',
        'body': text,
        'description': text,
        'type': 'chat_message',
        'chatId': chatId,
        'senderId': currentUser.uid,
        'isRead': false,
        'createdAt': now,
      });

      // Dispatch FCM Push Notification to Rider directly
      NotificationService.sendPushToRider(
        riderId: widget.riderId,
        title: 'New Message from $_customerName',
        body: text,
        data: {
          'type': 'chat_message',
          'chatId': chatId,
          'senderId': currentUser.uid,
          'senderName': _customerName,
          'senderPhoto': _customerPhoto,
        },
      );

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: Text("Please log in to view conversation")),
      );
    }

    final chatId = _getChatId(currentUser.uid, widget.riderId);

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
                color: borderColor,
                width: 1,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black, size: 20.sp),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: _riderPhoto.isNotEmpty
                  ? Colors.transparent
                  : purpleColor.withValues(alpha: 0.15),
              backgroundImage: _riderPhoto.isNotEmpty
                  ? NetworkImage(_riderPhoto)
                  : null,
              child: _riderPhoto.isEmpty
                  ? Center(
                      child: Text(
                        _riderName.trim().isNotEmpty
                            ? _riderName.trim().split(RegExp(r'\s+')).first[0].toUpperCase()
                            : 'R',
                        style: TextStyle(
                          color: purpleColor,
                          fontSize: AppTypography.font(AppFontSizes.titleMedium),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 10.w),
            Text(
              _riderName,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: purpleColor));
                }

                final messages = snapshot.data?.docs ?? [];
                
                if (messages.isNotEmpty) {
                  _scrollToBottom();
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.messageSquare, size: 48.sp, color: Colors.grey),
                        SizedBox(height: 12.h),
                        const Text(
                          'No messages yet. Send a message to start!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(20.w),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final senderId = msg['senderId'] ?? '';
                    final text = msg['text'] ?? '';
                    final isOutgoing = senderId == currentUser.uid;
                    final timeStamp = msg['createdAt'] as Timestamp?;
                    
                    String formattedTime = '';
                    if (timeStamp != null) {
                      final date = timeStamp.toDate();
                      formattedTime = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    }

                    if (isOutgoing) {
                      return _buildOutgoingMessage(context, text, formattedTime, purpleColor);
                    } else {
                      return _buildIncomingMessage(context, text, formattedTime);
                    }
                  },
                );
              },
            ),
          ),
          _buildInputArea(context, backgroundColor, borderColor, purpleColor),
        ],
      ),
    );
  }

  Widget _buildIncomingMessage(BuildContext context, String text, String time) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomRight: Radius.circular(16.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              time,
              style: TextStyle(
                fontSize: AppTypography.font(10),
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutgoingMessage(BuildContext context, String text, String time, Color purpleColor) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: purpleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomLeft: Radius.circular(16.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: AppTypography.font(10),
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(Icons.done_all, color: Colors.white, size: 12.sp),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(
    BuildContext context,
    Color backgroundColor,
    Color borderColor,
    Color purpleColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(fontSize: AppTypography.font(AppFontSizes.bodyMedium), color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12.w),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: purpleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send, color: Colors.white, size: 24.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
