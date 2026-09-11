/// The wire format phones use to run a tasting between themselves.
///
/// The host's device is the source of truth. Guests hold a mirror of it and
/// send back only their own ratings; the host merges, persists, and pushes a
/// fresh snapshot to everyone. There is no merge conflict to resolve because
/// every writer owns a disjoint slice of the data.
///
/// Frames are length-prefixed so a bottle photo can travel as raw bytes rather
/// than base64 — an 8 MB JPEG would otherwise cost 11 MB of string:
///
/// ```
///   [4 bytes] total payload length, big-endian
///   [4 bytes] JSON header length, big-endian
///   [n bytes] JSON header, UTF-8
///   [m bytes] optional binary blob
/// ```
library;

import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// The Bonjour service type the host advertises on.
const String kServiceType = '_iglasset._tcp';

/// TXT keys on the advertised record. Kept to nine characters, as RFC 6763 asks.
const String kTxtCode = 'code';
const String kTxtTitle = 'title';
const String kTxtHost = 'host';
const String kTxtGlasses = 'glasses';
const String kTxtVersion = 'v';

/// Bumped when the shape below changes incompatibly. A guest on a different
/// version is turned away with a readable message rather than half-working.
const int kProtocolVersion = 1;

enum PeerMessageType {
  /// guest → host: who I am, and the code I was given.
  hello,

  /// host → guest: you're in; here is the whole evening as you may see it.
  welcome,

  /// host → everyone: something changed; here it is again.
  sync,

  /// guest → host: my score, notes and guess for one glass.
  rating,

  /// guest → host: I don't have this photo yet.
  requestImage,

  /// host → guest: here it is, bytes attached.
  image,

  /// host → guest: I can't do that, and here's why in Danish.
  error,

  /// either way: I'm leaving.
  bye;

  static PeerMessageType? fromWire(String value) {
    for (final type in PeerMessageType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

/// One frame: a typed JSON header, and for images a blob riding alongside.
class PeerMessage {
  const PeerMessage(this.type, this.payload, {this.blob});

  final PeerMessageType type;
  final Map<String, dynamic> payload;
  final Uint8List? blob;

  factory PeerMessage.error(String message) =>
      PeerMessage(PeerMessageType.error, {'message': message});

  Uint8List encode() {
    final header = utf8.encode(
      jsonEncode({'type': type.name, 'v': kProtocolVersion, ...payload}),
    );
    final body = blob ?? Uint8List(0);

    final frame = BytesBuilder(copy: false)
      ..add(_uint32(header.length + body.length + 4))
      ..add(_uint32(header.length))
      ..add(header)
      ..add(body);
    return frame.takeBytes();
  }

  static Uint8List _uint32(int value) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, value);

  @override
  String toString() =>
      'PeerMessage(${type.name}, ${payload.keys.toList()}, '
      'blob=${blob?.length ?? 0})';
}

/// Turns a socket's byte stream into whole messages.
///
/// TCP gives no message boundaries, so this buffers until a complete frame has
/// arrived and only then hands one up.
///
/// Chunks are queued rather than concatenated on arrival. Re-joining the buffer
/// on every chunk would be quadratic, which matters here: a bottle photo comes
/// in over a hundred packets, and copying the growing buffer each time would
/// cost hundreds of megabytes of memory traffic per image.
///
/// A frame larger than [maxFrameBytes] is refused rather than allowed to
/// exhaust memory — the biggest legitimate frame is one photo, and the picker
/// already caps those.
class PeerDecoder {
  PeerDecoder({this.maxFrameBytes = 12 * 1024 * 1024});

  final int maxFrameBytes;
  final _chunks = Queue<Uint8List>();
  int _available = 0;

  /// Feeds bytes in, gets whole messages out.
  Iterable<PeerMessage> add(List<int> chunk) sync* {
    if (chunk.isEmpty) return;
    _chunks.add(chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
    _available += chunk.length;

    while (true) {
      if (_available < 8) return;

      final prefix = _peek(8);
      final view = prefix.buffer.asByteData(prefix.offsetInBytes);
      final total = view.getUint32(0);

      if (total > maxFrameBytes) {
        throw PeerProtocolException(
          'Modtog en urimeligt stor besked ($total bytes).',
        );
      }
      if (_available < 4 + total) return;

      final headerLength = view.getUint32(4);
      if (headerLength + 4 > total) {
        throw const PeerProtocolException('Beskeden er i stykker.');
      }

      final frame = _take(4 + total);
      final header = Uint8List.sublistView(frame, 8, 8 + headerLength);
      final blob = frame.length > 8 + headerLength
          ? Uint8List.sublistView(frame, 8 + headerLength)
          : null;

      final json = jsonDecode(utf8.decode(header)) as Map<String, dynamic>;
      final type = PeerMessageType.fromWire(json['type'] as String? ?? '');
      // Forward compatible: a message kind we don't know is skipped, not fatal.
      if (type == null) continue;

      yield PeerMessage(type, json, blob: blob);
    }
  }

  /// Reads the first [n] bytes without consuming them.
  Uint8List _peek(int n) {
    final out = Uint8List(n);
    var written = 0;
    for (final chunk in _chunks) {
      final take = (n - written) < chunk.length ? n - written : chunk.length;
      out.setRange(written, written + take, chunk);
      written += take;
      if (written == n) break;
    }
    return out;
  }

  /// Consumes and returns the first [n] bytes.
  Uint8List _take(int n) {
    final out = Uint8List(n);
    var written = 0;
    while (written < n) {
      final chunk = _chunks.removeFirst();
      final remaining = n - written;
      if (chunk.length <= remaining) {
        out.setRange(written, written + chunk.length, chunk);
        written += chunk.length;
      } else {
        out.setRange(written, n, chunk);
        _chunks.addFirst(Uint8List.sublistView(chunk, remaining));
        written = n;
      }
    }
    _available -= n;
    return out;
  }
}

class PeerProtocolException implements Exception {
  const PeerProtocolException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The snapshot a host sends and a guest stores.
///
/// It is deliberately the same map shape the local store persists, so a guest
/// can write what arrives straight to disk and read it back offline months
/// later.
class TastingSnapshot {
  const TastingSnapshot({
    required this.tasting,
    required this.items,
    required this.participants,
    required this.profiles,
    required this.ratings,
  });

  final Map<String, dynamic> tasting;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>> ratings;

  Map<String, dynamic> toJson() => {
        'tasting': tasting,
        'items': items,
        'participants': participants,
        'profiles': profiles,
        'ratings': ratings,
      };

  factory TastingSnapshot.fromJson(Map<String, dynamic> json) =>
      TastingSnapshot(
        tasting: Map<String, dynamic>.from(json['tasting'] as Map),
        items: _rows(json['items']),
        participants: _rows(json['participants']),
        profiles: _rows(json['profiles']),
        ratings: _rows(json['ratings']),
      );

  static List<Map<String, dynamic>> _rows(Object? value) => [
        for (final row in (value as List? ?? const []))
          Map<String, dynamic>.from(row as Map),
      ];
}
