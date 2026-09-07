import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  @override
  State<NotificationSettingScreen> createState() =>
      _NotificationSettingScreenState();
}

class _NotificationSettingScreenState extends State<NotificationSettingScreen> {
  bool _generalNotification = true;
  bool _sound = true;
  bool _vibrate = false;
  bool _specialOffers = true;
  bool _promoDiscount = false;
  bool _payments = true;
  bool _cashback = true;
  bool _appUpdates = true;
  bool _newServiceAvailable = false;
  bool _newTipsAvailable = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          'Notification Settings',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        children: [
          _buildSwitchTile('General Notification', _generalNotification,
              (v) => setState(() => _generalNotification = v), isDark),
          _buildSwitchTile(
              'Sound', _sound, (v) => setState(() => _sound = v), isDark),
          _buildSwitchTile(
              'Vibrate', _vibrate, (v) => setState(() => _vibrate = v), isDark),
          _buildSwitchTile('Special Offers', _specialOffers,
              (v) => setState(() => _specialOffers = v), isDark),
          _buildSwitchTile('Promo & Discount', _promoDiscount,
              (v) => setState(() => _promoDiscount = v), isDark),
          _buildSwitchTile('Payments', _payments,
              (v) => setState(() => _payments = v), isDark),
          _buildSwitchTile('Cashback', _cashback,
              (v) => setState(() => _cashback = v), isDark),
          _buildSwitchTile('App Updates', _appUpdates,
              (v) => setState(() => _appUpdates = v), isDark),
          _buildSwitchTile('New Service Available', _newServiceAvailable,
              (v) => setState(() => _newServiceAvailable = v), isDark),
          _buildSwitchTile('New Tips Available', _newTipsAvailable,
              (v) => setState(() => _newTipsAvailable = v), isDark),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
      String title, bool value, ValueChanged<bool> onChanged, bool isDark) {
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: purpleColor,
          ),
        ],
      ),
    );
  }
}
