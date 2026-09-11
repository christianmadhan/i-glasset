import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/glas_theme.dart';

/// An error, in the app's own voice.
///
/// The Postgres functions in `0001_init.sql` raise Danish sentences ("Koden
/// findes ikke"), so for those the server's message is already the right thing
/// to show. Anything else — a socket failure, a decoding error — becomes a
/// plain line rather than a stack trace shown to someone mid-tasting.
String describeError(Object error) => switch (error) {
      PostgrestException(:final message) => message,
      AuthException(:final message) => message,
      StorageException(:final message) => message,
      StateError(:final message) => message,
      SocketException() => 'Ingen forbindelse. Tjek dit netværk.',
      ClientException() => 'Kunne ikke få fat i serveren. Prøv igen.',
      _ => 'Noget gik galt. Prøv igen.',
    };

/// Surfaces an error as a snackbar.
void showGlasError(BuildContext context, Object error) {
  final c = context.glas;
  final message = describeError(error);

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: c.night,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        content: Text(message, style: GlasType.body(14, color: c.nightInk)),
      ),
    );
}

void showGlasMessage(BuildContext context, String message) {
  final c = context.glas;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: c.night,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        content: Text(message, style: GlasType.body(14, color: c.nightInk)),
      ),
    );
}

/// A yes/no sheet in the app's own palette.
Future<bool> showGlasConfirm(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'OK',
  String cancelLabel = 'Annullér',
}) async {
  final c = context.glas;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: GlasType.display(20, color: c.ink)),
      content: Text(body, style: GlasType.body(14, color: c.muted, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel, style: GlasType.body(14, color: c.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel, style: GlasType.body(14, color: c.accent)),
        ),
      ],
    ),
  );
  return result ?? false;
}
