class AppointmentDateUtils {
  static String toIsoDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String formatDateDisplay(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  static DateTime parseInputDateOrNow(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return DateTime.now();
    final parts = trimmed.split('-');
    if (parts.length == 3) {
      try {
        if (parts[0].length == 2) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
        if (parts[0].length == 4) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } catch (_) {}
    }
    try {
      return DateTime.parse(trimmed);
    } catch (_) {
      return DateTime.now();
    }
  }

  static String normalizeSlotDate(String rawDate) {
    final trimmed = rawDate.trim();
    final parts = trimmed.split('-');
    if (parts.length == 3 && parts[0].length == 2 && parts[1].length == 2) {
      return trimmed;
    }
    try {
      final parsed = DateTime.parse(trimmed);
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final year = parsed.year.toString();
      return '$day-$month-$year';
    } catch (_) {
      return trimmed;
    }
  }

  static String? normalizeDateToApi(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('-');
    try {
      if (parts.length == 3) {
        if (parts[0].length == 2) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return toIsoDate(DateTime(year, month, day));
        }
        if (parts[0].length == 4) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          return toIsoDate(DateTime(year, month, day));
        }
      }
      return toIsoDate(DateTime.parse(trimmed));
    } catch (_) {
      return null;
    }
  }
}
