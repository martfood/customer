import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  String _pin = '';

  void _onNumberPress(String number) {
    if (_pin.length < 4) {
      setState(() => _pin += number);
      if (_pin.length == 4) {
        _showSuccessBottomSheet();
      }
    }
  }

  void _onDeletePress() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  void _showSuccessBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 36.sp,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'PIN Created Successfully',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Your security PIN has been updated.',
              style: TextStyle(
                color: mutedTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 28.h),
            ElevatedButton(
              onPressed: () {
                context.pop(); // Close bottom sheet
                context.pop(); // Go back to security
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 56.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

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
          'Create New PIN',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Add a PIN number to make your account\nmore secure.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 40.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _pin.length;
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 12.w),
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? purpleColor
                        : (isDark ? const Color(0xFF27272A) : const Color(0xFFE9EAF0)),
                  ),
                );
              }),
            ),
            SizedBox(height: 60.h),
            _buildKeyboard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboard(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['1', '2', '3'].map((n) => _buildKey(n, isDark)).toList(),
        ),
        SizedBox(height: 20.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['4', '5', '6'].map((n) => _buildKey(n, isDark)).toList(),
        ),
        SizedBox(height: 20.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['7', '8', '9'].map((n) => _buildKey(n, isDark)).toList(),
        ),
        SizedBox(height: 20.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(width: 60.w, height: 60.w),
            _buildKey('0', isDark),
            Container(
              width: 60.w,
              height: 60.w,
              alignment: Alignment.center,
              child: IconButton(
                icon: Icon(Icons.backspace_outlined,
                    color: isDark ? Colors.white : const Color(0xFF15161A)),
                onPressed: _onDeletePress,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String number, bool isDark) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    return GestureDetector(
      onTap: () => _onNumberPress(number),
      child: Container(
        width: 60.w,
        height: 60.w,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          number,
          style: TextStyle(
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
            color: primaryTextColor,
          ),
        ),
      ),
    );
  }
}
