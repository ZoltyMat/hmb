import 'package:flutter/material.dart';

/// Shows a confirmation dialog when the user tries to navigate back
/// while the form has unsaved changes.
///
/// Wrap any edit screen's [Scaffold] with this widget and supply a
/// callback that returns `true` when the form is dirty.
class UnsavedChangesGuard extends StatelessWidget {
  /// The child widget (typically a [Scaffold]).
  final Widget child;

  /// Return `true` when the form has unsaved changes.
  final bool Function() isDirty;

  const UnsavedChangesGuard({
    required this.child,
    required this.isDirty,
    super.key,
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) {
        return;
      }
      if (!isDirty()) {
        Navigator.of(context).pop();
        return;
      }
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
            'You have unsaved changes. '
            'Are you sure you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if ((shouldDiscard ?? false) && context.mounted) {
        Navigator.of(context).pop();
      }
    },
    child: child,
  );
}
