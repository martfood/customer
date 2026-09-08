import 'package:flutter/material.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/no_internet_overlay.dart';
import 'package:go_router/go_router.dart';

import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/forgot_password_otp_screen.dart';
import 'features/auth/reset_forgotten_password_screen.dart';
import 'features/auth/personal_info_screen.dart';
import 'features/auth/success_screen.dart';
import 'features/home/home_screen.dart';
import 'features/notifications/notification_screen.dart';
import 'features/wallet/e-wallet_screen.dart';
import 'features/wallet/transaction_history_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/messages/message_screen.dart';
import 'features/profile/special_offer_screen.dart';
import 'features/profile/create_pin_screen.dart';
import 'features/profile/change_password_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/orders/pay_awaiting_order_screen.dart';
import 'features/home/restaurant_category_screen.dart';
import 'features/home/grocery_category_screen.dart';
import 'features/home/bakery_category_screen.dart';
import 'features/home/pharmacy_category_screen.dart';
import 'features/home/restaurant_food_details_screen.dart';
import 'features/home/vendor_screen.dart';
import 'features/home/vendor_detail_screen.dart';
import 'features/messages/conversation_screen.dart';
import 'features/checkout/checkout_orders_summary.dart';
import 'features/checkout/checkout_orders_summary_deliver_to_screen.dart';
import 'features/checkout/checkout_orders_summary_payment_methods.dart';
import 'features/cart/my_cart_screen.dart';
import 'features/tracking/track_driver_screen.dart';
import 'features/tracking/rate_rider_screen.dart';
import 'features/search/search_screen.dart';
import 'features/home/discount_guaranteed_screen.dart';
import 'features/home/schedule_meal_screen.dart';

import 'features/wallet/top_up_screen.dart';
import 'features/wallet/top_up_payment_method_screen.dart';
import 'features/wallet/top_up_pin_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/address_screen.dart';
import 'features/profile/notification_setting_screen.dart';
import 'features/profile/appearance_screen.dart';
import 'features/profile/add_address_screen.dart';
import 'features/profile/address_location_screen.dart';
import 'features/profile/language_screen.dart';
import 'features/profile/favorite_restaurants_screen.dart';
import 'features/profile/help_center_screen.dart';
import 'features/profile/customer_service_chat_screen.dart';
import 'features/profile/customer_chat_screen.dart';
import 'features/profile/profile_payment_methods_screen.dart';
import 'features/profile/customer_legal_screen.dart';
import 'features/profile/customer_privacy_policy_screen.dart';
import 'features/profile/customer_terms_of_use_screen.dart';
import 'features/orders/leave_a_review.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'core/services/notification_service.dart';
import 'core/services/price_helper.dart';
import 'core/services/account_status_service.dart';

class ThemeManager {
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.system);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('PreferredOrientations error: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp error: $e');
  }

  try {
    await PriceHelper.initialize();
  } catch (e) {
    debugPrint('PriceHelper.initialize error: $e');
  }

  // ── Offline persistence: data loads from disk instantly on revisit ──────────
  // 50 MB cache keeps vendor menus, profiles and food items available offline.
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 52428800, // 50 MB
    );
  } catch (e) {
    debugPrint('Firestore persistence settings error: $e');
  }

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('NotificationService.initialize error: $e');
  }

  try {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        NotificationService.registerCustomerToken(user.uid);
        NotificationService.listenToFirestoreNotifications(user.uid);
        FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .snapshots()
            .listen((snap) {
          if (snap.exists) {
            final data = snap.data();
            if (AccountStatusService.isSuspended(data)) {
              final info = AccountStatusService.parseSuspension(data);
              FirebaseAuth.instance.signOut();
              _router.go('/login', extra: {
                'suspensionReason': info.reason,
                'suspendedUntil': info.suspendedUntil,
              });
              return;
            }

            final themeStr = data?['themeMode'] as String?;
            if (themeStr != null) {
              ThemeMode mode;
              if (themeStr == 'light') {
                mode = ThemeMode.light;
              } else if (themeStr == 'dark') {
                mode = ThemeMode.dark;
              } else {
                mode = ThemeMode.system;
              }
              ThemeManager.themeModeNotifier.value = mode;
            }
          }
        });
      }
    });
  } catch (e) {
    debugPrint('Auth listener setup error: $e');
  }

  runApp(const MartFoodApp());
}

class MartFoodApp extends StatelessWidget {
  const MartFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeModeNotifier,
      builder: (context, currentThemeMode, child) {
        return ScreenUtilInit(
          designSize: const Size(390, 844), // iPhone 13/14 size
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MaterialApp.router(
              title: 'MartFood',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentThemeMode,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                final size = mediaQuery.size;
                final isTablet = size.width >= 600 || size.shortestSide >= 600;

                // ── GLOBAL FONT SCALING (MOBILE & TABLET) ────────────────────
                // Tablet (>= 600dp / 8.7"+): customize scale multiplier here
                // Mobile (< 600dp):          customize scale multiplier here
                final scaleFactor = isTablet ? 1.1 : 1.0;

                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(scaleFactor),
                  ),
                  child: ConnectivityWrapper(
                    onGoHome: () => _router.go('/home'),
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
              routerConfig: _router,
            );
          },
        );
      },
    );
  }
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return LoginScreen(
          suspensionReason: extra?['suspensionReason'] as String?,
          suspendedUntil: extra?['suspendedUntil'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        return OtpScreen(
          email: extra?['email'] ?? '',
          password: extra?['password'] ?? '',
          otp: extra?['otp'] ?? '',
          fullName: extra?['fullName'] ?? '',
          phoneNumber: extra?['phoneNumber'] ?? '',
          profilePicPath: extra?['profilePicPath'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/forgot-password-otp',
      builder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        return ForgotPasswordOtpScreen(
          email: extra?['email'] ?? '',
          otp: extra?['otp'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/reset-forgotten-password',
      builder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        return ResetForgottenPasswordScreen(
          email: extra?['email'] ?? '',
          otp: extra?['otp'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/personal-info',
      builder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        return PersonalInfoScreen(
          email: extra?['email'] ?? '',
          password: extra?['password'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/success',
      builder: (context, state) => const SuccessScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationScreen(),
    ),
    GoRoute(
      path: '/wallet',
      builder: (context, state) {
        final showSuccess = state.uri.queryParameters['showSuccess'] == 'true';
        final amountStr = state.uri.queryParameters['amount'];
        final amount = double.tryParse(amountStr ?? '') ?? 0.0;
        return EWalletScreen(showSuccess: showSuccess, amount: amount);
      },
    ),
    GoRoute(
      path: '/transaction-history',
      builder: (context, state) => const TransactionHistoryScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/messages',
      builder: (context, state) => const MessageScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) {
        final showSuccess = state.uri.queryParameters['showSuccess'] == 'true';
        final payForMeSuccess =
            state.uri.queryParameters['payForMeSuccess'] == 'true';
        final orderId = state.uri.queryParameters['orderId'];
        final paymentToken = state.uri.queryParameters['token'];
        final tabParam = state.uri.queryParameters['tab'];
        int initialIndex = 0;
        if (tabParam == 'active' || showSuccess || payForMeSuccess) {
          initialIndex = 1;
        } else if (tabParam == 'completed') {
          initialIndex = 2;
        } else if (tabParam == 'cart') {
          initialIndex = 0;
        }
        return OrdersScreen(
          showSuccess: showSuccess,
          payForMeSuccess: payForMeSuccess,
          orderId: orderId,
          paymentToken: paymentToken,
          initialIndex: initialIndex,
        );
      },
    ),
    GoRoute(
      path: '/orders/pay-awaiting',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return PayAwaitingOrderScreen(
          orderId: extra?['orderId']?.toString() ?? '',
          orderData: extra?['orderData'] as Map<String, dynamic>? ?? {},
        );
      },
    ),
    GoRoute(
      path: '/special_offers',
      builder: (context, state) => const SpecialOfferScreen(),
    ),
    GoRoute(
      path: '/create-pin',
      builder: (context, state) => const CreatePinScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/category/restaurant',
      builder: (context, state) => const RestaurantCategoryScreen(),
    ),
    GoRoute(
      path: '/category/grocery',
      builder: (context, state) => const GroceryCategoryScreen(),
    ),
    GoRoute(
      path: '/category/bakery',
      builder: (context, state) => const BakeryCategoryScreen(),
    ),
    GoRoute(
      path: '/category/pharmacy',
      builder: (context, state) => const PharmacyCategoryScreen(),
    ),
    GoRoute(
      path: '/conversation/:riderId',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ConversationScreen(
          riderId: state.pathParameters['riderId'] ?? '',
          riderName: extra?['riderName']?.toString(),
          riderPhotoUrl: extra?['riderPhotoUrl']?.toString(),
        );
      },
    ),
    GoRoute(
      path: '/food-details/:title',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return RestaurantFoodDetailsScreen(
          title: state.pathParameters['title'] ?? 'Food Details',
          vendorId: extra?['vendorId']?.toString(),
          docId: extra?['docId']?.toString(),
          sourceCollection: extra?['sourceCollection']?.toString(),
        );
      },
    ),
    GoRoute(
      path: '/vendor/:id',
      builder: (context, state) => VendorScreen(
        vendorId: state.pathParameters['id'] ?? 'chicken-republic',
      ),
    ),
    GoRoute(
      path: '/vendor-detail/:id',
      builder: (context, state) => VendorDetailScreen(
        vendorId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/checkout',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final checkoutItems = extra?['checkoutItems'] != null
            ? List<Map<String, dynamic>>.from(extra!['checkoutItems'])
            : null;
        return CheckoutOrdersSummaryScreen(checkoutItems: checkoutItems);
      },
    ),
    GoRoute(
      path: '/checkout/deliver-to',
      builder: (context, state) => const DeliverToScreen(),
    ),
    GoRoute(
      path: '/checkout/payment-methods',
      builder: (context, state) {
        final amount = state.extra as double? ?? 0.0;
        return PaymentMethodsScreen(orderTotal: amount);
      },
    ),
    GoRoute(
      path: '/checkout/discounts',
      builder: (context, state) => const SpecialOfferScreen(),
    ),
    GoRoute(
      path: '/wallet/top-up',
      builder: (context, state) => const TopUpScreen(),
    ),
    GoRoute(
      path: '/wallet/top-up/payment',
      builder: (context, state) {
        final amount = state.extra as double? ?? 0.0;
        return TopUpPaymentMethodScreen(amount: amount);
      },
    ),
    GoRoute(
      path: '/wallet/top-up/pin',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return TopUpPinScreen(
          amount: extra?['amount'] ?? 0.0,
          email: extra?['email'] ?? '',
          authorizationCode: extra?['authorizationCode'] ?? '',
          cardDescription: extra?['cardDescription'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/profile/address',
      builder: (context, state) => const AddressScreen(),
    ),
    GoRoute(
      path: '/profile/address/add',
      builder: (context, state) => const AddAddressScreen(),
    ),
    GoRoute(
      path: '/profile/address/location',
      builder: (context, state) => const AddressLocationScreen(),
    ),
    GoRoute(
      path: '/profile/notification',
      builder: (context, state) => const NotificationSettingScreen(),
    ),
    GoRoute(
      path: '/profile/appearance',
      builder: (context, state) => const AppearanceScreen(),
    ),
    GoRoute(
      path: '/profile/language',
      builder: (context, state) => const LanguageScreen(),
    ),
    GoRoute(
      path: '/profile/favorites',
      builder: (context, state) => const FavoriteRestaurantsScreen(),
    ),
    GoRoute(
      path: '/profile/help-center',
      builder: (context, state) => const HelpCenterScreen(),
    ),
    GoRoute(
      path: '/profile/legal',
      builder: (context, state) => const CustomerLegalScreen(),
    ),
    GoRoute(
      path: '/profile/legal/privacy-policy',
      builder: (context, state) => const CustomerPrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/profile/legal/terms-of-use',
      builder: (context, state) => const CustomerTermsOfUseScreen(),
    ),
    GoRoute(
      path: '/discount-guaranteed',
      builder: (context, state) => const DiscountGuaranteedScreen(),
    ),
    GoRoute(
      path: '/schedule-meal',
      builder: (context, state) => const ScheduleMealScreen(),
    ),
    GoRoute(
      path: '/profile/customer-service',
      builder: (context, state) => const CustomerServiceChatScreen(chatId: ''),
    ),
    GoRoute(
      path: '/profile/customer-service/chat',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CustomerChatScreen(chatId: extra?['id'] ?? '');
      },
    ),
    GoRoute(
      path: '/profile/payment-methods',
      builder: (context, state) => const ProfilePaymentMethodsScreen(),
    ),
    GoRoute(
      path: '/orders/leave-review',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>?;
        return LeaveAReviewScreen(
          restaurantName: extras?['name'] ?? 'Restaurant',
          imageUrl: extras?['imageUrl'] ?? '',
          vendorId: extras?['vendorId'] ?? '',
          orderId: extras?['orderId'] ?? '',
          itemsSummary: extras?['itemsSummary'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/cart',
      builder: (context, state) => const MyCartScreen(),
    ),
    GoRoute(
      path: '/track_driver',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return TrackDriverScreen(orderId: extra?['orderId'] ?? '');
      },
    ),
    GoRoute(
      path: '/rate_rider',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>?;
        return RateRiderScreen(
          orderId: extras?['orderId'] ?? '',
          riderId: extras?['riderId'] ?? '',
          riderName: extras?['riderName'] ?? 'Rider',
          riderPhoto: extras?['riderPhotoUrl'] ??
              extras?['riderPhoto'] ??
              extras?['photoUrl'] ??
              '',
        );
      },
    ),
  ],
);

final _router = appRouter;
