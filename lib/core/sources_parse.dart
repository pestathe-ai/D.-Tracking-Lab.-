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
SourceResult parseBrtHtml(String html, String number, {DateTime? now}) {
  final text = htmlToText(html);
  if (RegExp(
          r'TIS0564|TIS0868|Spedizione non trovata|non trovata oppure ancora in elaborazione|'
          r'Parcel label number \S+ non trovato|BRTcode \S+ non valido',
          caseSensitive: false)
      .hasMatch(text)) {
    return const SourceResult(status: ShipStatus.notFound, notFound: true);
  }
  // Togliamo menu e piè di pagina del sito: teniamo la parte centrale.
  final lines = text.split('\n');
  var start = lines.indexWhere((l) => RegExp(r'Ritorno|Dettaglio|spedizione', caseSensitive: false).hasMatch(l) &&
      lines.indexOf(l) > 5);
  if (start < 0) start = 0;
  var end = lines.indexWhere((l) => l.startsWith('Area informativa'));
  if (end < 0 || end <= start) end = lines.length;
  final core = lines.sublist(start, end).join('\n');

  final r = parseTrackingPage(core, number, now: now);
  final events = r.events.map(_splitCells).toList();
  var status = r.status;
  if (events.isNotEmpty) {
    status = classifyText(events.first.description) ?? status;
  }
  if (status == ShipStatus.pending && events.isNotEmpty) status = ShipStatus.inTransit;
  return SourceResult(status: status, events: events, eta: r.eta);
}

/// "MILANO | IN CONSEGNA" → descrizione "In consegna", luogo "Milano".
TrackEvent _splitCells(TrackEvent e) {
  final parts = e.description
      .split('|')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty && !RegExp(r'^\d{1,2}[:\.]\d{2}$').hasMatch(p))
      .toList();
  if (parts.length < 2) return TrackEvent(time: e.time, description: _nice(e.description), location: e.location);
  final descIndex = parts.indexWhere((p) => classifyText(p) != null);
  final di = descIndex >= 0 ? descIndex : parts.length - 1;
  final desc = parts[di];
  final others = [for (var i = 0; i < parts.length; i++) if (i != di) parts[i]];
  return TrackEvent(
    time: e.time,
    description: _nice(desc),
    location: e.location ?? (others.isEmpty ? null : _nice(others.join(', '))),
  );
}

/// "IN CONSEGNA" → "In consegna".
String _nice(String s) {
  if (s.isEmpty || s != s.toUpperCase()) return s;
  final lower = s.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

// ───────────────────────────── Poste Italiane ─────────────────────────────

/// Risposta di POST poste.it/online/dovequando/DQ-REST/ricercasemplice
SourceResult parsePoste(Map<String, dynamic> json) {
  final moves = (json['listaMovimenti'] as List?) ?? const [];
  if (moves.isEmpty) {
    return SourceResult(
        status: ShipStatus.notFound, notFound: json['esitoRicerca']?.toString() != '1');
  }
  final events = <TrackEvent>[];
  for (final m in moves) {
    if (m is! Map) continue;
    final desc = _firstString(m, ['statoLavorazione', 'descrizione', 'descrizioneEvento', 'evento', 'stato']);
    if (desc == null) continue;
    events.add(TrackEvent(
      time: _anyDate(m['dataOra'] ?? m['data'] ?? m['dataEvento']),
      description: _nice(desc),
      location: _firstString(m, ['luogo', 'ufficio', 'localita', 'frazionario']),
    ));
  }
  events.sort((a, b) => (b.time ?? DateTime(0)).compareTo(a.time ?? DateTime(0)));
  final status = events.isEmpty
      ? ShipStatus.pending
      : (classifyText(events.first.description) ?? ShipStatus.inTransit);
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
    return DateTime.tryParse(v)?.toLocal();
  }
  return null;
}
