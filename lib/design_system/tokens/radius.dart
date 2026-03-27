import 'package:flutter/material.dart';

/// Border radius tokens matching iOS design language.
///
/// Usage:
///   Container(
///     decoration: BoxDecoration(
///       borderRadius: HmbRadius.medium,
///     ),
///   )
abstract final class HmbRadius {
  /// 8pt — small elements (badges, chips, small buttons).
  static const double smallValue = 8;
  static final small = BorderRadius.circular(smallValue);

  /// 10pt — grouped list sections (iOS Settings-style rounded groups).
  static const double groupedValue = 10;
  static final grouped = BorderRadius.circular(groupedValue);

  /// 12pt — cards, dialogs, medium containers.
  static const double mediumValue = 12;
  static final medium = BorderRadius.circular(mediumValue);

  /// 16pt — large containers, sheets, hero cards.
  static const double largeValue = 16;
  static final large = BorderRadius.circular(largeValue);

  /// Fully rounded (for pills, circular avatars).
  static const double fullValue = 9999;
  static final full = BorderRadius.circular(fullValue);
}
