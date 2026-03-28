import 'package:flutter/widgets.dart';

/// Mixin that auto-scrolls to keep the focused field visible above the
/// keyboard.
///
/// Usage:
/// ```dart
/// class _MyFormState extends State<MyForm> with KeyboardScrollMixin {
///   final _scrollController = ScrollController();
///
///   @override
///   ScrollController get keyboardScrollController => _scrollController;
///
///   @override
///   void initState() {
///     super.initState();
///     initKeyboardScroll([focusNode1, focusNode2]);
///   }
///
///   @override
///   void dispose() {
///     disposeKeyboardScroll();
///     super.dispose();
///   }
/// }
/// ```
mixin KeyboardScrollMixin<T extends StatefulWidget> on State<T> {
  /// The scroll controller that wraps the form content.
  ScrollController get keyboardScrollController;

  final _listeners = <FocusNode, VoidCallback>{};

  /// Register [FocusNode]s for auto-scroll behavior.
  void initKeyboardScroll(List<FocusNode> focusNodes) {
    for (final node in focusNodes) {
      void listener() {
        if (node.hasFocus) {
          _scrollToFocusedNode(node);
        }
      }

      node.addListener(listener);
      _listeners[node] = listener;
    }
  }

  /// Clean up listeners. Call from [dispose].
  void disposeKeyboardScroll() {
    for (final entry in _listeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _listeners.clear();
  }

  void _scrollToFocusedNode(FocusNode node) {
    // Wait one frame for the keyboard to appear and layout to settle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final focusContext = node.context;
      if (focusContext == null) {
        return;
      }

      final renderObject = focusContext.findRenderObject();
      if (renderObject == null) {
        return;
      }

      Scrollable.ensureVisible(
        focusContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    });
  }
}
