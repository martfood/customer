import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class CustomerChatScreen extends StatefulWidget {
  final String chatId;
  const CustomerChatScreen({super.key, required this.chatId});

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _customerName = 'Customer';
  bool _isSending = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _fetchCustomerProfile();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomerProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();
      if (docSnap.exists && docSnap.data() != null) {
        setState(() {
          _customerName = docSnap.data()?['fullName'] ?? 'Customer';
        });
      }
    } catch (e) {
      debugPrint('Error fetching customer profile: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();
    final uid = user.uid;
    final nowStr = DateTime.now().toIso8601String();

    final messageObj = {
      'senderId': uid,
      'senderName': _customerName,
      'text': text,
      'createdAt': nowStr,
    };

    try {
      final docRef = FirebaseFirestore.instance
          .collection('support_chats')
          .doc(widget.chatId);
      await docRef.update({
        'status': 'active',
        'lastMessage': text,
        'lastMessageAt': nowStr,
        'messages': FieldValue.arrayUnion([messageObj]),
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending support message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isUploadingImage) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (pickedFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      String imageUrl = '';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';

      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('support_chats')
            .child(widget.chatId)
            .child(fileName);
        await storageRef.putFile(File(pickedFile.path));
        imageUrl = await storageRef.getDownloadURL();
      } catch (storageErr) {
        debugPrint('Firebase Storage error, encoding fallback: $storageErr');
        final bytes = await File(pickedFile.path).readAsBytes();
        final base64Str = base64Encode(bytes);
        imageUrl = 'data:image/jpeg;base64,$base64Str';
      }

      if (imageUrl.isEmpty) return;

      final nowStr = DateTime.now().toIso8601String();
      final messageObj = {
        'senderId': user.uid,
        'senderName': _customerName,
        'text': '',
        'imageUrl': imageUrl,
        'createdAt': nowStr,
      };

      final docRef = FirebaseFirestore.instance
          .collection('support_chats')
          .doc(widget.chatId);
      await docRef.update({
        'status': 'active',
        'lastMessage': '📷 Image',
        'lastMessageAt': nowStr,
        'messages': FieldValue.arrayUnion([messageObj]),
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minStr = dt.minute.toString().padLeft(2, '0');
      return "$hour:$minStr $ampm";
    } catch (_) {
      return '';
    }
  }

  Color _backgroundColor(bool isDark) {
    return isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
  }

  Color _surfaceColor(bool isDark) {
    return isDark ? AppTheme.darkSurface : Colors.white;
  }

  Color _borderColor(bool isDark) {
    return isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
  }

  Color _primaryTextColor(bool isDark) {
    return isDark ? Colors.white : const Color(0xFF15161A);
  }

  Color _mutedTextColor(bool isDark) {
    return isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor = _backgroundColor(isDark);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _primaryTextColor(isDark)),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Customer Support',
            style: TextStyle(
              color: _primaryTextColor(isDark),
              fontWeight: FontWeight.w800,
              fontSize: AppTypography.font(AppFontSizes.displaySmall),
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Please log in to view chat.',
            style: TextStyle(
              color: _primaryTextColor(isDark),
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
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryTextColor(isDark)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Customer Support',
          style: TextStyle(
            color: _primaryTextColor(isDark),
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('support_chats')
            .doc(widget.chatId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: purpleColor),
            );
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final messagesList = (data?['messages'] as List<dynamic>?) ?? [];
          final isClosed = data?['status'] == 'closed';
          final subject = (data?['subject'] ?? 'Support Ticket').toString();

          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
                  child: _buildTicketInfoCard(
                    isDark: isDark,
                    subject: subject,
                    isClosed: isClosed,
                    purpleColor: purpleColor,
                  ),
                ),
                Expanded(
                  child: messagesList.isEmpty
                      ? _buildEmptyConversationState(isDark, purpleColor)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                          itemCount: messagesList.length,
                          itemBuilder: (context, index) {
                            final msg = messagesList[index] as Map<String, dynamic>;
                            final senderId = msg['senderId'] ?? '';
                            final isMe = senderId == user.uid;
                            final isSystem = senderId == 'system';
                            final text = (msg['text'] ?? '').toString();
                            final imageUrl = (msg['imageUrl'] ?? '').toString();
                            final timeStr = (msg['createdAt'] ?? '').toString();

                            if (isSystem) {
                              return Align(
                                alignment: Alignment.center,
                                child: Container(
                                  margin: EdgeInsets.only(bottom: 16.h),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 10.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _surfaceColor(isDark),
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: _borderColor(isDark),
                                    ),
                                  ),
                                  child: Text(
                                    text,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _mutedTextColor(isDark),
                                      fontSize: AppTypography.font(
                                        AppFontSizes.bodySmall,
                                      ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return _buildMessageBubble(
                              text: text,
                              imageUrl: imageUrl,
                              time: _formatTime(timeStr),
                              isMe: isMe,
                              isDark: isDark,
                              purpleColor: purpleColor,
                            );
                          },
                        ),
                ),
                if (isClosed)
                  _buildClosedNotice(isDark)
                else
                  _buildInputArea(isDark, purpleColor),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTicketInfoCard({
    required bool isDark,
    required String subject,
    required bool isClosed,
    required Color purpleColor,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _surfaceColor(isDark),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: _borderColor(isDark),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: purpleColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.support_agent,
              color: purpleColor,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: TextStyle(
                    color: _primaryTextColor(isDark),
                    fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  isClosed ? 'Resolved ticket' : 'Active support conversation',
                  style: TextStyle(
                    color: _mutedTextColor(isDark),
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: (isClosed ? Colors.green : purpleColor)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              isClosed ? 'Closed' : 'Open',
              style: TextStyle(
                color: isClosed ? Colors.green : purpleColor,
                fontSize: AppTypography.font(AppFontSizes.caption),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConversationState(bool isDark, Color purpleColor) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: purpleColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 28.sp,
                color: purpleColor,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              'Start the conversation',
              style: TextStyle(
                color: _primaryTextColor(isDark),
                fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Send a message and our support team will reply here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mutedTextColor(isDark),
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedNotice(bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: _surfaceColor(isDark),
        border: Border(
          top: BorderSide(
            color: _borderColor(isDark),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.lock_outline,
              size: 18.sp,
              color: Colors.green,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'This ticket is resolved and closed.',
              style: TextStyle(
                color: _mutedTextColor(isDark),
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required String imageUrl,
    required String time,
    required bool isMe,
    required bool isDark,
    required Color purpleColor,
  }) {
    final hasImage = imageUrl.isNotEmpty;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        constraints: BoxConstraints(maxWidth: 0.75.sw),
        padding: EdgeInsets.symmetric(
          horizontal: hasImage ? 8.w : 16.w,
          vertical: hasImage ? 8.h : 12.h,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? purpleColor
              : _surfaceColor(isDark),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
            bottomLeft: isMe ? Radius.circular(20.r) : Radius.zero,
            bottomRight: isMe ? Radius.zero : Radius.circular(20.r),
          ),
          border: isMe
              ? null
              : Border.all(
                  color: _borderColor(isDark),
                ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: imageUrl.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(imageUrl.split(',').last),
                        width: 0.65.sw,
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 0.65.sw,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 0.65.sw,
                          height: 150.h,
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(color: purpleColor),
                          ),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 32.sp,
                        ),
                      ),
              ),
              if (text.isNotEmpty) SizedBox(height: 8.h),
            ],
            if (text.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hasImage ? 8.w : 0),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isMe
                        ? Colors.white
                        : _primaryTextColor(isDark),
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            SizedBox(height: 4.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hasImage ? 8.w : 0),
              child: Text(
                time,
                style: TextStyle(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.72)
                      : _mutedTextColor(isDark),
                  fontSize: AppTypography.font(10),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color purpleColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
      decoration: BoxDecoration(
        color: _surfaceColor(isDark),
        border: Border(
          top: BorderSide(
            color: _borderColor(isDark),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: _borderColor(isDark),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: _isUploadingImage
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: purpleColor,
                              ),
                            )
                          : Icon(
                              LucideIcons.image,
                              color: purpleColor,
                              size: 20.sp,
                            ),
                      onPressed: _isUploadingImage ? null : _pickAndSendImage,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyle(
                          color: _primaryTextColor(isDark),
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: _mutedTextColor(isDark),
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _sendMessage,
                borderRadius: BorderRadius.circular(18.r),
                child: Ink(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: purpleColor,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  child: _isSending
                      ? Padding(
                          padding: EdgeInsets.all(14.w),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.send, color: Colors.white, size: 20.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
