import 'package:flutter/material.dart';

/// Apple-inspired semantic color tokens with light/dark mode support.
///
/// Usage:
///   final colors = HmbColors.of(context);
///   Text('Hello', style: TextStyle(color: colors.label));
class HmbColors extends ThemeExtension<HmbColors> {
  const HmbColors({
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.quaternaryLabel,
    required this.systemBackground,
    required this.secondarySystemBackground,
    required this.tertiarySystemBackground,
    required this.groupedBackground,
    required this.secondaryGroupedBackground,
    required this.separator,
    required this.opaqueSeparator,
    required this.tint,
    required this.systemRed,
    required this.systemGreen,
    required this.systemYellow,
    required this.systemOrange,
    required this.systemBlue,
    required this.systemIndigo,
    required this.systemPurple,
    required this.systemPink,
    required this.systemTeal,
    required this.systemGray,
  });

  // MARK: - Label Colors
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color quaternaryLabel;

  // MARK: - Background Colors
  final Color systemBackground;
  final Color secondarySystemBackground;
  final Color tertiarySystemBackground;
  final Color groupedBackground;
  final Color secondaryGroupedBackground;

  // MARK: - Separator Colors
  final Color separator;
  final Color opaqueSeparator;

  // MARK: - Tint (primary interactive color)
  final Color tint;

  // MARK: - System Colors
  final Color systemRed;
  final Color systemGreen;
  final Color systemYellow;
  final Color systemOrange;
  final Color systemBlue;
  final Color systemIndigo;
  final Color systemPurple;
  final Color systemPink;
  final Color systemTeal;
  final Color systemGray;

  /// Light mode token values (iOS 17 reference).
  static const light = HmbColors(
    label: Color(0xFF000000),
    secondaryLabel: Color(0x993C3C43),
    tertiaryLabel: Color(0x4D3C3C43),
    quaternaryLabel: Color(0x2E3C3C43),
    systemBackground: Color(0xFFFFFFFF),
    secondarySystemBackground: Color(0xFFF2F2F7),
    tertiarySystemBackground: Color(0xFFFFFFFF),
    groupedBackground: Color(0xFFF2F2F7),
    secondaryGroupedBackground: Color(0xFFFFFFFF),
    separator: Color(0x493C3C43),
    opaqueSeparator: Color(0xFFC6C6C8),
    tint: Color(0xFF007AFF),
    systemRed: Color(0xFFFF3B30),
    systemGreen: Color(0xFF34C759),
    systemYellow: Color(0xFFFFCC00),
    systemOrange: Color(0xFFFF9500),
    systemBlue: Color(0xFF007AFF),
    systemIndigo: Color(0xFF5856D6),
    systemPurple: Color(0xFFAF52DE),
    systemPink: Color(0xFFFF2D55),
    systemTeal: Color(0xFF5AC8FA),
    systemGray: Color(0xFF8E8E93),
  );

  /// Dark mode token values (iOS 17 reference).
  static const dark = HmbColors(
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0x99EBEBF5),
    tertiaryLabel: Color(0x4DEBEBF5),
    quaternaryLabel: Color(0x29EBEBF5),
    systemBackground: Color(0xFF000000),
    secondarySystemBackground: Color(0xFF1C1C1E),
    tertiarySystemBackground: Color(0xFF2C2C2E),
    groupedBackground: Color(0xFF000000),
    secondaryGroupedBackground: Color(0xFF1C1C1E),
    separator: Color(0x99545458),
    opaqueSeparator: Color(0xFF38383A),
    tint: Color(0xFF0A84FF),
    systemRed: Color(0xFFFF453A),
    systemGreen: Color(0xFF30D158),
    systemYellow: Color(0xFFFFD60A),
    systemOrange: Color(0xFFFF9F0A),
    systemBlue: Color(0xFF0A84FF),
    systemIndigo: Color(0xFF5E5CE6),
    systemPurple: Color(0xFFBF5AF2),
    systemPink: Color(0xFFFF375F),
    systemTeal: Color(0xFF64D2FF),
    systemGray: Color(0xFF8E8E93),
  );

  /// Convenience accessor via BuildContext.
  static HmbColors of(BuildContext context) =>
      Theme.of(context).extension<HmbColors>() ?? light;

  @override
  HmbColors copyWith({
    Color? label,
    Color? secondaryLabel,
    Color? tertiaryLabel,
    Color? quaternaryLabel,
    Color? systemBackground,
    Color? secondarySystemBackground,
    Color? tertiarySystemBackground,
    Color? groupedBackground,
    Color? secondaryGroupedBackground,
    Color? separator,
    Color? opaqueSeparator,
    Color? tint,
    Color? systemRed,
    Color? systemGreen,
    Color? systemYellow,
    Color? systemOrange,
    Color? systemBlue,
    Color? systemIndigo,
    Color? systemPurple,
    Color? systemPink,
    Color? systemTeal,
    Color? systemGray,
  }) =>
      HmbColors(
        label: label ?? this.label,
        secondaryLabel: secondaryLabel ?? this.secondaryLabel,
        tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel,
        quaternaryLabel: quaternaryLabel ?? this.quaternaryLabel,
        systemBackground: systemBackground ?? this.systemBackground,
        secondarySystemBackground:
            secondarySystemBackground ?? this.secondarySystemBackground,
        tertiarySystemBackground:
            tertiarySystemBackground ?? this.tertiarySystemBackground,
        groupedBackground: groupedBackground ?? this.groupedBackground,
        secondaryGroupedBackground:
            secondaryGroupedBackground ?? this.secondaryGroupedBackground,
        separator: separator ?? this.separator,
        opaqueSeparator: opaqueSeparator ?? this.opaqueSeparator,
        tint: tint ?? this.tint,
        systemRed: systemRed ?? this.systemRed,
        systemGreen: systemGreen ?? this.systemGreen,
        systemYellow: systemYellow ?? this.systemYellow,
        systemOrange: systemOrange ?? this.systemOrange,
        systemBlue: systemBlue ?? this.systemBlue,
        systemIndigo: systemIndigo ?? this.systemIndigo,
        systemPurple: systemPurple ?? this.systemPurple,
        systemPink: systemPink ?? this.systemPink,
        systemTeal: systemTeal ?? this.systemTeal,
        systemGray: systemGray ?? this.systemGray,
      );

  @override
  HmbColors lerp(ThemeExtension<HmbColors>? other, double t) {
    if (other is! HmbColors) {
      return this;
    }
    return HmbColors(
      label: Color.lerp(label, other.label, t)!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      tertiaryLabel: Color.lerp(tertiaryLabel, other.tertiaryLabel, t)!,
      quaternaryLabel: Color.lerp(quaternaryLabel, other.quaternaryLabel, t)!,
      systemBackground:
          Color.lerp(systemBackground, other.systemBackground, t)!,
      secondarySystemBackground: Color.lerp(
        secondarySystemBackground,
        other.secondarySystemBackground,
        t,
      )!,
      tertiarySystemBackground: Color.lerp(
        tertiarySystemBackground,
        other.tertiarySystemBackground,
        t,
      )!,
      groupedBackground:
          Color.lerp(groupedBackground, other.groupedBackground, t)!,
      secondaryGroupedBackground: Color.lerp(
        secondaryGroupedBackground,
        other.secondaryGroupedBackground,
        t,
      )!,
      separator: Color.lerp(separator, other.separator, t)!,
      opaqueSeparator: Color.lerp(opaqueSeparator, other.opaqueSeparator, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
      systemRed: Color.lerp(systemRed, other.systemRed, t)!,
      systemGreen: Color.lerp(systemGreen, other.systemGreen, t)!,
      systemYellow: Color.lerp(systemYellow, other.systemYellow, t)!,
      systemOrange: Color.lerp(systemOrange, other.systemOrange, t)!,
      systemBlue: Color.lerp(systemBlue, other.systemBlue, t)!,
      systemIndigo: Color.lerp(systemIndigo, other.systemIndigo, t)!,
      systemPurple: Color.lerp(systemPurple, other.systemPurple, t)!,
      systemPink: Color.lerp(systemPink, other.systemPink, t)!,
      systemTeal: Color.lerp(systemTeal, other.systemTeal, t)!,
      systemGray: Color.lerp(systemGray, other.systemGray, t)!,
    );
  }
}
