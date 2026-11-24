/// Interpreta il testo di una pagina di tracking (letta dal browser
/// invisibile dell'app) e ne ricava stato, passaggi e data prevista.
/// Funziona con regole su parole chiave in italiano e inglese:
/// è un'interpretazione, non un dato ufficiale.
library;

import 'models.dart';

class PageReading {
  const PageReading({
    required this.status,
    required this.events,
    this.eta,
    required this.foundNumber,
  });
  final ShipStatus status;
  final List<TrackEvent> events;
  final DateTime? eta;

  /// Il numero compariva nella pagina: la lettura è affidabile.
  final bool foundNumber;
}

/// Regole in ordine di priorità: la prima che corrisponde vince.
final _rules = <(ShipStatus, RegExp)>[
  (
    ShipStatus.delivered,
    RegExp(
        r'(?<!\b(?:non|mancata|not)\s(?:\S+\s){0,2})\b(consegnat[ao]|recapitat[ao]|delivered|zugestellt|livr[ée])\b',
        caseSensitive: false)
  ),
  (
    ShipStatus.failed,
    RegExp(
        r'mancata consegna|consegna non (riuscita|effettuata|avvenuta)|tentativo di consegna|destinatario assente|delivery attempt|unable to deliver|failed delivery',
        caseSensitive: false)
  ),
  (
    ShipStatus.pickup,
    RegExp(
        r'disponibile (per il |al )?ritiro|pronto (per il |al )?ritiro|in giacenza|ritiralo|ritira il (tuo )?pacco|available for pick ?up|ready for pick ?up|nel locker|in locker|punto di ritiro',
        caseSensitive: false)
  ),
  (
    ShipStatus.exception,
    RegExp(
        r'in restituzione|reso al mittente|restituit[ao] al mittente|returned to sender|spedizione bloccata|smarrit[ao]|danneggiat[ao]|exception|anomalia|indirizzo (errato|incompleto)',
        caseSensitive: false)
  ),
  (
    ShipStatus.outForDelivery,
    RegExp(
        r'\bin consegna\b|in corso di consegna|affidat[ao] al corriere per la consegna|in distribuzione|out for delivery|on vehicle for delivery|in arrivo oggi|consegna prevista oggi',
        caseSensitive: false)
  ),
  (
    ShipStatus.inTransit,
    RegExp(
        r'in transito|in viaggio|in lavorazione|partit[ao]|arrivat[ao]|presa in carico|preso in carico|centro di smistamento|hub|smistat[ao]|in dogana|sdoganat|in transit|departed|arrived|processed at|picked up|ritirat[ao] dal corriere|in spedizione|spedit[ao]',
        caseSensitive: false)
  ),
  (
    ShipStatus.infoReceived,
    RegExp(
        r'etichetta (creata|stampata|generata)|dati (della spedizione )?ricevuti|spedizione (registrata|creata)|in attesa (di essere )?(ritirat|presa)|in preparazione|label created|shipment information received|pre-?advice',
        caseSensitive: false)
  ),
  (
    ShipStatus.notFound,
    RegExp(
        r'nessun risultato|non (è stato )?trovat[ao]|codice (non valido|errato|inesistente)|nessuna spedizione|not found|no results|we could not locate|non disponibili',
        caseSensitive: false)
  ),
];

final _dateRe = RegExp(
    r'\b(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})\b(?:[^\d\n]{0,5}(\d{1,2})[:\.](\d{2}))?');

final _monthNames = <String, int>{
  'gen': 1, 'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'mag': 5, 'may': 5,
  'giu': 6, 'jun': 6, 'lug': 7, 'jul': 7, 'ago': 8, 'aug': 8, 'set': 9,
  'sep': 9, 'ott': 10, 'oct': 10, 'nov': 11, 'dic': 12, 'dec': 12,
};

final _textDateRe = RegExp(
    r'\b(\d{1,2})\s+(gen|feb|mar|apr|mag|giu|lug|ago|set|ott|nov|dic|jan|may|jun|jul|aug|sep|oct|dec)[a-z]*\.?(?:\s+(\d{4}))?(?:[^\d\n]{0,8}(\d{1,2})[:\.](\d{2}))?',
    caseSensitive: false);

DateTime? _parseDate(String line, {DateTime? now}) {
  now ??= DateTime.now();
  final m = _dateRe.firstMatch(line);
  if (m != null) {
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    if (d < 1 || d > 31 || mo < 1 || mo > 12 || y < 2000 || y > 2100) return null;
    final h = int.tryParse(m.group(4) ?? '') ?? 0;
    final mi = int.tryParse(m.group(5) ?? '') ?? 0;
    return DateTime(y, mo, d, h.clamp(0, 23), mi.clamp(0, 59));
  }
  final t = _textDateRe.firstMatch(line);
  if (t != null) {
    final d = int.parse(t.group(1)!);
    final mo = _monthNames[t.group(2)!.toLowerCase().substring(0, 3)];
    if (mo == null || d < 1 || d > 31) return null;
    var y = int.tryParse(t.group(3) ?? '') ?? now.year;
    // Senza anno: se la data cade nel "futuro" lontano, è dell'anno scorso.
    if (t.group(3) == null && DateTime(y, mo, d).isAfter(now.add(const Duration(days: 30)))) {
      y -= 1;
    }
    final h = int.tryParse(t.group(4) ?? '') ?? 0;
    final mi = int.tryParse(t.group(5) ?? '') ?? 0;
    return DateTime(y, mo, d, h.clamp(0, 23), mi.clamp(0, 59));
  }
  return null;
}

String _squash(String s) => s.toUpperCase().replaceAll(RegExp(r'[\s\-\.]'), '');

/// [number] normalizzato. [now] serve ai test.
PageReading parseTrackingPage(String text, String number, {DateTime? now}) {
  now ??= DateTime.now();
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // Ci concentriamo sulla parte di pagina che parla del nostro pacco:
  // dalla prima riga che contiene il numero in poi (menu e pubblicità esclusi).
  var start = lines.indexWhere((l) => _squash(l).contains(number));
  final found = start >= 0;
  if (!found) start = 0;
  final relevant = lines.sublist(start, (start + 120).clamp(0, lines.length));
  final body = relevant.join('\n');

  // Eventi: righe con una data, più la riga successiva se è descrittiva.
  final events = <TrackEvent>[];
  for (var i = 0; i < relevant.length && events.length < 25; i++) {
    final line = relevant[i];
    if (_etaRe.hasMatch(line)) continue; // "Consegna prevista: ..." non è un passaggio
    final time = _parseDate(line, now: now);
    if (time == null) continue;
    var desc = line
        .replaceAll(_dateRe, '')
        .replaceAll(_textDateRe, '')
        .replaceAll(RegExp(r'^[\s\-–|,:]+|[\s\-–|,:]+$'), '')
        .trim();
    String? location;
    if (desc.length < 6 && i + 1 < relevant.length && _parseDate(relevant[i + 1], now: now) == null) {
      desc = relevant[i + 1];
      if (i + 2 < relevant.length &&
          relevant[i + 2].length < 40 &&
          _parseDate(relevant[i + 2], now: now) == null &&
          !_rules.any((r) => r.$2.hasMatch(relevant[i + 2]))) {
        location = relevant[i + 2];
      }
    }
    if (desc.length < 4 || desc.length > 200) continue;
    if (!_rules.any((r) => r.$2.hasMatch(desc)) && !RegExp(r'[a-zA-Z]{4,}').hasMatch(desc)) continue;
    events.add(TrackEvent(time: time, description: desc, location: location));
  }
  // Più recenti in alto, togliendo i doppioni.
  events.sort((a, b) => b.time!.compareTo(a.time!));
  final unique = <TrackEvent>[];
  for (final e in events) {
    if (unique.any((u) => u.time == e.time && u.description == e.description)) continue;
    unique.add(e);
  }

  // Stato: prima dall'evento più recente, poi dall'intero testo del pacco.
  ShipStatus status = ShipStatus.pending;
  if (unique.isNotEmpty) {
    status = _classify(unique.first.description) ?? ShipStatus.pending;
  }
  if (status == ShipStatus.pending) {
    status = _classify(body) ?? (found ? ShipStatus.inTransit : ShipStatus.pending);
  }

  // Data prevista.
  DateTime? eta;
  final etaLine = _etaRe.firstMatch(body);
  if (etaLine != null) {
    eta = _parseDate(etaLine.group(0)!, now: now);
    if (eta == null && RegExp(r'\boggi\b|\btoday\b', caseSensitive: false).hasMatch(etaLine.group(0)!)) {
      eta = DateTime(now.year, now.month, now.day);
    } else if (eta == null && RegExp(r'\bdomani\b|\btomorrow\b', caseSensitive: false).hasMatch(etaLine.group(0)!)) {
      eta = DateTime(now.year, now.month, now.day + 1);
    }
  }

  return PageReading(status: status, events: unique, eta: eta, foundNumber: found);
}

final _etaRe = RegExp(
    r'(consegna prevista|data (di consegna )?prevista|previst[ao]|arrivo previsto|expected delivery|estimated delivery|delivery by)[^\n]{0,60}',
    caseSensitive: false);

ShipStatus? _classify(String text) {
  for (final (status, re) in _rules) {
    if (re.hasMatch(text)) return status;
  }
  return null;
}
