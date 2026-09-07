class MealTimeHelper {
  MealTimeHelper._();

  /// Parses a time string (e.g. "08:00", "14:30", "08:00AM", "2:30 PM") into hour and minute.
  static ({int hour, int minute})? parseTime(String? timeStr) {
    if (timeStr == null) return null;
    final clean = timeStr.trim().toUpperCase();
    if (clean.isEmpty) return null;

    final isPm = clean.contains('PM');
    final isAm = clean.contains('AM');

    // Remove AM/PM and non-time characters
    final digitsOnly = clean.replaceAll(RegExp(r'[^\d:]'), '');
    final parts = digitsOnly.split(':');
    if (parts.isEmpty) return null;

    final rawHour = int.tryParse(parts[0]);
    if (rawHour == null) return null;
    final rawMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    int hour = rawHour;
    if (isPm && hour < 12) {
      hour += 12;
    } else if (isAm && hour == 12) {
      hour = 0;
    }

    if (hour < 0 || hour > 23 || rawMinute < 0 || rawMinute > 59) {
      return null;
    }

    return (hour: hour, minute: rawMinute);
  }

  /// Formats hour and minute into a readable 12-hour string (e.g. "8:00 AM", "2:30 PM").
  static String format12h(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mStr = minute.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }

  /// Formats a time string into 12-hour readable format (e.g. "08:00" -> "8:00 AM").
  static String formatSingleTime(String? timeStr) {
    final parsed = parseTime(timeStr);
    if (parsed == null) return (timeStr ?? '').trim();
    return format12h(parsed.hour, parsed.minute);
  }

  /// Formats a window between start and end time (e.g. "8:00 AM - 12:00 PM").
  static String formatTimeWindow(String? startStr, String? endStr) {
    final start = parseTime(startStr);
    final end = parseTime(endStr);

    if (start != null && end != null) {
      return '${format12h(start.hour, start.minute)} - ${format12h(end.hour, end.minute)}';
    } else if (start != null) {
      return format12h(start.hour, start.minute);
    } else if (end != null) {
      return format12h(end.hour, end.minute);
    }

    final s1 = (startStr ?? '').trim();
    final s2 = (endStr ?? '').trim();
    if (s1.isNotEmpty && s2.isNotEmpty) {
      return '$s1 - $s2';
    } else if (s1.isNotEmpty) {
      return s1;
    } else if (s2.isNotEmpty) {
      return s2;
    }
    return '';
  }

  /// Computes a real dynamic countdown status string:
  /// - "Order closes in 2h 30m"
  /// - "Order closes in 45m"
  /// - "Order opens in 1h 10m"
  /// - "Order closed"
  /// Returns empty string if no valid time is configured.
  static String calculateOrderClosesText({
    String? startTimeStr,
    String? closeTimeStr,
    DateTime? now,
  }) {
    final close = parseTime(closeTimeStr);
    if (close == null) return '';

    final current = now ?? DateTime.now();
    final nowMinutes = current.hour * 60 + current.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    final start = parseTime(startTimeStr);
    final startMinutes = start != null ? (start.hour * 60 + start.minute) : null;

    // If order window hasn't opened yet today
    if (startMinutes != null && nowMinutes < startMinutes) {
      final diff = startMinutes - nowMinutes;
      final hours = diff ~/ 60;
      final mins = diff % 60;
      if (hours > 0 && mins > 0) {
        return 'Order opens in ${hours}h ${mins}m';
      } else if (hours > 0) {
        return 'Order opens in ${hours}h';
      } else {
        return 'Order opens in ${mins}m';
      }
    }

    // If current time is past cutoff time
    if (nowMinutes >= closeMinutes) {
      return 'Order closed';
    }

    // Currently in active ordering window -> count down until close
    final diff = closeMinutes - nowMinutes;
    final hours = diff ~/ 60;
    final mins = diff % 60;
    if (hours > 0 && mins > 0) {
      return 'Order closes in ${hours}h ${mins}m';
    } else if (hours > 0) {
      return 'Order closes in ${hours}h';
    } else {
      return 'Order closes in ${mins}m';
    }
  }
}
