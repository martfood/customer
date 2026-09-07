import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import '../../core/services/price_helper.dart';
import '../../core/services/account_status_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    // Start pre-fetching location in background parallelly
    PriceHelper.preFetchLocation();

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('customers')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 4));

          if (doc.exists && AccountStatusService.isSuspended(doc.data())) {
            final info = AccountStatusService.parseSuspension(doc.data());
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              context.go('/login', extra: {
                'suspensionReason': info.reason,
                'suspendedUntil': info.suspendedUntil,
              });
            }
            return;
          }
        } catch (_) {}

        if (mounted) {
          context.go('/home');
        }
      } else {
        context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Image.asset(
          'assets/logo/martfood_logo_light.png',
          width: 180,
          height: 180,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
