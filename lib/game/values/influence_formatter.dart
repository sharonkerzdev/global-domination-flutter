import 'package:decimal/decimal.dart';

class InfluenceFormatter {
  static final _tiers = <(Decimal, String)>[
    (Decimal.parse('1e33'), 'De'),
    (Decimal.parse('1e30'), 'No'),
    (Decimal.parse('1e27'), 'Oc'),
    (Decimal.parse('1e24'), 'Sp'),
    (Decimal.parse('1e21'), 'Sx'),
    (Decimal.parse('1e18'), 'Qi'),
    (Decimal.parse('1e15'), 'Qa'),
    (Decimal.parse('1e12'), 'T'),
    (Decimal.parse('1e9'), 'B'),
    (Decimal.parse('1e6'), 'M'),
    (Decimal.parse('1e3'), 'K'),
  ];

  static String abbreviated(Decimal value) {
    if (value < Decimal.zero) return '-${abbreviated(-value)}';

    for (final (threshold, suffix) in _tiers) {
      if (value >= threshold) {
        final divided = (value / threshold).toDecimal(
          scaleOnInfinitePrecision: 2,
        );
        final truncated = _truncateToTwoDecimalPlaces(divided);
        final formatted = _stripTrailingZeros(truncated);
        return '$formatted$suffix';
      }
    }

    return value.truncate().toBigInt().toString();
  }

  static String _truncateToTwoDecimalPlaces(Decimal value) {
    final parts = value.toString().split('.');
    if (parts.length == 1) return parts[0];
    final decimals = parts[1].length > 2 ? parts[1].substring(0, 2) : parts[1];
    return '${parts[0]}.$decimals';
  }

  static String _stripTrailingZeros(String formatted) {
    if (!formatted.contains('.')) return formatted;
    var result = formatted;
    while (result.endsWith('0')) {
      result = result.substring(0, result.length - 1);
    }
    if (result.endsWith('.')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
