import 'package:flutter/material.dart';

/// Mixin that tracks whether form fields have been modified from their
/// initial values. Apply to any [State] that owns [TextEditingController]s.
///
/// Usage:
///   1. Mix into your State class.
///   2. Call [trackControllers] in [initState] after creating controllers.
///   3. Call [markClean] after a successful save.
///   4. Read [isDirty] to check for unsaved changes.
mixin DirtyFormMixin<T extends StatefulWidget> on State<T> {
  final List<TextEditingController> _trackedControllers = [];
  final Map<TextEditingController, String> _initialValues = {};
  bool _extraDirty = false;

  /// Register controllers to be tracked for changes.
  /// Call this in [initState] after all controllers are initialised.
  void trackControllers(List<TextEditingController> controllers) {
    for (final c in controllers) {
      _trackedControllers.add(c);
      _initialValues[c] = c.text;
      c.addListener(_onFieldChanged);
    }
  }

  /// Mark a non-text-field change (e.g. dropdown, switch, selector).
  void markExtraDirty() {
    _extraDirty = true;
  }

  /// Whether any tracked field differs from its initial value,
  /// or [markExtraDirty] was called.
  bool get isDirty {
    if (_extraDirty) {
      return true;
    }
    for (final c in _trackedControllers) {
      if (c.text != _initialValues[c]) {
        return true;
      }
    }
    return false;
  }

  /// Reset dirty state — call after a successful save.
  void markClean() {
    _extraDirty = false;
    for (final c in _trackedControllers) {
      _initialValues[c] = c.text;
    }
  }

  void _onFieldChanged() {
    // No-op listener; isDirty is computed on-demand.
  }

  /// Remove listeners from tracked controllers. Call in [dispose]
  /// before disposing the controllers themselves.
  void disposeTrackedControllers() {
    for (final c in _trackedControllers) {
      c.removeListener(_onFieldChanged);
    }
    _trackedControllers.clear();
    _initialValues.clear();
  }
}
