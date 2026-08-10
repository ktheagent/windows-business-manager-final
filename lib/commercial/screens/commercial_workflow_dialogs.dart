import 'package:flutter/material.dart';

/// Shared helpers for explicit user choices in Commercial Suite workflows.
///
/// This file intentionally contains only reusable UI primitives. Individual
/// panels remain responsible for calling the appropriate service methods.
Future<T?> showCommercialChoiceDialog<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext, void Function(void Function())) builder,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: builder(context, setState),
      ),
    ),
  );
}
