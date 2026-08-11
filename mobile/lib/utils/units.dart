/// Unit display helpers (Section 11). The backend always stores/validates
/// metric (grams, °C) — this layer only affects how numbers are *displayed*,
/// never what's sent over the API, so switching units can never corrupt data
/// or trip a backend validation range meant for the other unit.
library;

/// Weight: backend stores grams. 'imperial' displays lb+oz.
String formatWeight(int grams, String units) {
  if (units != 'imperial') {
    return grams >= 1000
        ? '${(grams / 1000).toStringAsFixed(2)} kg'
        : '$grams g';
  }
  final totalOunces = grams / 28.3495;
  final lb = totalOunces ~/ 16;
  final oz = totalOunces - (lb * 16);
  return '$lb lb ${oz.toStringAsFixed(1)} oz';
}

/// Temperature: backend stores °C. 'imperial' displays °F.
String formatTemp(double celsius, String units) {
  if (units != 'imperial') return '${celsius.toStringAsFixed(1)}°C';
  return '${(celsius * 9 / 5 + 32).toStringAsFixed(1)}°F';
}
