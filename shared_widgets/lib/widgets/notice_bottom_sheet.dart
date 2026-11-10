import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';

/// Data model representing a customizable disclaimer notice bottom sheet.
class NoticeDisclaimerData {
  final String title;
  final String subtitle;
  final String authorName;
  final String updatedDate;
  final String section1Title;
  final String section1Body;
  final String section2Title;
  final String section2Body;
  final String feedbackQuestion;

  const NoticeDisclaimerData({
    required this.title,
    required this.subtitle,
    required this.authorName,
    required this.updatedDate,
    required this.section1Title,
    required this.section1Body,
    required this.section2Title,
    required this.section2Body,
    this.feedbackQuestion = 'Did this answer your question?',
  });

  factory NoticeDisclaimerData.fromMap(
    Map<String, dynamic>? map, {
    required NoticeDisclaimerData fallback,
  }) {
    if (map == null || map.isEmpty) return fallback;
    return NoticeDisclaimerData(
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? map['title'] as String
          : fallback.title,
      subtitle: (map['subtitle'] as String?)?.trim().isNotEmpty == true
          ? map['subtitle'] as String
          : fallback.subtitle,
      authorName: (map['authorName'] as String?)?.trim().isNotEmpty == true
          ? map['authorName'] as String
          : fallback.authorName,
      updatedDate: (map['updatedDate'] as String?)?.trim().isNotEmpty == true
          ? map['updatedDate'] as String
          : fallback.updatedDate,
      section1Title:
          (map['section1Title'] as String?)?.trim().isNotEmpty == true
              ? map['section1Title'] as String
              : fallback.section1Title,
      section1Body: (map['section1Body'] as String?)?.trim().isNotEmpty == true
          ? map['section1Body'] as String
          : fallback.section1Body,
      section2Title:
          (map['section2Title'] as String?)?.trim().isNotEmpty == true
              ? map['section2Title'] as String
              : fallback.section2Title,
      section2Body: (map['section2Body'] as String?)?.trim().isNotEmpty == true
          ? map['section2Body'] as String
          : fallback.section2Body,
      feedbackQuestion:
          (map['feedbackQuestion'] as String?)?.trim().isNotEmpty == true
              ? map['feedbackQuestion'] as String
              : fallback.feedbackQuestion,
    );
  }
}

/// Fallback defaults for all disclaimer notice types
class NoticeDisclaimerDefaults {
  static const customerDeliveryFee = NoticeDisclaimerData(
    title: 'What is Delivery Fee?',
    subtitle: 'What is the delivery fee and why do we charge it?',
    authorName: 'MartFood Operations',
    updatedDate: 'June 21, 2026',
    section1Title: 'What is the MartFood Delivery Fee?',
    section1Body:
        'The delivery fee is a charge that appears on your price breakdown at checkout on the MartFood app. It covers the cost of getting your order from the restaurant to your doorstep. Unlike the service fee, the delivery fee is based on the distance between the restaurant and your delivery address — so the further you are, the higher the fee.\n\nYou\'ll always be able to see the delivery fee before you confirm your order, so there are no surprises at checkout.',
    section2Title: 'Why do we charge this?',
    section2Body:
        'Every time you place an order, a MartFood rider picks it up and brings it straight to you — rain or shine. The delivery fee helps us cover the operational cost of making that happen: rider compensation, fuel, and the logistics infrastructure that keeps orders moving fast and reliably.\n\nWe\'re committed to keeping delivery fees fair and transparent while continuing to build the most reliable food delivery experience.',
    feedbackQuestion: 'Did this answer your question?',
  );

  static const customerServiceFee = NoticeDisclaimerData(
    title: 'What is Service Fee?',
    subtitle: 'What is the service fee and why do we charge it?',
    authorName: 'MartFood Operations',
    updatedDate: 'June 21, 2026',
    section1Title: 'What is the MartFood Service Fee?',
    section1Body:
        'The service fee is a nominal charge applied to your order. It helps us run the MartFood platform 24/7, develop new app features, provide continuous customer support, and maintain secure payment processing across all transactions.',
    section2Title: 'Why do we charge this?',
    section2Body:
        'Maintaining a reliable, secure, and round-the-clock food delivery marketplace requires continuous investment in technology, server infrastructure, and dedicated customer care. The service fee ensures we can keep improving your ordering experience every single day.',
    feedbackQuestion: 'Did this answer your question?',
  );

  static const riderCommission = NoticeDisclaimerData(
    title: 'What is Platform Commission?',
    subtitle:
        'Understanding how platform commissions work on your delivery earnings.',
    authorName: 'MartFood Fleet Operations',
    updatedDate: 'June 21, 2026',
    section1Title: 'What is the Platform Commission?',
    section1Body:
        'The platform commission is a small percentage deducted from completed delivery fees. It helps fund rider app maintenance, automated dispatch routing, rider support, insurance partnerships, and continuous platform improvements.',
    section2Title: 'How does it affect your earnings?',
    section2Body:
        'Whenever a delivery order is completed, the commission rate configured by the platform is automatically accounted for, and your net earnings are immediately credited to your rider wallet. Any customer tips are always 100% yours with 0% platform commission deduction.',
    feedbackQuestion: 'Did this answer your question?',
  );

  static NoticeDisclaimerData forNoticeKey(String key) {
    switch (key) {
      case 'customerServiceFee':
        return customerServiceFee;
      case 'riderCommission':
        return riderCommission;
      case 'customerDeliveryFee':
      default:
        return customerDeliveryFee;
    }
  }
}

/// Reusable bottom sheet matching the minimal, modern editorial style.
class NoticeBottomSheet {
  /// Opens the notice bottom sheet with real-time Firestore sync & fallback.
  static Future<void> show(
    BuildContext context, {
    required String noticeKey,
  }) {
    final fallback = NoticeDisclaimerDefaults.forNoticeKey(noticeKey);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => _NoticeBottomSheetBody(
        noticeKey: noticeKey,
        fallback: fallback,
      ),
    );
  }
}

class _NoticeBottomSheetBody extends StatefulWidget {
  final String noticeKey;
  final NoticeDisclaimerData fallback;

  const _NoticeBottomSheetBody({
    required this.noticeKey,
    required this.fallback,
  });

  @override
  State<_NoticeBottomSheetBody> createState() => _NoticeBottomSheetBodyState();
}

class _NoticeBottomSheetBodyState extends State<_NoticeBottomSheetBody> {
  int? _selectedReaction; // 0: sad, 1: neutral, 2: happy
  bool _feedbackSubmitted = false;

  void _handleReaction(int reactionIndex) {
    if (_feedbackSubmitted) return;

    setState(() {
      _selectedReaction = reactionIndex;
      _feedbackSubmitted = true;
    });

    final reactionName =
        reactionIndex == 0 ? 'sad' : (reactionIndex == 1 ? 'neutral' : 'happy');

    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. Record individual granular feedback record
      FirebaseFirestore.instance.collection('disclaimers_feedback').add({
        'noticeKey': widget.noticeKey,
        'reaction': reactionName,
        'rating': reactionIndex + 1, // 1: sad, 2: neutral, 3: happy
        'userId': user?.uid,
        'userEmail': user?.email,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Atomically increment aggregated analytics counters
      FirebaseFirestore.instance
          .collection('settings')
          .doc('disclaimers_stats')
          .set({
        widget.noticeKey: {
          reactionName: FieldValue.increment(1),
          'total': FieldValue.increment(1),
          'lastVoteAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-blocking fire-and-forget
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : Colors.white;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final text = isDark ? Colors.white : AppTheme.brandBlack;
    final muted = AppTheme.mutedTextColorFor(isDark);
    final closeBtnBg = isDark ? AppTheme.darkBorder : AppTheme.lightInputFill;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('disclaimers')
          .snapshots(),
      builder: (context, snapshot) {
        NoticeDisclaimerData data = widget.fallback;

        if (snapshot.hasData && snapshot.data?.exists == true) {
          final docMap = snapshot.data!.data() as Map<String, dynamic>?;
          final noticeMap = docMap?[widget.noticeKey] as Map<String, dynamic>?;
          data = NoticeDisclaimerData.fromMap(noticeMap,
              fallback: widget.fallback);
        }

        final authorInitial = data.authorName.trim().isNotEmpty
            ? data.authorName.trim()[0].toUpperCase()
            : 'M';

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: border, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top close bar with round button
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 4.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            color: closeBtnBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: border, width: 1),
                          ),
                          child: Icon(
                            LucideIcons.x,
                            size: 18.sp,
                            color: text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable notice content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 28.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main Title
                        Text(
                          data.title,
                          style: TextStyle(
                            fontSize: AppTypography.font(24),
                            fontWeight: FontWeight.w900,
                            color: text,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 8.h),

                        // Subtitle
                        Text(
                          data.subtitle,
                          style: TextStyle(
                            fontSize: AppTypography.font(14.5),
                            fontWeight: FontWeight.w400,
                            color: muted,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 18.h),

                        // Author / Date Metadata Row
                        Row(
                          children: [
                            Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0F5132),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  authorInitial,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AppTypography.font(16),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Written by ${data.authorName}',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(12.5),
                                    fontWeight: FontWeight.w600,
                                    color: text,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  data.updatedDate,
                                  style: TextStyle(
                                    fontSize: AppTypography.font(11.5),
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 24.h),

                        // Section 1 Heading
                        Text(
                          data.section1Title,
                          style: TextStyle(
                            fontSize: AppTypography.font(19),
                            fontWeight: FontWeight.w800,
                            color: text,
                            letterSpacing: -0.3,
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: 10.h),

                        // Section 1 Body
                        Text(
                          data.section1Body,
                          style: TextStyle(
                            fontSize: AppTypography.font(13.5),
                            fontWeight: FontWeight.w400,
                            color: text.withValues(alpha: 0.90),
                            height: 1.55,
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // Section 2 Heading
                        Text(
                          data.section2Title,
                          style: TextStyle(
                            fontSize: AppTypography.font(19),
                            fontWeight: FontWeight.w800,
                            color: text,
                            letterSpacing: -0.3,
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: 10.h),

                        // Section 2 Body
                        Text(
                          data.section2Body,
                          style: TextStyle(
                            fontSize: AppTypography.font(13.5),
                            fontWeight: FontWeight.w400,
                            color: text.withValues(alpha: 0.90),
                            height: 1.55,
                          ),
                        ),
                        SizedBox(height: 36.h),

                        // Feedback Section
                        Center(
                          child: Column(
                            children: [
                              Text(
                                _feedbackSubmitted
                                    ? 'Thank you for your feedback!'
                                    : data.feedbackQuestion,
                                style: TextStyle(
                                  fontSize: AppTypography.font(13),
                                  fontWeight: FontWeight.w600,
                                  color: _feedbackSubmitted
                                      ? AppTheme.primaryPurpleFor(isDark)
                                      : muted,
                                ),
                              ),
                              SizedBox(height: 14.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildEmojiButton(
                                    emoji: '😞',
                                    index: 0,
                                    border: border,
                                    isDark: isDark,
                                  ),
                                  SizedBox(width: 16.w),
                                  _buildEmojiButton(
                                    emoji: '😐',
                                    index: 1,
                                    border: border,
                                    isDark: isDark,
                                  ),
                                  SizedBox(width: 16.w),
                                  _buildEmojiButton(
                                    emoji: '😃',
                                    index: 2,
                                    border: border,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                              if (_feedbackSubmitted) ...[
                                SizedBox(height: 12.h),
                                Text(
                                  'Thank you for your feedback! ✨',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(12),
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryPurpleFor(isDark),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmojiButton({
    required String emoji,
    required int index,
    required Color border,
    required bool isDark,
  }) {
    final isSelected = _selectedReaction == index;

    return GestureDetector(
      onTap: () => _handleReaction(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryPurpleFor(isDark).withValues(alpha: 0.15)
              : (isDark ? AppTheme.darkBorder : AppTheme.lightInputFill),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primaryPurpleFor(isDark) : border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(
              fontSize: AppTypography.font(20),
            ),
          ),
        ),
      ),
    );
  }
}
