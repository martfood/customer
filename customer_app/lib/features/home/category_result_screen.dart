import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/widgets/food_card_vertical.dart';
import '../../core/services/price_helper.dart';

class CategoryResultScreen extends StatelessWidget {
  final String categoryName;
  final List<Map<String, dynamic>> items;

  const CategoryResultScreen({
    super.key,
    required this.categoryName,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          categoryName,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.headlineMedium),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SizedBox(
            height: 50.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              children: [
                _buildFilterChip('Filter', LucideIcons.sliders, true),
                _buildFilterChip('Sort', LucideIcons.arrowUpDown, false),
                _buildFilterChip('Promo', null, false),
                _buildFilterChip('Self Pick', null, false),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          // Items List
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(20.w),
              itemCount: items.length,
              separatorBuilder: (context, index) => SizedBox(height: 16.h),
              itemBuilder: (context, index) {
                final item = items[index];
                return FoodCardVertical(
                  title: item['title'],
                  imageUrl: item['imageUrl'],
                  rating: (item['rating'] as num? ?? 0).toDouble(),
                  reviewsCount: (item['reviewsCount'] as num? ?? 0).toInt(),
                  distanceM: (item['distanceM'] as num? ?? 0).toInt(),
                  basePrice: item['basePrice'] != null
                      ? PriceHelper.applyMarkup((item['basePrice'] as num).toDouble(), item['sourceCollection'] ?? categoryName)
                      : null,
                  promoPrice: item['promoPrice'] != null
                      ? PriceHelper.applyMarkup((item['promoPrice'] as num).toDouble(), item['sourceCollection'] ?? categoryName)
                      : null,
                  onTap: () => context.push('/food-details/${item['title']}'),
                  onFavoriteTap: () {},
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData? icon, bool isSelected) {
    return Padding(
      padding: EdgeInsets.only(right: 12.w),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14.sp, color: isSelected ? Colors.white : AppTheme.primaryColor),
              SizedBox(width: 6.w),
            ],
            Text(label),
          ],
        ),
        onSelected: (selected) {},
        selected: false, // We'll manage state later if needed
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryColor,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: AppTypography.font(AppFontSizes.bodySmall),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
          side: const BorderSide(color: AppTheme.primaryColor),
        ),
      ),
    );
  }
}
