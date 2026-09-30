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

  /// Parses a time window string (e.g. "12:00 PM - 2:00 PM", "08:00 - 11:30", "12:00 to 14:00")
  /// into start and end hour/minute.
  static ({({int hour, int minute})? start, ({int hour, int minute})? end}) parseWindow(String? windowStr) {
    if (windowStr == null) return (start: null, end: null);
    final clean = windowStr.trim();
    if (clean.isEmpty) return (start: null, end: null);

    final separator = RegExp(r'\s*[-–—]\s*|\s+to\s+', caseSensitive: false);
    final parts = clean.split(separator);
    if (parts.length >= 2) {
      return (
        start: parseTime(parts[0]),
        end: parseTime(parts[1]),
      );
    } else if (parts.length == 1) {
      return (
        start: null,
        end: parseTime(parts[0]),
      );
    }
    return (start: null, end: null);
  }

  /// Computes a real dynamic countdown status string:
  /// - During delivery time period: "Delivery ongoing"
  /// - When delivery time is over: "Order opens in 14h 30m"
  /// - Before order window opens: "Order opens in 1h 10m"
  /// - During active ordering window: "Order closes in 2h 30m"
  /// - Between order close and delivery start: "Order closed"
  /// Returns empty string if no valid time is configured.
  static String calculateOrderClosesText({
    String? startTimeStr,
    String? closeTimeStr,
    String? deliveryStartTimeStr,
    String? deliveryEndTimeStr,
    String? orderWindowStr,
    String? deliveryWindowStr,
    DateTime? now,
  }) {
    // Resolve order start and close
    ({int hour, int minute})? start = parseTime(startTimeStr);
    ({int hour, int minute})? close = parseTime(closeTimeStr);
    if (start == null && close == null && orderWindowStr != null && orderWindowStr.trim().isNotEmpty) {
      final parsedOrd = parseWindow(orderWindowStr);
      start = parsedOrd.start;
      close = parsedOrd.end;
    }

    // Resolve delivery start and end
    ({int hour, int minute})? delStart = parseTime(deliveryStartTimeStr);
    ({int hour, int minute})? delEnd = parseTime(deliveryEndTimeStr);
    if (delStart == null && delEnd == null && deliveryWindowStr != null && deliveryWindowStr.trim().isNotEmpty) {
      final parsedDel = parseWindow(deliveryWindowStr);
      delStart = parsedDel.start;
      delEnd = parsedDel.end;
    }

    final current = now ?? DateTime.now();
    final nowMinutes = current.hour * 60 + current.minute;

    final delStartMin = delStart != null ? delStart.hour * 60 + delStart.minute : null;
    final delEndMin = delEnd != null ? delEnd.hour * 60 + delEnd.minute : null;
    final ordStartMin = start != null ? start.hour * 60 + start.minute : null;
    final ordCloseMin = close != null ? close.hour * 60 + close.minute : null;

    // 1. During the delivery time period -> "Delivery ongoing"
    if (delStartMin != null && delEndMin != null) {
      if (delStartMin <= delEndMin) {
        if (nowMinutes >= delStartMin && nowMinutes <= delEndMin) {
          return 'Delivery ongoing';
        }
      } else {
        // Across midnight delivery
        if (nowMinutes >= delStartMin || nowMinutes <= delEndMin) {
          return 'Delivery ongoing';
        }
      }
    } else if (delEndMin != null && ordCloseMin != null) {
      if (nowMinutes >= ordCloseMin && nowMinutes <= delEndMin) {
        return 'Delivery ongoing';
      }
    }

    // 2. When delivery time is over -> "Order opens in..."
    if (delEndMin != null && nowMinutes > delEndMin) {
      if (ordStartMin != null) {
        final diff = (24 * 60 - nowMinutes) + ordStartMin;
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
      return 'Order opens tomorrow';
    }

    // 3. Early morning before order opens today -> "Order opens in..."
    if (ordStartMin != null && nowMinutes < ordStartMin) {
      final diff = ordStartMin - nowMinutes;
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

    // 4. Currently in active ordering window -> count down until close
    if (ordCloseMin != null) {
      if (nowMinutes < ordCloseMin) {
        final diff = ordCloseMin - nowMinutes;
        final hours = diff ~/ 60;
        final mins = diff % 60;
        if (hours > 0 && mins > 0) {
          return 'Order closes in ${hours}h ${mins}m';
        } else if (hours > 0) {
          return 'Order closes in ${hours}h';
        } else {
          return 'Order closes in ${mins}m';
        }
      } else {
        // Cut-off time passed, delivery hasn't started yet
        return 'Order closed';
      }
    }

    return '';
  }
}
