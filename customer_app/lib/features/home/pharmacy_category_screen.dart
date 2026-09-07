import 'package:flutter/material.dart';
import 'category_result_screen.dart';

class PharmacyCategoryScreen extends StatelessWidget {
  const PharmacyCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoryResultScreen(
      categoryName: 'Pharmacy',
      items: [
        {
          'title': 'Health First',
          'imageUrl': 'https://images.unsplash.com/photo-1587854692152-cbe660dbbb88?auto=format&fit=crop&q=80&w=400',
          'rating': 4.6,
          'reviewsCount': 800,
          'distanceM': 1500,
          'deliveryFee': 250,
        },
      ],
    );
  }
}
