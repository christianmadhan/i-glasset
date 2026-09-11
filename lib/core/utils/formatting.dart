import 'package:intl/intl.dart';

import '../../data/repositories/tasting_repository.dart';

/// Danish formatting helpers. Dates and numbers are written the way the design
/// writes them: "10. september 2026", "1.500 kr.", "8,6".

final _dayMonth = DateFormat('d. MMMM', 'da');
final _dayMonthYear = DateFormat('d. MMMM y', 'da');
final _shortDate = DateFormat('d. MMM y', 'da');
final _time = DateFormat('HH.mm', 'da');

String formatDate(DateTime? date) =>
    date == null ? '' : _dayMonthYear.format(date);

String formatShortDate(DateTime? date) =>
    date == null ? '' : _shortDate.format(date);

/// "i aften 19.30", "i morgen 19.30", "17. september · 19.30".
String formatWhen(DateTime? date) {
  if (date == null) return 'tidspunkt ikke sat';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final days = day.difference(today).inDays;

  final clock = _time.format(date);
  return switch (days) {
    0 => '${date.hour < 12 ? 'i dag' : 'i aften'} $clock',
    1 => 'i morgen $clock',
    -1 => 'i går $clock',
    _ => '${_dayMonth.format(date)} · $clock',
  };
}

/// A 1–10 score in Danish: one decimal, comma separator.
String formatScore(double score) =>
    score.toStringAsFixed(1).replaceAll('.', ',');

/// "1.500 kr."
String formatMoney(num amount, {String currency = 'DKK'}) {
  final whole = amount.round().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]}.',
      );
  return '$whole ${currency == 'DKK' ? 'kr.' : currency}';
}

String formatAbv(double abv) => '${abv.toStringAsFixed(1).replaceAll('.', ',')} %';

/// "Godmorgen, Sofie" / "Godaften, Sofie".
String greeting(String? name) {
  final hour = DateTime.now().hour;
  final part = switch (hour) {
    < 5 => 'Godnat',
    < 10 => 'Godmorgen',
    < 14 => 'Goddag',
    < 18 => 'God eftermiddag',
    _ => 'Godaften',
  };
  return name == null || name.isEmpty ? part : '$part, $name';
}

/// "Rødvin fra Piemonte" — whichever region shows up most in the archive.
String? mostTastedLabel(List<ArchiveEntry>? archive) {
  if (archive == null || archive.isEmpty) return null;

  final counts = <String, int>{};
  for (final entry in archive) {
    final region = entry.item.region;
    final type = entry.item.productType ?? entry.tasting.category;
    if (region == null || region.isEmpty) continue;
    counts['$type fra $region'] = (counts['$type fra $region'] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;

  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// "7 er med", "1 er med" — Danish has no separate plural here, but the
/// surrounding copy changes, so it lives in one place.
String participantsLine(int count, int glasses) =>
    '$count er med · $glasses ${glasses == 1 ? 'glas' : 'glas'} i aften';
