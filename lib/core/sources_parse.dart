/// Interpreta le risposte dei servizi pubblici dei corrieri.
/// Solo Dart puro: testabile senza telefono né rete.
library;

import 'dart:convert';

import 'models.dart';
import 'page_parser.dart';


class SourceResult {
  const SourceResult({
    required this.status,
    this.events = const [],
    this.eta,
    this.notFound = false,
    this.detail,
  });

  final ShipStatus status;
  final List<TrackEvent> events;
  final DateTime? eta;

  /// Il corriere dice che il numero non esiste (o non è ancora in sistema).
  final bool notFound;

  /// Informazione utile in più (es. locker di ritiro).
  final String? detail;
}

// ───────────────────────────── InPost ─────────────────────────────

const _inpostStatus = <String, (ShipStatus, String)>{
  'created': (ShipStatus.infoReceived, 'Spedizione creata dal venditore'),
  'offers_prepared': (ShipStatus.infoReceived, 'Spedizione in preparazione'),
  'offer_selected': (ShipStatus.infoReceived, 'Spedizione in preparazione'),
  'confirmed': (ShipStatus.infoReceived, 'Etichetta pronta, in attesa del ritiro'),
  'dispatched_by_sender': (ShipStatus.inTransit, 'Lasciato dal mittente nel locker'),
  'dispatched_by_sender_to_pok': (ShipStatus.inTransit, 'Lasciato dal mittente in un punto InPost'),
  'collected_from_sender': (ShipStatus.inTransit, 'Ritirato dal mittente'),
  'taken_by_courier': (ShipStatus.inTransit, 'Ritirato dal corriere'),
  'taken_by_courier_from_pok': (ShipStatus.inTransit, 'Ritirato dal corriere'),
  'adopted_at_source_branch': (ShipStatus.inTransit, 'Arrivato al magazzino di partenza'),
  'sent_from_source_branch': (ShipStatus.inTransit, 'In viaggio'),
  'adopted_at_sorting_center': (ShipStatus.inTransit, 'Al centro di smistamento'),
  'sent_from_sorting_center': (ShipStatus.inTransit, 'Partito dal centro di smistamento'),
  'adopted_at_target_branch': (ShipStatus.inTransit, 'Arrivato nella tua città'),
  'out_for_delivery': (ShipStatus.outForDelivery, 'In consegna'),
  'out_for_delivery_to_address': (ShipStatus.outForDelivery, 'In consegna all\'indirizzo'),
  'ready_to_pickup': (ShipStatus.pickup, 'Nel locker: pronto da ritirare'),
  'ready_to_pickup_from_pok': (ShipStatus.pickup, 'Nel punto InPost: pronto da ritirare'),
  'ready_to_pickup_from_branch': (ShipStatus.pickup, 'In filiale: pronto da ritirare'),
  'pickup_reminder_sent': (ShipStatus.pickup, 'Promemoria: il pacco ti aspetta'),
  'pickup_reminder_sent_address': (ShipStatus.pickup, 'Promemoria: il pacco ti aspetta'),
  'stack_in_box_machine': (ShipStatus.pickup, 'In un locker temporaneo: pronto da ritirare'),
  'stack_in_customer_service_point': (ShipStatus.pickup, 'In un punto temporaneo: pronto da ritirare'),
  'delivered': (ShipStatus.delivered, 'Consegnato'),
  'pickup_time_expired': (ShipStatus.exception, 'Tempo per il ritiro scaduto'),
  'stack_parcel_pickup_time_expired': (ShipStatus.exception, 'Tempo per il ritiro scaduto'),
  'avizo': (ShipStatus.failed, 'Consegna non riuscita, avviso lasciato'),
  'undelivered': (ShipStatus.failed, 'Consegna non riuscita'),
  'redirect_to_box': (ShipStatus.inTransit, 'Dirottato verso un locker'),
  'canceled_redirect_to_box': (ShipStatus.inTransit, 'Dirottamento annullato'),
  'returned_to_sender': (ShipStatus.exception, 'Restituito al mittente'),
  'returned_to_agency': (ShipStatus.exception, 'Tornato in filiale'),
  'canceled': (ShipStatus.exception, 'Spedizione annullata'),
  'claimed': (ShipStatus.exception, 'Reclamo aperto'),
  'missing': (ShipStatus.exception, 'Pacco non trovato dal corriere'),
  'oversized': (ShipStatus.exception, 'Pacco troppo grande per il locker'),
  'handed_over': (ShipStatus.inTransit, 'Consegnato a un altro corriere'),
  'other': (ShipStatus.inTransit, 'Aggiornamento del corriere'),
};

(ShipStatus, String) _inpost(String? name) {
  if (name == null || name.isEmpty) return (ShipStatus.pending, 'Aggiornamento');
  final known = _inpostStatus[name];
  if (known != null) return known;
  // Stato nuovo non ancora in elenco: lo rendiamo leggibile.
  final text = name.replaceAll('_', ' ');
  return (classifyText(text) ?? ShipStatus.inTransit, text[0].toUpperCase() + text.substring(1));
}

/// Risposta di GET api-shipx-*.easypack24.net/v1/tracking/{numero}
SourceResult parseInPost(Map<String, dynamic> json) {
  if (json['tracking_details'] == null && json['status'] == null) {
    return const SourceResult(status: ShipStatus.notFound, notFound: true);
  }
  final events = <TrackEvent>[];
  for (final d in (json['tracking_details'] as List?) ?? const []) {
    final m = d as Map;
    final (_, label) = _inpost(m['status'] as String?);
    final agency = m['agency'] as String?;
    events.add(TrackEvent(
      time: DateTime.tryParse(m['datetime'] as String? ?? '')?.toLocal(),
      description: label,
      location: (agency == null || agency.isEmpty) ? null : agency,
    ));
  }
  events.sort((a, b) => (b.time ?? DateTime(0)).compareTo(a.time ?? DateTime(0)));

  var (status, label) = _inpost(json['status'] as String?);
  if (events.isEmpty) {
    events.add(TrackEvent(
        time: DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal(), description: label));
  }

  // Dove ritirarlo (locker), se indicato.
  String? detail;
  final attrs = json['custom_attributes'];
  if (attrs is Map) {
    final machine = attrs['target_machine_detail'];
    if (machine is Map) {
      final addr = machine['address'];
      final parts = <String>[
        if (machine['name'] is String) 'Locker ${machine['name']}',
        if (addr is Map && addr['line1'] is String) addr['line1'] as String,
        if (addr is Map && addr['line2'] is String) addr['line2'] as String,
      ];
      if (parts.isNotEmpty) detail = parts.join(', ');
    } else if (attrs['target_machine_id'] is String) {
      detail = 'Locker ${attrs['target_machine_id']}';
    }
  }
  return SourceResult(status: status, events: events, detail: detail);
}

// ───────────────────────────── BRT ─────────────────────────────

/// Converte una pagina HTML in righe di testo (le celle di tabella
/// diventano "a | b | c").
String htmlToText(String html) {
  var h = html.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');
  h = h.replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true), ' ');
  h = h.replaceAll(RegExp(r'<br\s*/?>|</(tr|p|div|li|h\d|table|caption)>', caseSensitive: false), '\n');
  h = h.replaceAll(RegExp(r'</t[dh]>', caseSensitive: false), ' | ');
  h = h.replaceAll(RegExp(r'<[^>]+>'), ' ');
  h = h
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)))
      .replaceAll('&agrave;', 'à')
      .replaceAll('&egrave;', 'è')
      .replaceAll('&eacute;', 'é')
      .replaceAll('&igrave;', 'ì')
      .replaceAll('&ograve;', 'ò')
      .replaceAll('&ugrave;', 'ù');
  return h
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
      .map((l) => l.replaceAll(RegExp(r'^(\|\s*)+|(\s*\|)+$'), '').trim())
      .where((l) => l.isNotEmpty)
      .join('\n');
}

/// Pagina di risultato di vas.brt.it (sped_det_show).
///
/// La tabella "Data | Ora | Filiale | Evento" può arrivare con le celle sulla
/// stessa riga o una per riga: la leggiamo come una sequenza di celle.
/// BRT mostra anche eventi *previsti* con data futura (es. "IN CONSEGNA" di
/// domani): diventano la data prevista, non lo stato attuale.
SourceResult parseBrtHtml(String html, String number, {DateTime? now}) {
  now ??= DateTime.now();
  final text = htmlToText(html);
  if (RegExp(
          r'TIS0564|TIS0868|Spedizione non trovata|non trovata oppure ancora in elaborazione|'
          r'Parcel label number \S+ non trovato|BRTcode \S+ non valido',
          caseSensitive: false)
      .hasMatch(text)) {
    return const SourceResult(status: ShipStatus.notFound, notFound: true);
  }
  final lines = text.split('\n');
  var end = lines.indexWhere((l) => l.startsWith('Area informativa'));
  if (end < 0) end = lines.length;

  // Celle dopo l'intestazione "Data … Evento".
  final cells = <String>[];
  var inTable = false;
  for (final line in lines.sublist(0, end)) {
    for (final raw in line.split('|')) {
      final c = raw.trim();
      if (c.isEmpty) continue;
      if (!inTable) {
        if (c.toLowerCase() == 'evento') inTable = true;
        continue;
      }
      cells.add(c);
    }
  }

  final dateRe = RegExp(r'^(\d{1,2})[\.\/\-](\d{1,2})[\.\/\-](\d{4})$');
  final timeRe = RegExp(r'^(\d{1,2})[\.:](\d{2})$');
  final events = <TrackEvent>[];
  DateTime? planned;
  String? plannedText;
  var i = 0;
  while (i < cells.length) {
    final d = dateRe.firstMatch(cells[i]);
    if (d == null) {
      // Fine della tabella: la prima cella che non è una data dopo le righe lette.
      if (events.isNotEmpty || planned != null) break;
      i++;
      continue;
    }
    i++;
    var h = 0, mi = 0;
    var hasTime = false;
    if (i < cells.length) {
      final t = timeRe.firstMatch(cells[i]);
      if (t != null) {
        h = int.parse(t.group(1)!);
        mi = int.parse(t.group(2)!);
        hasTime = true;
        i++;
      }
    }
    final row = <String>[];
    while (i < cells.length && !dateRe.hasMatch(cells[i]) && row.length < 2) {
      row.add(cells[i]);
      i++;
    }
    if (row.isEmpty) continue;
    final place = row.length > 1 ? row.first : null;
    final what = row.last;
    final day = DateTime(int.parse(d.group(3)!), int.parse(d.group(2)!), int.parse(d.group(1)!));
    final today = DateTime(now.year, now.month, now.day);
    if (day.isAfter(today) && !hasTime) {
      planned ??= day;
      plannedText ??= what;
      continue;
    }
    events.add(TrackEvent(
      time: DateTime(day.year, day.month, day.day, h, mi),
      description: _brtEvent(what),
      location: place == null ? null : _nice(place),
    ));
  }
  events.sort((a, b) => (b.time ?? DateTime(0)).compareTo(a.time ?? DateTime(0)));

  final fermopoint = RegExp(r'fermopoint|fermo point', caseSensitive: false).hasMatch(text);
  var status = events.isEmpty
      ? ShipStatus.pending
      : (classifyText(events.first.description) ?? ShipStatus.inTransit);
  // Se la consegna prevista è oggi e l'ultimo evento la conferma, resta "in consegna".
  String? detail;
  if (fermopoint && status != ShipStatus.delivered) {
    detail = 'Spedito a un BRT-fermopoint: riceverai un avviso quando sarà pronto da ritirare.';
  }
  if (planned != null && plannedText != null && status != ShipStatus.delivered) {
    final what = _brtEvent(plannedText).toLowerCase();
    detail = [
      if (detail != null) detail,
      'Previsto il ${planned.day}/${planned.month}: $what.',
    ].join('\n');
  }
  return SourceResult(status: status, events: events, eta: planned, detail: detail);
}

/// Testi BRT abbreviati o in maiuscolo → frasi leggibili.
String _brtEvent(String raw) {
  final t = raw.toUpperCase().trim();
  const known = {
    'DATI SPEDIZ. TRASMESSI A BRT': 'Dati della spedizione ricevuti da BRT',
    'DATI SPEDIZIONE TRASMESSI A BRT': 'Dati della spedizione ricevuti da BRT',
    'DIROTTATA': 'Spedizione dirottata',
    'PARTITA': 'Partita dalla filiale',
    'ARRIVATA IN FILIALE': 'Arrivata in filiale',
    'IN CONSEGNA': 'In consegna',
    'CONSEGNATA': 'Consegnata',
  };
  return known[t] ?? _nice(raw.trim());
}

/// "IN CONSEGNA" → "In consegna".
String _nice(String s) {
  if (s.isEmpty || s != s.toUpperCase()) return s;
  final lower = s.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

// ───────────────────────────── Poste Italiane ─────────────────────────────

/// Risposta di POST poste.it/online/dovequando/DQ-REST/ricercasemplice
/// (vale anche per le spedizioni SDA, gestite ora da Poste).
SourceResult parsePoste(Map<String, dynamic> json) {
  final moves = (json['listaMovimenti'] as List?) ?? const [];
  if (moves.isEmpty) {
    return SourceResult(
        status: ShipStatus.notFound, notFound: json['esitoRicerca']?.toString() != '1');
  }
  final events = <TrackEvent>[];
  for (final m in moves) {
    if (m is! Map) continue;
    var desc = _firstString(m, [
      'statoLavorazione', 'descrizioneStato', 'descrizione', 'descrizioneEvento',
      'evento', 'stato', 'fase', 'faseLavorazione', 'esito',
    ]);
    // Campo con un nome diverso: prendiamo il testo descrittivo più lungo.
    desc ??= (m.entries
            .where((e) => e.value is String && RegExp(r'[A-Za-z]{4,}').hasMatch(e.value as String))
            .where((e) => !RegExp(r'luogo|ufficio|local|citt|cap|prov|id|codice', caseSensitive: false)
                .hasMatch(e.key.toString()))
            .map((e) => (e.value as String).trim())
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length)))
        .firstOrNull;
    if (desc == null) continue;
    Object? when = m['dataOra'] ?? m['data'] ?? m['dataEvento'] ?? m['dataOraEvento'] ?? m['timestamp'];
    when ??= m.entries
        .where((e) => RegExp(r'data|ora|time', caseSensitive: false).hasMatch(e.key.toString()))
        .map((e) => e.value)
        .firstOrNull;
    events.add(TrackEvent(
      time: _anyDate(when),
      description: _nice(desc),
      location: _firstString(m, ['luogo', 'ufficio', 'localita', 'citta', 'frazionario']),
    ));
  }
  events.sort((a, b) => (b.time ?? DateTime(0)).compareTo(a.time ?? DateTime(0)));
  if (events.isEmpty) {
    // Formato inatteso: lo segnaliamo con i nomi dei campi, per poterlo sistemare.
    final keys = moves.first is Map ? (moves.first as Map).keys.join(', ') : moves.first.runtimeType;
    throw FormatException('Formato Poste non riconosciuto (campi: $keys)');
  }
  final status = classifyText(events.first.description) ?? ShipStatus.inTransit;
  return SourceResult(status: status, events: events);
}

// ───────────────────────────── Amazon ─────────────────────────────

/// Risposta di GET track.amazon.it/api/tracker/{TBA...}
SourceResult parseAmazon(Map<String, dynamic> json) {
  Map<String, dynamic>? inner(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is String && v.isNotEmpty && v != 'null') {
      try {
        return Map<String, dynamic>.from(jsonDecode(v) as Map);
      } catch (_) {}
    }
    return null;
  }

  final progress = inner(json['progressTracker']);
  final errors = (progress?['errors'] as List?) ?? const [];
  if (errors.isNotEmpty && progress?['summary']?['status'] == null) {
    return const SourceResult(status: ShipStatus.notFound, notFound: true);
  }
  final summary = (progress?['summary'] as Map?) ?? const {};
  final code = (summary['status'] as String? ?? '').toUpperCase();
  var status = switch (code) {
    'DELIVERED' => ShipStatus.delivered,
    'OUT_FOR_DELIVERY' => ShipStatus.outForDelivery,
    'IN_TRANSIT' || 'SHIPPED' || 'DEPARTED' || 'ARRIVED' => ShipStatus.inTransit,
    'READY_FOR_PICKUP' || 'AVAILABLE_FOR_PICKUP' => ShipStatus.pickup,
    'DELIVERY_ATTEMPTED' || 'UNDELIVERABLE' => ShipStatus.failed,
    'RETURNING' || 'RETURNED' || 'DELAYED' => ShipStatus.exception,
    'ORDERED' || 'NOT_SHIPPED' || 'LABEL_CREATED' => ShipStatus.infoReceived,
    _ => ShipStatus.pending,
  };

  final events = <TrackEvent>[];
  final history = inner(json['eventHistory']);
  for (final e in (history?['eventHistory'] as List?) ?? const []) {
    if (e is! Map) continue;
    final codeE = (e['eventCode'] as String?) ?? '';
    final loc = e['location'];
    events.add(TrackEvent(
      time: DateTime.tryParse(e['eventTime'] as String? ?? '')?.toLocal(),
      description: _amazonEvent(codeE),
      location: loc is Map ? (loc['city'] as String?) : null,
    ));
  }
  events.sort((a, b) => (b.time ?? DateTime(0)).compareTo(a.time ?? DateTime(0)));
  if (status == ShipStatus.pending && events.isNotEmpty) {
    status = classifyText(events.first.description) ?? ShipStatus.inTransit;
  }
  return SourceResult(
    status: status,
    events: events,
    eta: _anyDate(progress?['expectedDeliveryDate']),
  );
}

String _amazonEvent(String code) {
  const names = {
    'Delivered': 'Consegnato',
    'OutForDelivery': 'In consegna',
    'Departed': 'Partito dal centro Amazon',
    'Arrived': 'Arrivato al centro Amazon',
    'PickupDone': 'Ritirato dal corriere',
    'CreationConfirmed': 'Spedizione creata',
    'ReadyForReceive': 'Etichetta creata',
    'DeliveryAttempted': 'Tentativo di consegna non riuscito',
    'ReadyForPickup': 'Pronto da ritirare',
    'PickedUpByCustomer': 'Ritirato',
    'Rejected': 'Rifiutato',
    'Delayed': 'In ritardo',
  };
  if (names.containsKey(code)) return names[code]!;
  if (code.isEmpty) return 'Aggiornamento';
  // "InTransit" → "In transit"
  final spaced = code.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m.group(1)!.toLowerCase()}');
  return spaced;
}

// ───────────────────────────── utilità ─────────────────────────────

String? _firstString(Map m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

DateTime? _anyDate(Object? v) {
  if (v == null) return null;
  if (v is int) {
    // millisecondi o secondi dall'epoca
    return DateTime.fromMillisecondsSinceEpoch(v > 100000000000 ? v : v * 1000);
  }
  if (v is String) {
    final asInt = int.tryParse(v);
    if (asInt != null) return _anyDate(asInt);
    final iso = DateTime.tryParse(v);
    if (iso != null) return iso.toLocal();
    final m = RegExp(r'(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{4})(?:\D+(\d{1,2})[:\.](\d{2}))?').firstMatch(v);
    if (m != null) {
      return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!),
          int.tryParse(m.group(4) ?? '') ?? 0, int.tryParse(m.group(5) ?? '') ?? 0);
    }
    return null;
  }
  return null;
}
