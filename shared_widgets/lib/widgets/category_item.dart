import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';

class CategoryItem extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;
  final double? circleSize;
  final double? iconSize;

  const CategoryItem({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.circleSize,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final effectiveCircleSize = circleSize ?? (isTablet ? 56.w : 52.w);
    final effectiveIconSize = iconSize ?? (isTablet ? 42.w : 39.w);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: effectiveCircleSize,
                height: effectiveCircleSize,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: imageUrl.startsWith('assets/')
                    ? Image.asset(
                        imageUrl,
                        width: effectiveIconSize,
                        height: effectiveIconSize,
                        fit: BoxFit.contain,
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: effectiveIconSize,
                        height: effectiveIconSize,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => SizedBox(
                          width: effectiveIconSize,
                          height: effectiveIconSize,
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.fastfood,
                          size: effectiveIconSize * 0.8,
                          color: AppTheme.primaryPurpleFor(isDark),
                        ),
                      ),
              ),
              SizedBox(height: 6.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
