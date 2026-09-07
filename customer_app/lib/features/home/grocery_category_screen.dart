import 'package:flutter/material.dart';
import 'category_result_screen.dart';

class GroceryCategoryScreen extends StatelessWidget {
  const GroceryCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoryResultScreen(
      categoryName: 'Grocery',
      items: [
        {
          'title': 'Fresh Market',
          'imageUrl': 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=400',
          'rating': 4.8,
          'reviewsCount': 3100,
          'distanceM': 500,
          'deliveryFee': 100,
        },
        {
          'title': 'Organic Greens',
          'imageUrl': 'https://images.unsplash.com/photo-1573248639136-8f81735a0243?auto=format&fit=crop&q=80&w=400',
          'rating': 4.6,
          'reviewsCount': 1200,
          'distanceM': 1100,
          'deliveryFee': 150,
        },
      ],
    );
  }
}
