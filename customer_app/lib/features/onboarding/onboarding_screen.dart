import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const darkTextColor = Color(0xFF222222);
    const subtextColor = Color(0xFF4A4A4A);

    return Scaffold(
      body: Stack(
        children: [
          // ── 1. Full Screen Background Image (Onboarding-2.png) ─────────────
          Positioned.fill(
            child: Image.asset(
              'assets/onboarding/Onboarding-2.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // ── 2. Content & Action Overlay ──────────────────────────────────
          SafeArea(
            child: Responsive.maxContainer(
              context: context,
              maxWidth: 600,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),

                    // ── Logo ──────────────────────────────────────────────────
                    Image.asset(
                      'assets/logo/martfood_logo_dark.png',
                      height: 38.h,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.restaurant_menu,
                        size: 38.sp,
                        color: AppTheme.primaryColor,
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // ── Headline ──────────────────────────────────────────────
                    Text(
                      'Discover Tasty Meals\nAt your Convinience.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.displayLarge),
                        fontWeight: FontWeight.w800,
                        color: darkTextColor,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // ── Subline ───────────────────────────────────────────────
                    Text(
                      'Discover Tasty Meals At your Convinience...Restaurants to pharmacy essentials, MartFood brings all to your doorstep.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.normal,
                        color: subtextColor,
                        height: 1.4,
                      ),
                    ),

                    SizedBox(height: 28.h),

                    // ── Action Button (Purple Pill Button) ────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: () => context.go('/login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28.r),
                          ),
                        ),
                        child: Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.titleMedium),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 12.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



