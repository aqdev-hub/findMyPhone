/// Robust phone number normalization.
/// Handles: +966XXXXXXXX, 00966XXXXXXXX, 0XXXXXXXXX, XXXXXXXXX, spaces/dashes.
///
/// Strategy: preserve the + prefix if present or if 00-prefix is found.
/// Allows users to enter numbers in any format — all are stored the same way.
class PhoneNormalizer {
  /// Normalize a phone number to a canonical form.
  /// +966512345678  → +966512345678
  /// 00966512345678 → +966512345678
  /// 0512345678     → 0512345678    (local format preserved when no country code)
  /// 512345678      → 512345678
  /// Spaces, dashes, parentheses are stripped.
  static String normalize(String input) {
    final trimmed = input.trim();
    // Strip all non-digit characters except leading +
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');

    if (hasPlus) return '+$digits';
    // Convert 00-prefixed international to +
    if (digits.startsWith('00') && digits.length > 4) {
      return '+${digits.substring(2)}';
    }
    return digits;
  }

  /// Compare two numbers for equality, accounting for different formats.
  /// +966512345678 == 0512345678 if country code is 966.
  static bool same(String a, String b) {
    final na = normalize(a);
    final nb = normalize(b);
    if (na == nb) return true;
    // Try suffix match for country-code-less comparisons (last 9 digits)
    final da = na.replaceAll('+', '').replaceAll(RegExp(r'^0+'), '');
    final db = nb.replaceAll('+', '').replaceAll(RegExp(r'^0+'), '');
    // Match on last 9 digits (handles 0512345678 == +966512345678)
    if (da.length >= 9 && db.length >= 9) {
      return da.substring(da.length - 9) == db.substring(db.length - 9);
    }
    return false;
  }

  /// Validate that a phone number has at least 7 digits.
  static bool isValid(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 7 && digits.length <= 15;
  }

  /// Format for display: add spaces every 3 digits after country code.
  static String display(String normalized) {
    if (normalized.startsWith('+')) {
      // +966 512 345 678
      final digits = normalized.substring(1);
      if (digits.length >= 10) {
        final cc = digits.substring(0, 3);
        final rest = digits.substring(3);
        final chunks = <String>[];
        for (var i = 0; i < rest.length; i += 3) {
          chunks.add(rest.substring(i, (i + 3).clamp(0, rest.length)));
        }
        return '+$cc ${chunks.join(' ')}';
      }
    }
    return normalized;
  }
}
