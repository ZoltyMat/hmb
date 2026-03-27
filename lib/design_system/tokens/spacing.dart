/// 8pt grid spacing tokens.
///
/// All padding, margins, and gaps should use these values to maintain
/// consistent rhythm across the app.
///
/// Usage:
///   Padding(padding: EdgeInsets.all(HmbSpacing.md))
///   SizedBox(height: HmbSpacing.lg)
abstract final class HmbSpacing {
  /// 4pt — tight inner padding (icon gaps, inline spacing).
  static const double xs = 4;

  /// 8pt — standard inner padding (list item padding, field gaps).
  static const double sm = 8;

  /// 12pt — medium spacing (section inner padding, form field gaps).
  static const double md = 12;

  /// 16pt — standard outer padding (screen margins, card padding).
  static const double lg = 16;

  /// 24pt — large spacing (section gaps, card margins).
  static const double xl = 24;

  /// 32pt — extra large spacing (screen section separators, hero spacing).
  static const double xxl = 32;

  /// Horizontal screen margin (matches iOS grouped list inset).
  static const double screenHorizontal = 16;

  /// Vertical screen padding (top/bottom safe area content offset).
  static const double screenVertical = 20;
}
