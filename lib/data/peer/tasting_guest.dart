import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

import 'peer_protocol.dart';

/// A tasting someone nearby is hosting right now.
class NearbyTasting {
  const NearbyTasting({
    required this.code,
    required this.title,
    required this.hostName,
    required this.glasses,
    required this.addresses,
    required this.port,
  });

  final String code;
  final String title;
  final String hostName;
  final int glasses;
  final List<String> addresses;
  final int port;

  bool get isReachable => addresses.isNotEmpty && port > 0;

  static NearbyTasting? fromService(BonsoirService service) {
    final code = service.attributes[kTxtCode];
    if (code == null || code.isEmpty) return null;
    return NearbyTasting(
      code: code.toUpperCase(),
      title: service.attributes[kTxtTitle] ?? 'Smagning',
      hostName: service.attributes[kTxtHost] ?? '',
      glasses: int.tryParse(service.attributes[kTxtGlasses] ?? '') ?? 0,
      addresses: service.hostAddresses,
      port: service.port,
    );
  }
}

/// Watches the local network for tastings being hosted.
///
/// Bonjour only tells you a service exists; the address and port arrive after
/// resolution, so found services are resolved eagerly and only surfaced once
/// they can actually be dialled.
class NearbyTastings {
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _subscription;

  final _found = <String, NearbyTasting>{};
  final _controller = StreamController<List<NearbyTasting>>.broadcast();

  Stream<List<NearbyTasting>> get stream => _controller.stream;
  List<NearbyTasting> get current => _found.values.toList();

  Future<void> start() async {
    if (_discovery != null) return;

    final discovery = BonsoirDiscovery(type: kServiceType);
    await discovery.initialize();

    _subscription = discovery.eventStream?.listen((event) {
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          // Ask for the address and port; it arrives as a resolved event.
          discovery.serviceResolver.resolveService(event.service);

        case BonsoirDiscoveryServiceResolvedEvent():
        case BonsoirDiscoveryServiceUpdatedEvent():
          final service = (event as dynamic).service as BonsoirService;
          final tasting = NearbyTasting.fromService(service);
          if (tasting != null && tasting.isReachable) {
            _found[tasting.code] = tasting;
            _emit();
          }

        case BonsoirDiscoveryServiceLostEvent(:final service):
          final code = service.attributes[kTxtCode]?.toUpperCase();
          if (code != null && _found.remove(code) != null) _emit();

        default:
          break;
      }
    });

    await discovery.start();
    _discovery = discovery;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _discovery?.stop();
    _discovery = null;
    _found.clear();
    _emit();
  }

  /// Waits for a host advertising [code] to appear, up to [timeout].
  Future<NearbyTasting?> resolve(
    String code, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final wanted = code.trim().toUpperCase();
    await start();

    final existing = _found[wanted];
    if (existing != null) return existing;

    try {
      return await stream
          .map((all) => all.where((t) => t.code == wanted).firstOrNull)
          .where((match) => match != null)
          .cast<NearbyTasting>()
          .first
          .timeout(timeout);
    } on TimeoutException {
      return null;
    }
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(current);
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}

/// What the guest's repository does with what arrives from the host.
abstract interface class GuestDelegate {
  /// A fresh picture of the evening. Persisted locally so the archive survives
  /// the walk home.
  Future<void> onSnapshot(TastingSnapshot snapshot);

  /// A photo of a revealed glass, to write into this device's own folder.
  Future<void> onImage({
    required String itemId,
    required String sha256,
    required String extension,
    required Uint8List bytes,
  });

  /// The host turned us away, or the evening ended.
  void onDisconnected(String? reason);
}

enum GuestState { idle, connecting, connected, disconnected }

/// The guest's end of the evening.
///
/// Holds one socket to the host, keeps the local mirror fed, and sends this
/// person's ratings back. Deliberately dumb: it never decides what a guest may
/// see, because the host has already decided that before sending.
class TastingGuest {
  TastingGuest({required this.delegate});

  final GuestDelegate delegate;

  Socket? _socket;
  String? _joinCode;
  Map<String, dynamic>? _profile;
  NearbyTasting? _host;

  final _stateController = StreamController<GuestState>.broadcast();
  GuestState _state = GuestState.idle;

  Stream<GuestState> get states => _stateController.stream;
  GuestState get state => _state;
  bool get isConnected => _state == GuestState.connected;
  String? get joinCode => _joinCode;

  /// Connects to [host] and asks to be let in. Throws [PeerProtocolException]
  /// with a Danish message when the host refuses.
  Future<void> connect({
    required NearbyTasting host,
    required String joinCode,
    required Map<String, dynamic> profile,
  }) async {
    await disconnect();

    _host = host;
    _joinCode = joinCode.toUpperCase();
    _profile = profile;
    _setState(GuestState.connecting);

    final socket = await _dial(host);
    _socket = socket;

    final admitted = Completer<void>();
    final decoder = PeerDecoder();

    socket.listen(
      (chunk) async {
        try {
          for (final message in decoder.add(chunk)) {
            await _handle(message, admitted);
          }
        } on Object catch (error) {
          debugPrint('I Glasset guest: $error');
        }
      },
      onError: (Object error) => _dropped('$error', admitted),
      onDone: () => _dropped(null, admitted),
      cancelOnError: true,
    );

    socket.add(
      PeerMessage(PeerMessageType.hello, {
        'profile': profile,
        kTxtCode: _joinCode,
      }).encode(),
    );

    // Either the welcome or a refusal lands within a few seconds.
    await admitted.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        disconnect();
        throw const PeerProtocolException(
          'Værten svarer ikke. Er I på det samme wi-fi?',
        );
      },
    );
  }

  /// Tries each advertised address in turn — a phone often publishes both a
  /// Wi-Fi and a link-local address, and only one of them answers.
  Future<Socket> _dial(NearbyTasting host) async {
    Object? lastError;
    for (final address in host.addresses) {
      try {
        return await Socket.connect(
          address,
          host.port,
          timeout: const Duration(seconds: 4),
        );
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw PeerProtocolException(
      lastError == null
          ? 'Kunne ikke få forbindelse til værten.'
          : 'Kunne ikke få forbindelse til værten. Er I på det samme wi-fi?',
    );
  }

  /// Sends this person's rating for one glass.
  void sendRating(Map<String, dynamic> rating) {
    final socket = _socket;
    if (socket == null || !isConnected) return;
    socket.add(
      PeerMessage(PeerMessageType.rating, {'rating': rating}).encode(),
    );
  }

  /// Asks for a photo this device doesn't have yet.
  void requestImage(String itemId) {
    final socket = _socket;
    if (socket == null || !isConnected) return;
    socket.add(
      PeerMessage(PeerMessageType.requestImage, {'item_id': itemId}).encode(),
    );
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        socket.add(const PeerMessage(PeerMessageType.bye, {}).encode());
        await socket.flush();
        await socket.close();
      } on Object {
        // Already gone.
      }
      socket.destroy();
    }
    if (_state != GuestState.idle) _setState(GuestState.disconnected);
  }

  /// Reconnects to the host we were last talking to — used when the app comes
  /// back to the foreground mid-tasting.
  Future<void> reconnect() async {
    final host = _host;
    final code = _joinCode;
    final profile = _profile;
    if (host == null || code == null || profile == null) return;
    await connect(host: host, joinCode: code, profile: profile);
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
  }

  // --------------------------------------------------------------- internals

  Future<void> _handle(PeerMessage message, Completer<void> admitted) async {
    switch (message.type) {
      case PeerMessageType.welcome:
        _setState(GuestState.connected);
        await delegate.onSnapshot(TastingSnapshot.fromJson(message.payload));
        if (!admitted.isCompleted) admitted.complete();

      case PeerMessageType.sync:
        await delegate.onSnapshot(TastingSnapshot.fromJson(message.payload));

      case PeerMessageType.image:
        if (message.payload['missing'] == true || message.blob == null) return;
        await delegate.onImage(
          itemId: message.payload['item_id'] as String,
          sha256: message.payload['sha256'] as String? ?? '',
          extension: message.payload['ext'] as String? ?? '.jpg',
          bytes: message.blob!,
        );

      case PeerMessageType.error:
        final reason = message.payload['message'] as String? ??
            'Værten afviste forbindelsen.';
        if (!admitted.isCompleted) {
          admitted.completeError(PeerProtocolException(reason));
        }
        await disconnect();
        delegate.onDisconnected(reason);

      case PeerMessageType.bye:
        await disconnect();
        delegate.onDisconnected(null);

      case PeerMessageType.hello:
      case PeerMessageType.rating:
      case PeerMessageType.requestImage:
        // Guest-to-host kinds; nothing to do.
        break;
    }
  }

  void _dropped(String? reason, Completer<void> admitted) {
    _socket = null;
    if (!admitted.isCompleted) {
      admitted.completeError(
        const PeerProtocolException('Forbindelsen til værten blev afbrudt.'),
      );
    }
    _setState(GuestState.disconnected);
    delegate.onDisconnected(reason);
  }

  void _setState(GuestState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }
}
