import 'package:flutter/material.dart';

/// A reusable edge-to-edge thick divider line.
///
/// In light mode, renders a thick grey line.
/// In dark mode, renders a very deep black line (Colors.black).
class SectionDivider extends StatelessWidget {
  final double? thickness;
  final EdgeInsetsGeometry? margin;
  final double? bleedHorizontal;

  const SectionDivider({
    super.key,
    this.thickness,
    this.margin,
    this.bleedHorizontal,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double effectiveHeight = thickness ?? 4.0;

    // Check if margin has negative horizontal components
    double extraBleed = bleedHorizontal ?? 0.0;
    EdgeInsets resolvedMargin = const EdgeInsets.symmetric(vertical: 16.0);

    if (margin is EdgeInsets) {
      final m = margin as EdgeInsets;
      double top = m.top;
      double bottom = m.bottom;
      if (m.left < 0) extraBleed = -m.left;
      if (m.right < 0 && -m.right > extraBleed) extraBleed = -m.right;
      resolvedMargin = EdgeInsets.only(
        top: top > 0 ? top : 0,
        bottom: bottom > 0 ? bottom : 0,
        left: m.left > 0 ? m.left : 0,
        right: m.right > 0 ? m.right : 0,
      );
    } else if (margin != null) {
      resolvedMargin = margin!.resolve(Directionality.of(context));
    }

    Widget dividerBar = Container(
      width: double.infinity,
      height: effectiveHeight,
      color: isDark ? Colors.black : const Color(0xFFE5E7EB),
    );

    if (extraBleed > 0) {
      final screenWidth = MediaQuery.of(context).size.width;
      dividerBar = SizedBox(
        height: effectiveHeight,
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: screenWidth,
          maxWidth: screenWidth,
          minHeight: effectiveHeight,
          maxHeight: effectiveHeight,
          child: Transform.translate(
            offset: Offset(-extraBleed, 0),
            child: Container(
              width: screenWidth,
              height: effectiveHeight,
              color: isDark ? Colors.black : const Color(0xFFE5E7EB),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: resolvedMargin,
      child: dividerBar,
    );
  }
}
