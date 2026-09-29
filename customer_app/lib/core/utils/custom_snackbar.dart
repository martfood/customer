import 'package:flutter/material.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

enum SnackBarType { success, warning, error, info }

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Consistent snackbar color across the app:
    // Light mode: background = app grey, font = black
    // Dark mode: background = app white, font = black
    final Color backgroundColor = isDark ? Colors.white : AppTheme.lightInputFill;
    const Color textColor = Colors.black;
    final Color borderColor = isDark ? const Color(0xFFE5E5EA) : AppTheme.lightInputBorder;

    Color iconColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        iconColor = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
        break;
      case SnackBarType.warning:
        iconColor = const Color(0xFFD97706);
        icon = Icons.warning_amber_rounded;
        break;
      case SnackBarType.error:
        iconColor = const Color(0xFFC62828);
        icon = Icons.error_outline_rounded;
        break;
      case SnackBarType.info:
        iconColor = AppTheme.primaryPurple;
        icon = Icons.info_outline_rounded;
        break;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1.0),
        ),
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
