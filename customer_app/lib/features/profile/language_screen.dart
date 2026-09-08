import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'English (US)';

  final List<String> _languages = [
    'English (US)',
    'English (UK)',
    'Mandarin',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Portuguese',
    'Russian',
    'Japanese',
    'Korean',
    'Arabic',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
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
          'Language',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        itemCount: _languages.length,
        separatorBuilder: (context, index) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = _selectedLanguage == lang;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18.r),
              onTap: () => setState(() => _selectedLanguage = lang),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: isSelected ? purpleColor : borderColor,
                    width: isSelected ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang,
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? purpleColor
                          : AppTheme.hintColorFor(isDark),
                      size: 22.sp,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
