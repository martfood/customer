import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class CustomerLegalScreen extends StatelessWidget {
  const CustomerLegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFF0E6FF);
    final dividerColor = isDark ? AppTheme.darkBorder : const Color(0xFFF5EEFF);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);

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
                color: isDark ? Colors.grey[800]! : const Color(0xFFE9EAF0),
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
        centerTitle: true,
        title: Text(
          'Legal',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  children: [
                    // Privacy Policy
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/profile/legal/privacy-policy'),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24.r),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.shieldCheck,
                                  color: purpleColor,
                                  size: 20.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  'Privacy Policy',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(15),
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: purpleColor,
                                size: 22.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: dividerColor,
                      indent: 64.w,
                      endIndent: 16.w,
                    ),

                    // Terms of Use
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/profile/legal/terms-of-use'),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(24.r),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.fileText,
                                  color: purpleColor,
                                  size: 20.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  'Terms of Use',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(15),
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: purpleColor,
                                size: 22.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
