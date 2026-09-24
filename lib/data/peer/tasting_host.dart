import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

import 'peer_protocol.dart';

/// What a guest is allowed to ask the host to do.
///
/// The host phone owns the evening, so every mutation arrives here and is
/// applied by the same code that would apply it locally. The repository
/// supplies these; this class only moves bytes.
abstract interface class HostDelegate {
  /// Whether this code opens this room, and whether the person may come in.
  /// Returns a refusal message, or null to admit them.
  Future<String?> admit({required String joinCode, required Map<String, dynamic> profile});

  /// The evening as this guest may see it — unrevealed glasses redacted.
  /// Keyed by the code they joined with, so a phone coming back for a finished
  /// evening is not handed whatever the host has opened since.
  Future<TastingSnapshot> snapshotFor(String userId, {required String joinCode});

  /// A guest's rating for one glass.
  Future<void> applyRating(String userId, Map<String, dynamic> rating);

  /// Someone left.
  Future<void> onLeave(String userId, {required String joinCode});

  /// The bytes of a revealed glass's photo, or null if there is none.
  Future<({Uint8List bytes, String sha256, String extension})?> imageFor(
    String itemId,
  );
}

/// Runs the evening for the phones in the room.
///
/// Discovery is Bonjour on the local Wi-Fi, so nothing leaves the flat and no
/// account, pairing or internet connection is needed. The TCP port is ephemeral
/// and advertised in the record, so several tastings can run in the same house
/// without colliding.
class TastingHost {
  TastingHost({required this.delegate});

  final HostDelegate delegate;

  ServerSocket? _server;
  BonsoirBroadcast? _broadcast;
  final _guests = <String, _GuestConnection>{};

  final _statusController = StreamController<HostStatus>.broadcast();

  /// Who is currently connected, so the lobby can show them arriving.
  Stream<HostStatus> get status => _statusController.stream;

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;
  int get guestCount => _guests.length;

  /// Starts listening and puts the tasting on the air.
  Future<void> start({
    required String joinCode,
    required String title,
    required String hostName,
    required int glasses,
  }) async {
    // A second evening in the same session must not keep advertising the
    // first one's code and title.
    if (_server != null) await stop();

    // Port 0: let the OS pick a free one and tell everyone through the record.
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _server = server;

    server.listen(
      _accept,
      onError: (Object error) => debugPrint('I Glasset host socket: $error'),
    );

    // If Bonjour is unavailable the socket still serves: a phone that already
    // knows the address (one that was in the room and dropped) can come back.
    try {
      final broadcast = BonsoirBroadcast(
        service: BonsoirService(
          name: 'I Glasset $joinCode',
          type: kServiceType,
          port: server.port,
          attributes: {
            kTxtCode: joinCode,
            kTxtTitle: title,
            kTxtHost: hostName,
            kTxtGlasses: '$glasses',
            kTxtVersion: '$kProtocolVersion',
          },
        ),
      );
      await broadcast.initialize();
      await broadcast.start();
      _broadcast = broadcast;
    } on Object catch (error) {
      debugPrint('I Glasset host: kunne ikke annoncere på netværket: $error');
    }

    _emit();
  }

  /// Takes the tasting off the air but keeps serving the phones that know
  /// where it is — what a finished evening wants: no new joiners, but anyone
  /// who dropped out can still come back for the final picture.
  Future<void> stopAdvertising() async {
    await _broadcast?.stop();
    _broadcast = null;
  }

  /// Takes the tasting off the air and disconnects everyone.
  Future<void> stop() async {
    for (final guest in _guests.values.toList()) {
      guest.send(const PeerMessage(PeerMessageType.bye, {}));
      await guest.close();
    }
    _guests.clear();

    await _broadcast?.stop();
    _broadcast = null;

    await _server?.close();
    _server = null;

    _emit();
  }

  /// Pushes a fresh snapshot to everyone. Called after any change the host
  /// makes — revealing a glass, moving on, editing the programme.
  /// Puts one guest out: tells them why, closes the socket, forgets them. The
  /// delegate has already struck them from the room, so the socket closing
  /// must not count as them leaving — hence the removal before the close.
  Future<void> expel(String userId, {required String reason}) async {
    final guest = _guests.remove(userId);
    if (guest == null) return;
    guest.send(PeerMessage.error(reason));
    await guest.close();
    _emit();
  }

  Future<void> broadcastSync() async {
    for (final guest in _guests.values.toList()) {
      if (guest.userId == null) continue;
      try {
        final snapshot = await delegate.snapshotFor(
          guest.userId!,
          joinCode: guest.joinCode!,
        );
        guest.send(PeerMessage(PeerMessageType.sync, snapshot.toJson()));
      } on Object catch (error) {
        debugPrint('I Glasset host sync: $error');
      }
    }
  }

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }

  // --------------------------------------------------------------- internals

  void _accept(Socket socket) {
    final guest = _GuestConnection(socket);
    final decoder = PeerDecoder();

    socket.listen(
      (chunk) async {
        try {
          for (final message in decoder.add(chunk)) {
            await _handle(guest, message);
          }
        } on PeerProtocolException catch (error) {
          guest.send(PeerMessage.error(error.message));
          await guest.close();
        } on Object catch (error) {
          debugPrint('I Glasset host: $error');
        }
      },
      onError: (Object _) => _drop(guest),
      onDone: () => _drop(guest),
      cancelOnError: true,
    );
  }

  Future<void> _handle(_GuestConnection guest, PeerMessage message) async {
    switch (message.type) {
      case PeerMessageType.hello:
        final profile =
            Map<String, dynamic>.from(message.payload['profile'] as Map? ?? {});
        final code = message.payload[kTxtCode] as String? ?? '';
        final version = message.payload['v'] as int? ?? 0;

        if (version != kProtocolVersion) {
          guest.send(PeerMessage.error(
            'I bruger forskellige versioner af appen. Opdatér begge telefoner.',
          ));
          await guest.close();
          return;
        }

        final refusal = await delegate.admit(joinCode: code, profile: profile);
        if (refusal != null) {
          guest.send(PeerMessage.error(refusal));
          await guest.close();
          return;
        }

        guest.userId = profile['id'] as String?;
        guest.joinCode = code.toUpperCase();
        if (guest.userId == null) {
          guest.send(PeerMessage.error('Din profil mangler et id.'));
          await guest.close();
          return;
        }

        // A reconnecting phone replaces its old socket rather than doubling up.
        final previous = _guests.remove(guest.userId);
        if (previous != null && previous != guest) await previous.close();
        _guests[guest.userId!] = guest;

        final snapshot = await delegate.snapshotFor(
          guest.userId!,
          joinCode: guest.joinCode!,
        );
        guest.send(PeerMessage(PeerMessageType.welcome, snapshot.toJson()));
        _emit();

      case PeerMessageType.rating:
        if (guest.userId == null) return;
        final rating =
            Map<String, dynamic>.from(message.payload['rating'] as Map? ?? {});
        // The sender doesn't get to say whose rating it is.
        rating['user_id'] = guest.userId;
        await delegate.applyRating(guest.userId!, rating);
        await broadcastSync();

      case PeerMessageType.requestImage:
        final itemId = message.payload['item_id'] as String?;
        if (itemId == null) return;
        final image = await delegate.imageFor(itemId);
        if (image == null) {
          guest.send(PeerMessage(
            PeerMessageType.image,
            {'item_id': itemId, 'missing': true},
          ));
          return;
        }
        guest.send(PeerMessage(
          PeerMessageType.image,
          {
            'item_id': itemId,
            'sha256': image.sha256,
            'ext': image.extension,
          },
          blob: image.bytes,
        ));

      case PeerMessageType.bye:
        await _drop(guest);

      case PeerMessageType.welcome:
      case PeerMessageType.sync:
      case PeerMessageType.image:
      case PeerMessageType.error:
        // Host-to-guest kinds; nothing to do if a guest sends one.
        break;
    }
  }

  Future<void> _drop(_GuestConnection guest) async {
    final id = guest.userId;
    if (id != null && identical(_guests[id], guest)) {
      _guests.remove(id);
      await delegate.onLeave(id, joinCode: guest.joinCode ?? '');
    }
    await guest.close();
    _emit();
  }

  void _emit() {
    if (_statusController.isClosed) return;
    _statusController.add(HostStatus(
      running: _server != null,
      guestIds: _guests.keys.toList(),
    ));
  }
}

class HostStatus {
  const HostStatus({required this.running, required this.guestIds});

  final bool running;
  final List<String> guestIds;
}

class _GuestConnection {
  _GuestConnection(this.socket);

  final Socket socket;
  String? userId;
  String? joinCode;
  bool _closed = false;

  void send(PeerMessage message) {
    if (_closed) return;
    try {
      socket.add(message.encode());
    } on Object catch (error) {
      debugPrint('I Glasset host send: $error');
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await socket.flush();
      await socket.close();
    } on Object {
      // Already gone; nothing to do.
    }
    socket.destroy();
  }
}
