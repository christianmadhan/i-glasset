/// One glass.
///
/// Participants read these through the `tasting_items_visible` view, which
/// returns null for every identifying field until that glass is revealed — so
/// an unrevealed glass genuinely carries no answer on the guest's device.
class TastingItem {
  const TastingItem({
    required this.id,
    required this.tastingId,
    required this.position,
    required this.isRevealed,
    this.revealedAt,
    this.name,
    this.producer,
    this.grape,
    this.country,
    this.region,
    this.vintage,
    this.abv,
    this.price,
    this.currency = 'DKK',
    this.productType,
    this.extra,
    this.aromas = const [],
    this.flavours = const [],
    this.hostNotes,
    this.imagePath,
    this.imageSha256,
    this.imageBytes,
    bool? hasExtra,
    // A named parameter cannot be private, so no initialising formal here.
    // ignore: prefer_initializing_formals
  }) : _hasExtra = hasExtra;

  final String id;
  final String tastingId;
  final int position;
  final bool isRevealed;
  final DateTime? revealedAt;

  final String? name;
  final String? producer;
  final String? grape;
  final String? country;
  final String? region;
  final int? vintage;
  final double? abv;
  final double? price;
  final String currency;
  final String? productType;

  /// The one thing the host marked as special about this glass.
  final String? extra;

  /// Whether the host marked anything at all — carried to guests as a plain
  /// yes/no before the reveal, so the guess sheet knows to ask without
  /// giving the answer away. Only glasses with one have the category in play.
  bool get hasExtra => _hasExtra ?? (extra != null && extra!.isNotEmpty);
  final bool? _hasExtra;

  final List<String> aromas;
  final List<String> flavours;

  /// Only ever populated for the host.
  final String? hostNotes;

  /// Storage object path — never bytes, never a URL.
  final String? imagePath;
  final String? imageSha256;
  final int? imageBytes;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  /// What a participant sees before the reveal.
  String get blindLabel => 'Glas #$position';

  /// The name once revealed, falling back to the blind label.
  String get displayName => name?.isNotEmpty == true ? name! : blindLabel;

  /// "Nebbiolo · Piemonte, Italien · 315 kr."
  String get meta {
    final place = [region, country].where((v) => v?.isNotEmpty == true).join(', ');
    return [
      if (grape?.isNotEmpty == true) grape!,
      if (place.isNotEmpty) place,
      if (price != null) formattedPrice,
    ].join(' · ');
  }

  /// The host's own one-line summary while building the programme.
  String get hostMeta {
    final parts = [
      if (region?.isNotEmpty == true) region!,
      if (country?.isNotEmpty == true && region?.isNotEmpty != true) country!,
      if (price != null) formattedPrice,
    ];
    return parts.isEmpty ? 'Ingen detaljer endnu' : parts.join(' · ');
  }

  String get formattedPrice {
    if (price == null) return '';
    final whole = price!.round();
    final text = whole.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]}.',
        );
    return '$text ${currency == 'DKK' ? 'kr.' : currency}';
  }

  String get formattedAbv =>
      abv == null ? '' : '${abv!.toStringAsFixed(1).replaceAll('.', ',')} %';

  factory TastingItem.fromJson(Map<String, dynamic> json) => TastingItem(
        id: json['id'] as String,
        tastingId: json['tasting_id'] as String,
        position: (json['position'] as num).toInt(),
        isRevealed: json['is_revealed'] as bool? ??
            (json['revealed_at'] != null),
        revealedAt: json['revealed_at'] == null
            ? null
            : DateTime.parse(json['revealed_at'] as String).toLocal(),
        name: json['name'] as String?,
        producer: json['producer'] as String?,
        grape: json['grape'] as String?,
        country: json['country'] as String?,
        region: json['region'] as String?,
        vintage: (json['vintage'] as num?)?.toInt(),
        abv: _double(json['abv']),
        price: _double(json['price']),
        currency: json['currency'] as String? ?? 'DKK',
        productType: json['product_type'] as String?,
        extra: json['extra'] as String?,
        hasExtra: json['has_extra'] as bool?,
        aromas: (json['aromas'] as List?)?.cast<String>() ?? const [],
        flavours: (json['flavours'] as List?)?.cast<String>() ?? const [],
        hostNotes: json['host_notes'] as String?,
        imagePath: json['image_path'] as String?,
        imageSha256: json['image_sha256'] as String?,
        imageBytes: (json['image_bytes'] as num?)?.toInt(),
      );

  /// Only the host ever writes a glass, so this carries every secret field.
  Map<String, dynamic> toUpsert() => {
        'id': id,
        'tasting_id': tastingId,
        'position': position,
        'name': name,
        'producer': producer,
        'grape': grape,
        'country': country,
        'region': region,
        'vintage': vintage,
        'abv': abv,
        'price': price,
        'currency': currency,
        'product_type': productType,
        'extra': extra,
        'aromas': aromas,
        'flavours': flavours,
        'host_notes': hostNotes,
        'image_path': imagePath,
        'image_sha256': imageSha256,
        'image_bytes': imageBytes,
      };

  TastingItem copyWith({
    int? position,
    String? name,
    String? producer,
    String? grape,
    String? country,
    String? region,
    int? vintage,
    double? abv,
    double? price,
    String? currency,
    String? productType,
    String? extra,
    List<String>? aromas,
    List<String>? flavours,
    String? hostNotes,
    String? imagePath,
    String? imageSha256,
    int? imageBytes,
    bool? isRevealed,
    DateTime? revealedAt,
  }) =>
      TastingItem(
        id: id,
        tastingId: tastingId,
        position: position ?? this.position,
        isRevealed: isRevealed ?? this.isRevealed,
        revealedAt: revealedAt ?? this.revealedAt,
        name: name ?? this.name,
        producer: producer ?? this.producer,
        grape: grape ?? this.grape,
        country: country ?? this.country,
        region: region ?? this.region,
        vintage: vintage ?? this.vintage,
        abv: abv ?? this.abv,
        price: price ?? this.price,
        currency: currency ?? this.currency,
        productType: productType ?? this.productType,
        extra: extra ?? this.extra,
        aromas: aromas ?? this.aromas,
        flavours: flavours ?? this.flavours,
        hostNotes: hostNotes ?? this.hostNotes,
        imagePath: imagePath ?? this.imagePath,
        imageSha256: imageSha256 ?? this.imageSha256,
        imageBytes: imageBytes ?? this.imageBytes,
      );
}

double? _double(Object? value) => switch (value) {
      null => null,
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
