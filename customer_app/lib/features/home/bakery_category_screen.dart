import 'package:flutter/material.dart';
import 'category_result_screen.dart';

class BakeryCategoryScreen extends StatelessWidget {
  const BakeryCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoryResultScreen(
      categoryName: 'Bakery',
      items: [
        {
          'title': 'Sweet Delights',
          'imageUrl': 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&q=80&w=400',
          'rating': 4.7,
          'reviewsCount': 1500,
          'distanceM': 900,
          'deliveryFee': 120,
        },
        {
          'title': 'Golden Crust',
          'imageUrl': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&q=80&w=400',
          'rating': 4.9,
          'reviewsCount': 2100,
          'distanceM': 1300,
          'deliveryFee': 180,
        },
      ],
    );
  }
}
