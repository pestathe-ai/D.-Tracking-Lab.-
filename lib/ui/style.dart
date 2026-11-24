import 'package:flutter/material.dart';

import '../core/models.dart';

const brandYellow = Color(0xFFFFC629);
const brandNight = Color(0xFF10182B);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  var scheme = ColorScheme.fromSeed(seedColor: brandYellow, brightness: brightness);
  scheme = scheme.copyWith(
    primaryContainer: brandYellow,
    onPrimaryContainer: brandNight,
  );
  if (dark) {
    scheme = scheme.copyWith(
      primary: brandYellow,
      onPrimary: brandNight,
      surface: brandNight,
      surfaceContainerLow: const Color(0xFF172238),
      surfaceContainer: const Color(0xFF1B2740),
      surfaceContainerHigh: const Color(0xFF22304D),
    );
  }
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? brandNight : null,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? brandNight : null,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5)),
  );
}

Color statusColor(ShipStatus s, Brightness b) {
  final dark = b == Brightness.dark;
  return switch (s) {
    ShipStatus.delivered => dark ? const Color(0xFF5BD68A) : const Color(0xFF1E8E4E),
    ShipStatus.outForDelivery => dark ? brandYellow : const Color(0xFFB07D00),
    ShipStatus.pickup => dark ? const Color(0xFFC39BFF) : const Color(0xFF7043C9),
    ShipStatus.inTransit => dark ? const Color(0xFF7FB2FF) : const Color(0xFF2962C4),
    ShipStatus.infoReceived => dark ? const Color(0xFF9FB4D0) : const Color(0xFF4F6886),
    ShipStatus.failed => dark ? const Color(0xFFFFA06B) : const Color(0xFFC4501A),
    ShipStatus.exception => dark ? const Color(0xFFFF7B7B) : const Color(0xFFC62828),
    _ => dark ? const Color(0xFF9AA3B2) : const Color(0xFF6B7280),
  };
}

IconData statusIcon(ShipStatus s) => switch (s) {
      ShipStatus.pending => Icons.hourglass_empty_rounded,
      ShipStatus.notFound => Icons.search_off_rounded,
      ShipStatus.infoReceived => Icons.receipt_long_rounded,
      ShipStatus.inTransit => Icons.local_shipping_rounded,
      ShipStatus.pickup => Icons.storefront_rounded,
      ShipStatus.outForDelivery => Icons.delivery_dining_rounded,
      ShipStatus.failed => Icons.report_problem_rounded,
      ShipStatus.delivered => Icons.check_circle_rounded,
      ShipStatus.exception => Icons.error_rounded,
      ShipStatus.expired => Icons.schedule_rounded,
    };

const _months = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
const _weekdays = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];

String _two(int n) => n.toString().padLeft(2, '0');

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "oggi 14:30", "ieri 09:10", "24 nov 14:30".
String formatWhen(DateTime t, {DateTime? now}) {
  now ??= DateTime.now();
  final hasTime = t.hour != 0 || t.minute != 0;
  final time = hasTime ? ' ${_two(t.hour)}:${_two(t.minute)}' : '';
  if (_sameDay(t, now)) return 'oggi$time';
  if (_sameDay(t, now.subtract(const Duration(days: 1)))) return 'ieri$time';
  final year = t.year != now.year ? ' ${t.year}' : '';
  return '${t.day} ${_months[t.month - 1]}$year$time';
}

/// "Arriva oggi", "Arriva domani", "Arriva gio 26 nov".
String formatEta(DateTime eta, {DateTime? now}) {
  now ??= DateTime.now();
  if (_sameDay(eta, now)) return 'Arriva oggi';
  if (_sameDay(eta, now.add(const Duration(days: 1)))) return 'Arriva domani';
  return 'Arriva ${_weekdays[eta.weekday - 1]} ${eta.day} ${_months[eta.month - 1]}';
}
