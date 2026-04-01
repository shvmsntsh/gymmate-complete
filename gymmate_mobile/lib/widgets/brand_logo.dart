import 'package:flutter/material.dart';

enum BrandLogoVariant { mark, full }

class BrandLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BrandLogoVariant variant;

  const BrandLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.variant = BrandLogoVariant.mark,
  });

  static String assetForTheme(
    BuildContext context, {
    BrandLogoVariant variant = BrandLogoVariant.mark,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (variant == BrandLogoVariant.full) {
      return isDark
          ? 'assets/images/gymmate_logo_light.png'
          : 'assets/images/gymmate_logo_dark.png';
    }
    return isDark
        ? 'assets/images/gymmate_logo_mark_light.png'
        : 'assets/images/gymmate_logo_mark_dark.png';
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetForTheme(context, variant: variant),
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
    );
  }
}
