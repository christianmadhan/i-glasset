import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/data/peer/peer_protocol.dart';

void main() {
  group('PeerDecoder', () {
    test('round-trips a control message', () {
      final decoder = PeerDecoder();
      final sent = PeerMessage(PeerMessageType.hello, {
        'profile': {'id': 'abc', 'display_name': 'Sofie'},
        kTxtCode: 'GLAS42',
      });

      final got = decoder.add(sent.encode()).toList();

      expect(got, hasLength(1));
      expect(got.single.type, PeerMessageType.hello);
      expect(got.single.payload[kTxtCode], 'GLAS42');
      expect(
        (got.single.payload['profile'] as Map)['display_name'],
        'Sofie',
      );
      expect(got.single.blob, isNull);
    });

    test('carries a binary blob beside the header', () {
      final decoder = PeerDecoder();
      final bytes = Uint8List.fromList(List.generate(5000, (i) => i % 256));

      final got = decoder
          .add(PeerMessage(
            PeerMessageType.image,
            {'item_id': 'i1', 'sha256': 'abc'},
            blob: bytes,
          ).encode())
          .toList();

      expect(got.single.type, PeerMessageType.image);
      expect(got.single.payload['item_id'], 'i1');
      expect(got.single.blob, bytes);
    });

    // TCP hands over arbitrary slices, so the decoder has to hold on until a
    // whole frame has arrived. This is the bug class that shows up only on a
    // real network, so it's pinned here.
    test('reassembles a message split across many chunks', () {
      final decoder = PeerDecoder();
      final bytes = Uint8List.fromList(List.generate(40000, (i) => i % 251));
      final frame = PeerMessage(
        PeerMessageType.image,
        {'item_id': 'i1'},
        blob: bytes,
      ).encode();

      final random = Random(7);
      final received = <PeerMessage>[];
      var offset = 0;
      while (offset < frame.length) {
        final size = min(1 + random.nextInt(1500), frame.length - offset);
        received.addAll(decoder.add(
          Uint8List.sublistView(frame, offset, offset + size),
        ));
        offset += size;
      }

      expect(received, hasLength(1));
      expect(received.single.blob, bytes);
    });

    test('yields several messages arriving in one chunk', () {
      final decoder = PeerDecoder();
      final buffer = <int>[
        ...const PeerMessage(PeerMessageType.bye, {}).encode(),
        ...PeerMessage(PeerMessageType.rating, {
          'rating': {'score': 8.5},
        }).encode(),
        ...PeerMessage.error('Koden findes ikke.').encode(),
      ];

      final got = decoder.add(buffer).toList();

      expect(got.map((m) => m.type), [
        PeerMessageType.bye,
        PeerMessageType.rating,
        PeerMessageType.error,
      ]);
      expect(got.last.payload['message'], 'Koden findes ikke.');
    });

    test('holds a partial frame until the rest arrives', () {
      final decoder = PeerDecoder();
      final frame = PeerMessage(PeerMessageType.sync, {'x': 1}).encode();

      expect(decoder.add(Uint8List.sublistView(frame, 0, 5)), isEmpty);
      expect(decoder.add(Uint8List.sublistView(frame, 5)), hasLength(1));
    });

    test('skips a message kind it does not know, rather than dying', () {
      final decoder = PeerDecoder();
      // Hand-roll a frame with an unknown type, followed by a good one.
      final unknown = PeerMessage(PeerMessageType.sync, {}).encode();
      final patched = Uint8List.fromList(unknown)
        ..setRange(8, 8 + 13, '{"type":"zzzz"'.codeUnits);

      final good = PeerMessage(PeerMessageType.bye, {}).encode();
      final got = decoder.add(<int>[...patched, ...good]).toList();

      expect(got.map((m) => m.type), [PeerMessageType.bye]);
    });

    test('refuses an absurdly large frame instead of allocating it', () {
      final decoder = PeerDecoder(maxFrameBytes: 1024);
      final huge = Uint8List(8)..buffer.asByteData().setUint32(0, 1 << 20);

      expect(
        () => decoder.add(huge).toList(),
        throwsA(isA<PeerProtocolException>()),
      );
    });
  });

  group('TastingSnapshot', () {
    test('survives the trip as plain maps', () {
      const snapshot = TastingSnapshot(
        tasting: {'id': 't1', 'title': 'Italienske rødvine'},
        items: [
          {'id': 'i1', 'position': 1, 'revealed_at': null},
        ],
        participants: [
          {'id': 'p1', 'user_id': 'u1'},
        ],
        profiles: [
          {'id': 'u1', 'display_name': 'Sofie'},
        ],
        ratings: [
          {'id': 'r1', 'score': 8.5},
        ],
      );

      final restored = TastingSnapshot.fromJson(snapshot.toJson());

      expect(restored.tasting['title'], 'Italienske rødvine');
      expect(restored.items.single['position'], 1);
      expect(restored.profiles.single['display_name'], 'Sofie');
      expect(restored.ratings.single['score'], 8.5);
    });
  });
}
