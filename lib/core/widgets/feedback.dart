import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/peer/peer_protocol.dart';
import '../../data/repositories/tasting_repository.dart';
import '../theme/glas_theme.dart';

/// An error, in the app's own voice.
///
/// The Postgres functions in `0001_init.sql` raise Danish sentences ("Koden
/// findes ikke"), so for those the server's message is already the right thing
/// to show. Anything else — a socket failure, a decoding error — becomes a
/// plain line rather than a stack trace shown to someone mid-tasting.
String describeError(Object error) => switch (error) {
      // The app's own exceptions already carry the sentence to show — the
      // refused join code, the glass that has already been poured. Falling
      // through to the catch-all below would throw all of that away.
      TastingException(:final message) => message,
      PeerProtocolException(:final message) => message,
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

/// A short list of choices, in the app's own palette.
Future<T?> showGlasChoice<T>(
  BuildContext context, {
  required String title,
  required List<({String label, T value})> options,
}) {
  final c = context.glas;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
            child: Text(title, style: GlasType.display(20, color: c.ink)),
          ),
          for (final option in options)
            InkWell(
              onTap: () => Navigator.pop(context, option.value),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: Text(option.label,
                    style: GlasType.body(15.5, color: c.ink)),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
