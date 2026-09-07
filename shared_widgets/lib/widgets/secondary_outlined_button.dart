import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Full-width outlined secondary action matching [CustomButton] height and radius.
class SecondaryOutlinedButton extends StatelessWidget {
  /// Label shown on the button.
  final String label;

  /// Called when the button is pressed.
  final VoidCallback onPressed;

  /// Whether the button shows a loading indicator.
  final bool isLoading;

  const SecondaryOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = AppTheme.primaryColor;
    final textColor = isDark ? Colors.white : AppTheme.primaryColor;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
