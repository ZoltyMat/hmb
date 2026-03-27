import 'package:flutter/material.dart';

import 'tokens/colors.dart';
import 'tokens/typography.dart';

export 'tokens/colors.dart';
export 'tokens/radius.dart';
export 'tokens/spacing.dart';
export 'tokens/typography.dart';

/// Assembles all design system tokens into a single ThemeExtension.
///
/// Provides a unified accessor so consumers can grab all tokens at once:
///
///   final theme = HmbTheme.of(context);
///   Text('Hello', style: theme.typography.headline.copyWith(
///     color: theme.colors.label,
///   ));
///
/// Or access individual token sets directly:
///
///   final colors = HmbColors.of(context);
///   final typography = HmbTypography.of(context);
class HmbTheme extends ThemeExtension<HmbTheme> {
  const HmbTheme({
    required this.colors,
    required this.typography,
  });

  final HmbColors colors;
  final HmbTypography typography;

  /// Light mode theme.
  static const light = HmbTheme(
    colors: HmbColors.light,
    typography: HmbTypography.standard,
  );

  /// Dark mode theme.
  static const dark = HmbTheme(
    colors: HmbColors.dark,
    typography: HmbTypography.standard,
  );

  /// Convenience accessor via BuildContext.
  static HmbTheme of(BuildContext context) =>
      Theme.of(context).extension<HmbTheme>() ?? light;

  /// Returns a [ThemeData] for light mode with all extensions registered.
  static ThemeData lightThemeData() => _buildThemeData(
        brightness: Brightness.light,
        hmbTheme: light,
      );

  /// Returns a [ThemeData] for dark mode with all extensions registered.
  static ThemeData darkThemeData() => _buildThemeData(
        brightness: Brightness.dark,
        hmbTheme: dark,
      );

  static ThemeData _buildThemeData({
    required Brightness brightness,
    required HmbTheme hmbTheme,
  }) {
    final colors = hmbTheme.colors;
    final typography = hmbTheme.typography;

    return ThemeData(
      brightness: brightness,
      colorSchemeSeed: colors.tint,
      scaffoldBackgroundColor: colors.groupedBackground,
      extensions: <ThemeExtension>[
        hmbTheme,
        colors,
        typography,
      ],
    );
  }

  @override
  HmbTheme copyWith({
    HmbColors? colors,
    HmbTypography? typography,
  }) =>
      HmbTheme(
        colors: colors ?? this.colors,
        typography: typography ?? this.typography,
      );

  @override
  HmbTheme lerp(ThemeExtension<HmbTheme>? other, double t) {
    if (other is! HmbTheme) {
      return this;
    }
    return HmbTheme(
      colors: colors.lerp(other.colors, t),
      typography: typography.lerp(other.typography, t),
    );
  }
}
