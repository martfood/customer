import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _faqs = [
    // General
    {
      'category': 'General',
      'q': 'What is MartFood?',
      'a':
          'MartFood is a comprehensive food, grocery, and pharmacy delivery platform bringing your favorite meals, groceries, and essential medications right to your doorstep.'
    },
    {
      'category': 'General',
      'q': 'What are the operating hours of MartFood stores?',
      'a':
          'Operating hours vary per vendor. Each vendor profile and restaurant card prominently displays their open and close times for the current day. Ordering is disabled when a store is past its closing hours.'
    },
    {
      'category': 'General',
      'q': 'Can I order from multiple restaurants/vendors at once?',
      'a':
          'To ensure fast preparation and hot delivery, multi-vendor order splitting is not supported in a single checkout. Please place separate orders for each restaurant or vendor.'
    },
    {
      'category': 'General',
      'q': 'What do the verification badges mean on store cards?',
      'a':
          'Verification tiers highlight trusted vendors:\n• Gold (Gold Badge): Official premier partner verified with in-person address audits.\n• Standard (Green Badge): Trusted business with government-verified business identities.\n• Basic (Gray Badge): Starter business with authenticated contact and bank details.'
    },
    // Account
    {
      'category': 'Account',
      'q': 'How do I change my account details?',
      'a':
          'Navigate to the Profile tab, tap "Edit Profile", and update your profile photo, business details, or contact information.'
    },
    {
      'category': 'Account',
      'q': 'How do I change my account password?',
      'a':
          'Go to the Profile tab, tap "Change Password", enter your current password, and choose a new, secure password.'
    },
    {
      'category': 'Account',
      'q': 'How do I manage my delivery addresses?',
      'a':
          'Tap "Addresses" in your Profile tab. You can add new addresses, edit existing locations, or choose a default delivery point using real-time maps.'
    },
    {
      'category': 'Account',
      'q': 'What is the E-Wallet PIN?',
      'a':
          'Your E-Wallet PIN is a 4-digit security code used to authorize wallet-based checkout payments. You can set up or reset your PIN from the Profile tab under "Create PIN".'
    },
    // Payment
    {
      'category': 'Payment',
      'q': 'What payment options does MartFood accept?',
      'a':
          'We support payment via your secure MartFood E-Wallet, Card payments (handled via Paystack), and Cash/Card on Delivery (depending on vendor settings).'
    },
    {
      'category': 'Payment',
      'q': 'How do I top up my E-Wallet balance?',
      'a':
          'Go to the Wallet screen, tap "Top Up", enter your desired amount, and securely complete the payment using Paystack web-pay options.'
    },
    {
      'category': 'Payment',
      'q': 'What happens if a payment fails but my account is debited?',
      'a':
          'Failed payments are typically auto-reversed by your bank within 24 hours. If your wallet is not credited, please tap "Customer Service" under "Contact Us" to chat directly with support with your transaction details.'
    },
    // Delivery
    {
      'category': 'Delivery',
      'q': 'How are delivery fees calculated?',
      'a':
          'Delivery fees are dynamically calculated based on the distance between your selected delivery address and the vendor\'s physical location.'
    },
    {
      'category': 'Delivery',
      'q': 'Can I track my rider in real-time?',
      'a':
          'Yes, once a rider accepts your order and arrives at the restaurant, you can view their real-time location on the Map inside the Orders/Tracking tab.'
    },
    {
      'category': 'Delivery',
      'q': 'How do I contact my rider?',
      'a':
          'Open your active order tracking screen. You can initiate a call or send direct chat messages to your assigned rider from there.'
    },
    // Promo
    {
      'category': 'Promo',
      'q': 'How do I use a promo code?',
      'a':
          'During checkout, click on "Select Promo Code" or enter your voucher code in the designated discount field to deduct the discount from your total bill.'
    },
    {
      'category': 'Promo',
      'q': 'Where can I find active promotions?',
      'a':
          'Check the "Special Offers" screen in the Profile tab or look out for push notifications sent directly to your device.'
    },
    {
      'category': 'Promo',
      'q': 'Why is my promo code not working?',
      'a':
          'Promo codes have specific conditions such as minimum order value, expiration date, or usage limits per user. Please check the promotion terms in the Special Offers page.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextColor),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Help Center',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.5, color: purpleColor),
            insets: EdgeInsets.symmetric(horizontal: 28.w),
          ),
          labelColor: purpleColor,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          labelStyle: TextStyle(
            fontSize: AppTypography.font(AppFontSizes.bodyLarge),
            fontWeight: FontWeight.w800,
          ),
          tabs: const [
            Tab(text: 'FAQ'),
            Tab(text: 'Contact Us'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFAQTab(isDark, purpleColor),
          _buildContactUsTab(isDark, purpleColor),
        ],
      ),
    );
  }

  Widget _buildFAQTab(bool isDark, Color purpleColor) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('faqs')
          .snapshots(),
      builder: (context, snapshot) {
        List<Map<String, String>> effectiveFaqs = _faqs;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final dynamic rawList = data?['customerFaqs'];
          if (rawList is List && rawList.isNotEmpty) {
            effectiveFaqs = rawList
                .map((item) {
                  final map = item as Map<String, dynamic>;
                  return {
                    'category': (map['category'] ?? 'General').toString(),
                    'q': (map['q'] ?? '').toString(),
                    'a': (map['a'] ?? '').toString(),
                  };
                })
                .where((f) => f['q']!.isNotEmpty && f['a']!.isNotEmpty)
                .toList();
          }
        }

        final String query = _searchQuery.trim().toLowerCase();
        final filteredFaqs = effectiveFaqs.where((faq) {
          return query.isEmpty ||
              faq['q']!.toLowerCase().contains(query) ||
              faq['a']!.toLowerCase().contains(query) ||
              (faq['category'] ?? '').toLowerCase().contains(query);
        }).toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          children: [
            TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search FAQ',
                hintStyle: TextStyle(
                  color: mutedTextColor,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18.r),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18.r),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18.r),
                  borderSide: BorderSide(
                    color: purpleColor,
                    width: 1.4,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            if (filteredFaqs.isEmpty)
              Container(
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
                      width: 56.w,
                      height: 56.w,
                      decoration: BoxDecoration(
                        color: purpleColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: Icon(
                        LucideIcons.search,
                        color: purpleColor,
                        size: 24.sp,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      'No FAQs found',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Try another keyword or switch to a different category.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...filteredFaqs.map((faq) =>
                  _buildFAQItem(faq['q']!, faq['a']!, isDark, purpleColor)),
          ],
        );
      },
    );
  }

  Widget _buildFAQItem(
      String question, String answer, bool isDark, Color purpleColor) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 4.h),
        childrenPadding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 18.h),
        iconColor: purpleColor,
        collapsedIconColor: Colors.grey[500],
        title: Text(
          question,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: AppTypography.font(AppFontSizes.bodyLarge),
            color: primaryTextColor,
          ),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactUsTab(bool isDark, Color purpleColor) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('contact_us')
          .snapshots(),
      builder: (context, snapshot) {
        String whatsappTitle = 'WhatsApp';
        String whatsappLink = 'https://wa.me/2348000000000';
        String websiteTitle = 'Website';
        String websiteLink = 'https://www.martfooddelivery.com';
        String facebookTitle = 'Facebook';
        String facebookLink = 'https://facebook.com/martfooddelivery';
        String twitterTitle = 'Twitter';
        String twitterLink = 'https://twitter.com/martfood';
        String instagramTitle = 'Instagram';
        String instagramLink = 'https://instagram.com/martfood';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            final wa = data['whatsapp'] as Map<String, dynamic>?;
            if (wa != null) {
              whatsappTitle = (wa['title'] ?? whatsappTitle).toString();
              whatsappLink = (wa['link'] ?? whatsappLink).toString();
            }
            final web = data['website'] as Map<String, dynamic>?;
            if (web != null) {
              websiteTitle = (web['title'] ?? websiteTitle).toString();
              websiteLink = (web['link'] ?? websiteLink).toString();
            }
            final fb = data['facebook'] as Map<String, dynamic>?;
            if (fb != null) {
              facebookTitle = (fb['title'] ?? facebookTitle).toString();
              facebookLink = (fb['link'] ?? facebookLink).toString();
            }
            final tw = data['twitter'] as Map<String, dynamic>?;
            if (tw != null) {
              twitterTitle = (tw['title'] ?? twitterTitle).toString();
              twitterLink = (tw['link'] ?? twitterLink).toString();
            }
            final ig = data['instagram'] as Map<String, dynamic>?;
            if (ig != null) {
              instagramTitle = (ig['title'] ?? instagramTitle).toString();
              instagramLink = (ig['link'] ?? instagramLink).toString();
            }
          }
        }

        final List<Map<String, dynamic>> items = [
          {
            'title': whatsappTitle,
            'icon': LucideIcons.messageCircle,
            'isLink': true,
            'link': whatsappLink,
          },
          {
            'title': websiteTitle,
            'icon': LucideIcons.globe,
            'isLink': true,
            'link': websiteLink,
          },
          {
            'title': facebookTitle,
            'icon': Icons.facebook,
            'isLink': true,
            'link': facebookLink,
          },
          {
            'title': twitterTitle,
            'icon': Icons.flutter_dash,
            'isLink': true,
            'link': twitterLink,
          },
          {
            'title': instagramTitle,
            'icon': Icons.camera_alt_outlined,
            'isLink': true,
            'link': instagramLink,
          },
        ];

        return ListView(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          children: [
            ...List.generate(items.length, (index) {
              final item = items[index];
              final bool isLink = item['isLink'] as bool;

              if (!isLink) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: borderColor),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24.r),
                        onTap: item['onTap'] as VoidCallback,
                        child: Padding(
                          padding: EdgeInsets.all(18.w),
                          child: Row(
                            children: [
                              Container(
                                width: 48.w,
                                height: 48.w,
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: purpleColor,
                                  size: 22.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  item['title'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: AppTypography.font(
                                        AppFontSizes.bodyLarge),
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                              Icon(LucideIcons.chevronRight,
                                  color: purpleColor, size: 20.sp),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              final String linkUrl = item['link'] as String;

              return Padding(
                padding: EdgeInsets.only(
                    bottom: index == items.length - 1 ? 0 : 16.h),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: borderColor),
                  ),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding:
                          EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
                      childrenPadding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 18.h),
                      iconColor: purpleColor,
                      collapsedIconColor:
                          isDark ? Colors.grey[500] : Colors.grey[400],
                      title: Row(
                        children: [
                          Container(
                            width: 48.w,
                            height: 48.w,
                            decoration: BoxDecoration(
                              color: purpleColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              color: purpleColor,
                              size: 22.sp,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Text(
                            item['title'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize:
                                  AppTypography.font(AppFontSizes.bodyLarge),
                              color: primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      children: [
                        InkWell(
                          onTap: () async {
                            final Uri url = Uri.parse(linkUrl);
                            try {
                              if (!await launchUrl(url,
                                  mode: LaunchMode.externalApplication)) {
                                debugPrint('Could not launch $url');
                              }
                            } catch (e) {
                              debugPrint('Error launching url: $e');
                            }
                          },
                          borderRadius: BorderRadius.circular(14.r),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                horizontal: 14.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF27272A)
                                  : const Color(0xFFF7F8FC),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8.sp,
                                  color: purpleColor,
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Text(
                                    linkUrl,
                                    style: TextStyle(
                                      color: purpleColor,
                                      fontSize: AppTypography.font(
                                          AppFontSizes.bodyMedium),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
