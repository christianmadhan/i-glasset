import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/core/widgets/feedback.dart';
import 'package:i_glasset/data/peer/peer_protocol.dart';
import 'package:i_glasset/data/repositories/tasting_repository.dart';

/// The repository and the peer layer raise Danish sentences written for the
/// person holding the phone — a wrong join code, a glass already poured. They
/// are only worth writing if they survive as far as the snackbar.
void main() {
  test('the app\'s own exceptions keep their message', () {
    expect(
      describeError(const TastingException(
        'Ingen smagning med den kode i nærheden.',
      )),
      'Ingen smagning med den kode i nærheden.',
    );
    expect(
      describeError(const PeerProtocolException('Koden passer ikke.')),
      'Koden passer ikke.',
    );
  });

  test('anything else becomes a plain line, not a stack trace', () {
    expect(describeError(const SocketException('ECONNREFUSED')),
        'Ingen forbindelse. Tjek dit netværk.');
    expect(describeError(ArgumentError('boom')), 'Noget gik galt. Prøv igen.');
  });
}
