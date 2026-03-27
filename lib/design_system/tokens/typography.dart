import 'package:flutter/material.dart';

/// Apple SF Pro typography scale as a ThemeExtension.
///
/// Font sizes and weights match Apple's Human Interface Guidelines.
/// Uses the system font (San Francisco on Apple, Roboto on Android).
///
/// Usage:
///   final typography = HmbTypography.of(context);
///   Text('Title', style: typography.largeTitle);
class HmbTypography extends ThemeExtension<HmbTypography> {
  const HmbTypography({
    required this.largeTitle,
    required this.title1,
    required this.title2,
    required this.title3,
    required this.headline,
    required this.body,
    required this.callout,
    required this.subheadline,
    required this.footnote,
    required this.caption1,
    required this.caption2,
  });

  /// 34pt regular — screen titles, hero text.
  final TextStyle largeTitle;

  /// 28pt regular — section titles.
  final TextStyle title1;

  /// 22pt regular — sub-section titles.
  final TextStyle title2;

  /// 20pt regular — grouped list section headers.
  final TextStyle title3;

  /// 17pt semibold — list row primary text, emphasised body.
  final TextStyle headline;

  /// 17pt regular — default body text.
  final TextStyle body;

  /// 16pt regular — secondary interactive text.
  final TextStyle callout;

  /// 15pt regular — list row secondary text.
  final TextStyle subheadline;

  /// 13pt regular — timestamps, supplementary info.
  final TextStyle footnote;

  /// 12pt regular — small labels, badges.
  final TextStyle caption1;

  /// 11pt regular — smallest text, legal, disclaimers.
  final TextStyle caption2;

  /// Standard scale matching Apple HIG.
  static const standard = HmbTypography(
    largeTitle: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.37,
      height: 41 / 34,
    ),
    title1: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.36,
      height: 34 / 28,
    ),
    title2: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.35,
      height: 28 / 22,
    ),
    title3: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.38,
      height: 25 / 20,
    ),
    headline: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.41,
      height: 22 / 17,
    ),
    body: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.41,
      height: 22 / 17,
    ),
    callout: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.32,
      height: 21 / 16,
    ),
    subheadline: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.24,
      height: 20 / 15,
    ),
    footnote: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.08,
      height: 18 / 13,
    ),
    caption1: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 16 / 12,
    ),
    caption2: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.07,
      height: 13 / 11,
    ),
  );

  /// Convenience accessor via BuildContext.
  static HmbTypography of(BuildContext context) =>
      Theme.of(context).extension<HmbTypography>() ?? standard;

  @override
  HmbTypography copyWith({
    TextStyle? largeTitle,
    TextStyle? title1,
    TextStyle? title2,
    TextStyle? title3,
    TextStyle? headline,
    TextStyle? body,
    TextStyle? callout,
    TextStyle? subheadline,
    TextStyle? footnote,
    TextStyle? caption1,
    TextStyle? caption2,
  }) =>
      HmbTypography(
        largeTitle: largeTitle ?? this.largeTitle,
        title1: title1 ?? this.title1,
        title2: title2 ?? this.title2,
        title3: title3 ?? this.title3,
        headline: headline ?? this.headline,
        body: body ?? this.body,
        callout: callout ?? this.callout,
        subheadline: subheadline ?? this.subheadline,
        footnote: footnote ?? this.footnote,
        caption1: caption1 ?? this.caption1,
        caption2: caption2 ?? this.caption2,
      );

  @override
  HmbTypography lerp(ThemeExtension<HmbTypography>? other, double t) {
    if (other is! HmbTypography) {
      return this;
    }
    return HmbTypography(
      largeTitle: TextStyle.lerp(largeTitle, other.largeTitle, t)!,
      title1: TextStyle.lerp(title1, other.title1, t)!,
      title2: TextStyle.lerp(title2, other.title2, t)!,
      title3: TextStyle.lerp(title3, other.title3, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      callout: TextStyle.lerp(callout, other.callout, t)!,
      subheadline: TextStyle.lerp(subheadline, other.subheadline, t)!,
      footnote: TextStyle.lerp(footnote, other.footnote, t)!,
      caption1: TextStyle.lerp(caption1, other.caption1, t)!,
      caption2: TextStyle.lerp(caption2, other.caption2, t)!,
    );
  }
}
