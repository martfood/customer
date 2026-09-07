import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  String _amount = '7500';
  late final TextEditingController _amountController;
  final List<String> _presets = ['1500', '3000', '7500', '10000', '15000', '20000'];

  double get _parsedAmount => double.tryParse(_amount) ?? 0.0;

  String _formatCurrency(num value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  void _selectPreset(String preset) {
    setState(() {
      _amount = preset;
      _amountController.text = preset;
      _amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: preset.length),
      );
    });
  }

  void _handleContinue() {
    if (_parsedAmount > 0) {
      context.push('/wallet/top-up/payment', extra: _parsedAmount);
    }
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: _amount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
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
              icon: Icon(Icons.arrow_back, color: purpleColor, size: 20.sp),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Text(
          'Top Up',
          style: TextStyle(
            color: purpleColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Responsive.maxContainer(
        context: context,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: 22.h,
                          horizontal: 22.w,
                        ),
                        decoration: BoxDecoration(
                          color: purpleColor,
                          borderRadius: BorderRadius.circular(28.r),
                          boxShadow: null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amount to add',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: AppTypography.font(
                                  AppFontSizes.bodySmall,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 14.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,
                                vertical: 16.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(22.r),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '₦',
                                    style: TextStyle(
                                      fontSize: AppTypography.font(28),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: TextField(
                                      controller: _amountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: false,
                                        signed: false,
                                      ),
                                      style: TextStyle(
                                        fontSize: AppTypography.font(30),
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: '0',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _amount = val;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              _parsedAmount > 0
                                  ? 'You are funding your wallet with ₦${_formatCurrency(_parsedAmount)}'
                                  : 'Enter a valid amount to continue',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: AppTypography.font(
                                  AppFontSizes.bodySmall,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        'Quick amounts',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Tap a preset to fill the amount instantly.',
                        style: TextStyle(
                          color: mutedTextColor,
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12.h,
                          crossAxisSpacing: 12.w,
                          childAspectRatio: 2.15,
                        ),
                        itemCount: _presets.length,
                        itemBuilder: (context, index) {
                          final preset = _presets[index];
                          final isSelected = _amount == preset;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectPreset(preset),
                              borderRadius: BorderRadius.circular(18.r),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? purpleColor
                                      : surfaceColor,
                                  border: Border.all(
                                    color: isSelected
                                        ? purpleColor
                                        : borderColor,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(18.r),
                                  boxShadow: null,
                                ),
                                child: Center(
                                  child: Text(
                                    '₦$preset',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : primaryTextColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: AppTypography.font(
                                        AppFontSizes.bodyMedium,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Selected amount',
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _parsedAmount > 0
                                  ? '₦${_formatCurrency(_parsedAmount)}'
                                  : '₦0.00',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 14.h),
                        ElevatedButton(
                          onPressed: _parsedAmount > 0 ? _handleContinue : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: purpleColor,
                            disabledBackgroundColor:
                                purpleColor.withValues(alpha: 0.35),
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 56.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
