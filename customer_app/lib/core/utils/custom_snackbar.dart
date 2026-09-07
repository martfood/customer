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

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    Color iconColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = isDark ? const Color(0xFF14321A) : const Color(0xFFE8F5E9);
        borderColor = isDark ? const Color(0xFF2E7D32) : const Color(0xFFA5D6A7);
        textColor = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
        iconColor = textColor;
        icon = Icons.check_circle_rounded;
        break;
      case SnackBarType.warning:
        backgroundColor = isDark ? const Color(0xFF3B2E1C) : const Color(0xFFFEF3C7);
        borderColor = const Color(0xFFD97706);
        textColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
        iconColor = borderColor;
        icon = Icons.warning_amber_rounded;
        break;
      case SnackBarType.error:
        backgroundColor = isDark ? const Color(0xFF4A1515) : const Color(0xFFFFEBEE);
        borderColor = isDark ? const Color(0xFFC62828) : const Color(0xFFEF9A9A);
        textColor = isDark ? const Color(0xFFE57373) : const Color(0xFFC62828);
        iconColor = textColor;
        icon = Icons.error_outline_rounded;
        break;
      case SnackBarType.info:
      default:
        backgroundColor = isDark ? const Color(0xFF1E152A) : const Color(0xFFF3E8FF);
        borderColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE9D5FF);
        textColor = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF6B21A8);
        iconColor = textColor;
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
          side: BorderSide(color: borderColor, width: 1.5),
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
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
