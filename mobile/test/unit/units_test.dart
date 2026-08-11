/// Pure-Dart unit-conversion tests (Section 11 "Units"). These only affect
/// display — the backend always stores/validates metric — so correctness
/// here matters for UX but can never corrupt data.
import 'package:bracelet_monitor/utils/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatWeight', () {
    test('metric under 1000g shows grams', () {
      expect(formatWeight(750, 'metric'), '750 g');
    });

    test('metric at or above 1000g shows kg with 2 decimals', () {
      expect(formatWeight(3250, 'metric'), '3.25 kg');
    });

    test('imperial converts grams to lb + oz', () {
      // 3250g ≈ 7lb 2.6oz
      final result = formatWeight(3250, 'imperial');
      expect(result, contains('lb'));
      expect(result, contains('oz'));
      expect(result, '7 lb 2.6 oz');
    });

    test('imperial handles a value just over 1 pound cleanly', () {
      // 454g ≈ 16.014 oz ≈ 1 lb 0.0 oz (1 lb == 453.592g exactly)
      expect(formatWeight(454, 'imperial'), '1 lb 0.0 oz');
    });
  });

  group('formatTemp', () {
    test('metric shows Celsius with one decimal and degree symbol', () {
      expect(formatTemp(36.9, 'metric'), '36.9°C');
    });

    test('imperial converts to Fahrenheit', () {
      // 37.0°C == 98.6°F
      expect(formatTemp(37.0, 'imperial'), '98.6°F');
    });

    test('imperial conversion of 0°C is 32°F (sanity check on the formula)', () {
      expect(formatTemp(0, 'imperial'), '32.0°F');
    });

    test('unknown/unset units value defaults to metric', () {
      expect(formatTemp(36.5, 'unspecified'), '36.5°C');
    });
  });
}
