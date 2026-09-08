import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF803CA2);
  static const Color primaryPurple = Color(0xFF803CA2);
  static const Color darkPrimaryPurple =
      Color(0xFFA855F7); // Lighter vibrant purple for dark mode
  static const Color accentColor = Color(0xFFE5A70C);

  static Color getPrimaryPurple(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkPrimaryPurple : primaryPurple;
  }

  static Color primaryPurpleFor(bool isDark) {
    return isDark ? darkPrimaryPurple : primaryPurple;
  }

  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFFA05CBF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const List<BoxShadow> faintShadow = [];

  static List<BoxShadow>? getShadow(BuildContext context) {
    return null; // Minimal and Flat UI: No drop shadows
  }

  static const double borderRadius = 12.0;

  // Minimal and Flat color tokens
  static const Color lightSurface = Color(0xFFF7F7F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color darkSurface = Color(0xFF18181B);
  static const Color darkBorder = Color(0xFF27272A);
  static const Color lightInputFill = Color(0xFFF3F3F5);
  static const Color lightInputBorder = Color(0xFFE5E5EA);
  static const Color lightPurpleBorder = Color(0xFFE9D5FF);
  static const Color onboardingBackground = Color(0xFFE4E1DA);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: accentColor,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
    textTheme: _buildTextTheme(
        GoogleFonts.urbanistTextTheme(ThemeData.light().textTheme)),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.black),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFF3E8FF), // Branded light purple bg
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE9D5FF), width: 1.5),
      ),
      contentTextStyle: const TextStyle(
        color: Color(0xFF6B21A8), // Deep purple text
        fontWeight: FontWeight.bold,
        fontSize: 13.5,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: darkPrimaryPurple,
    colorScheme: ColorScheme.fromSeed(
      seedColor: darkPrimaryPurple,
      primary: darkPrimaryPurple,
      secondary: accentColor,
      surface: Colors.black,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: Colors.black, // Pure Black
    textTheme: _buildTextTheme(
        GoogleFonts.urbanistTextTheme(ThemeData.dark().textTheme)),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1E152A), // Branded dark purple bg
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
      ),
      contentTextStyle: const TextStyle(
        color: Color(0xFFE9D5FF), // Light purple text
        fontWeight: FontWeight.bold,
        fontSize: 13.5,
      ),
    ),
  );

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.displayLarge),
        fontWeight: FontWeight.bold,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.displayMedium),
        fontWeight: FontWeight.bold,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.displaySmall),
        fontWeight: FontWeight.bold,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.headlineLarge),
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.headlineMedium),
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.headlineSmall),
        fontWeight: FontWeight.bold,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.titleLarge),
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.titleMedium),
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.titleSmall),
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
        fontWeight: FontWeight.w500,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.bodySmall),
        fontWeight: FontWeight.w500,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.bodySmall),
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: AppTypography.font(AppFontSizes.caption),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class AppFontSizes {
  static const double displayLarge = 34;
  static const double displayMedium = 30;
  static const double displaySmall = 26;
  static const double authHeader = 28;

  static const double headlineLarge = 24;
  static const double headlineMedium = 22;
  static const double headlineSmall = 20;

  static const double titleLarge = 18;
  static const double titleMedium = 16;
  static const double titleSmall = 14;

  static const double bodyLarge = 17;
  static const double bodyMedium = 15.5;
  static const double bodySmall = 13.5;

  static const double caption = 12.5;
}

class AppTypography {
  static double scale = 1.0;

  static double font(double size) {
    final effectiveSize = size < 12.0 ? 12.0 : size;
    return effectiveSize * scale;
  }
}

class AppTextStyles {
  static TextStyle get displayLarge => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.displayLarge),
        fontWeight: FontWeight.bold,
      );
  static TextStyle get displayMedium => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.displayMedium),
        fontWeight: FontWeight.bold,
      );
  static TextStyle get displaySmall => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.displaySmall),
        fontWeight: FontWeight.bold,
      );
  static TextStyle get authHeader => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.authHeader),
        fontWeight: FontWeight.bold,
      );
  static TextStyle get headlineLarge => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.headlineLarge),
        fontWeight: FontWeight.bold,
      );
  static TextStyle get headlineMedium => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.headlineMedium),
        fontWeight: FontWeight.bold,
      );
  static TextStyle get headlineSmall => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.headlineSmall),
        fontWeight: FontWeight.bold,
      );
  static TextStyle get titleLarge => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.titleLarge),
        fontWeight: FontWeight.w600,
      );
  static TextStyle get titleMedium => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.titleMedium),
        fontWeight: FontWeight.w600,
      );
  static TextStyle get titleSmall => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.titleSmall),
        fontWeight: FontWeight.w600,
      );
  static TextStyle get bodyLarge => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
        fontWeight: FontWeight.w500,
      );
  static TextStyle get bodyMedium => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
        fontWeight: FontWeight.w500,
      );
  static TextStyle get bodySmall => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.bodySmall),
        fontWeight: FontWeight.w500,
      );
  static TextStyle get caption => TextStyle(
        fontSize: AppTypography.font(AppFontSizes.caption),
        fontWeight: FontWeight.w500,
      );
}

class Responsive {
  static double width(BuildContext context, double percentage) {
    // If percentage is like 0.5 (meaning 50%), use as fraction. If it is 50.0, divide by 100.
    final factor = percentage > 1.0 ? percentage / 100.0 : percentage;
    return MediaQuery.of(context).size.width * factor;
  }

  static double height(BuildContext context, double percentage) {
    final factor = percentage > 1.0 ? percentage / 100.0 : percentage;
    return MediaQuery.of(context).size.height * factor;
  }

  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static bool isSmallTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 900;
  }

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 900;
  }

  static double font(BuildContext context, double size) {
    return AppTypography.font(size);
  }

  static EdgeInsets padding(BuildContext context) {
    if (isTablet(context)) {
      return const EdgeInsets.all(24.0);
    } else if (isSmallTablet(context)) {
      return const EdgeInsets.all(20.0);
    }
    return const EdgeInsets.all(16.0);
  }

  static Widget maxContainer(
      {required BuildContext context,
      required Widget child,
      double maxWidth = 750,
      AlignmentGeometry alignment = Alignment.topCenter}) {
    if (isTablet(context) || isSmallTablet(context)) {
      return Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
    }
    return child;
  }
}

class AppSpacing {
  static const double screenMarginH = 20.0;
  static const double screenMarginV = 16.0;
  static const double cardPadding = 12.0;
  static const double sectionGap = 20.0;
  static const double itemGap = 12.0;
  static const double elementGap = 8.0;
  static const double smallGap = 4.0;
}
