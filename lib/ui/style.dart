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

/// Colori dei luoghi di consegna (pieni): stesso luogo, stesso colore.
const placePalette = <Color>[
  Color(0xFF2EC4B6), // verde acqua
  Color(0xFFFF8C42), // arancio
  Color(0xFFE85D9E), // rosa
  Color(0xFF8BC34A), // verde
  Color(0xFF4FA3F7), // azzurro
  Color(0xFFA77BEA), // viola
  Color(0xFFE5484D), // rosso
  Color(0xFF9E8F6E), // sabbia
];

const placePaletteNames = [
  'Verde acqua', 'Arancio', 'Rosa', 'Verde', 'Azzurro', 'Viola', 'Rosso', 'Sabbia',
];

Color placeColor(int index) => placePalette[index % placePalette.length];

/// Colori dei negozi (usati come contorno): sempre uguali per lo stesso nome.
const _shopPalette = <Color>[
  Color(0xFFFFB020),
  Color(0xFF3DD6D0),
  Color(0xFFFF6B8B),
  Color(0xFF7C9CFF),
  Color(0xFF6FD66F),
  Color(0xFFFF8A4C),
  Color(0xFFC08BFF),
  Color(0xFF56C2FF),
  Color(0xFFE9D84A),
  Color(0xFFFF5F5F),
];

Color shopColor(String shop) {
  var h = 0;
  for (final c in shop.trim().toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _shopPalette[h % _shopPalette.length];
}

/// Etichetta del negozio: contorno colorato, ben visibile.
class ShopBadge extends StatelessWidget {
  const ShopBadge(this.shop, {super.key, this.large = false});
  final String shop;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = shopColor(shop);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? color : Color.lerp(color, Colors.black, 0.45)!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 9, vertical: large ? 5 : 2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: large ? 2 : 1.6),
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.10),
      ),
      child: Text(
        shop,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w700,
          fontSize: large ? 14 : 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Etichetta del luogo di consegna: pallino pieno del colore del luogo.
class PlaceBadge extends StatelessWidget {
  const PlaceBadge(this.place, this.color, {super.key});
  final String place;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 2, 9, 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_rounded, size: 13, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Etichetta del destinatario (pacchi spediti): contorno colorato e omino.
class RecipientBadge extends StatelessWidget {
  const RecipientBadge(this.name, {super.key, this.large = false});
  final String name;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = shopColor(name);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? color : Color.lerp(color, Colors.black, 0.45)!;
    return Container(
      padding: EdgeInsets.fromLTRB(large ? 8 : 6, large ? 4 : 2, large ? 12 : 9, large ? 4 : 2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: large ? 2 : 1.6),
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_rounded, size: large ? 16 : 13, color: text),
          const SizedBox(width: 3),
          Flexible(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: large ? 14 : 12)),
          ),
        ],
      ),
    );
  }
}
