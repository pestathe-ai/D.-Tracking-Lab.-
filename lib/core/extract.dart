/// Trova numeri di tracking dentro un testo qualsiasi
/// (email, SMS, testo selezionato, appunti).
library;

import 'carriers.dart';

List<String> extractTrackingNumbers(String text) {
  final results = <String>[];
  void add(String raw) {
    final n = normalizeNumber(raw);
    if (!results.contains(n)) results.add(n);
  }

  final upper = text.toUpperCase();

  // UPS spesso è scritto a gruppi: "1Z 999 AA1 01 2345 6784".
  for (final m in RegExp(r'1Z(?:[ ]?[0-9A-Z]){16}').allMatches(upper)) {
    add(m.group(0)!);
  }

  final tokens = RegExp(r'[A-Z0-9]{8,30}')
      .allMatches(upper)
      .map((m) => m.group(0)!)
      .where(_plausible)
      .toList();

  // Prima i formati noti con lettere (più specifici), poi quelli noti
  // solo numerici, poi gli altri.
  bool known(String t) => carriers.any((c) => c.matches(t));
  bool hasLetters(String t) => RegExp(r'[A-Z]').hasMatch(t);
  for (final t in tokens) {
    if (known(t) && hasLetters(t)) add(t);
  }
  for (final t in tokens) {
    if (known(t)) add(t);
  }
  for (final t in tokens) {
    if (RegExp(r'\d').allMatches(t).length >= 10) add(t);
  }
  return results;
}

bool _plausible(String t) {
  final digits = RegExp(r'\d').allMatches(t).length;
  if (digits < 6) return false; // parole normali
  if (RegExp(r'^(\d)\1+$').hasMatch(t)) return false; // 00000000
  if (t.startsWith('HTTP') || t.startsWith('WWW')) return false;
  // Numeri di telefono italiani (39 + cellulare/fisso).
  if (RegExp(r'^39[03]\d{8,9}$').hasMatch(t)) return false;
  return true;
}
