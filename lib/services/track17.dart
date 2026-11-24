import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models.dart';

/// Servizio facoltativo 17TRACK (serve una chiave personale; le prime
/// 200 spedizioni sono gratuite). Se non c'è la chiave non viene usato.
class Track17Exception implements Exception {
  Track17Exception(this.message, {this.quotaExhausted = false});
  final String message;
  final bool quotaExhausted;
  @override
  String toString() => message;
}

class Track17Result {
  const Track17Result({
    required this.status,
    required this.events,
    this.eta,
    this.carrierName,
  });
  final ShipStatus status;
  final List<TrackEvent> events;
  final DateTime? eta;
  final String? carrierName;
}

class Track17Quota {
  const Track17Quota({required this.total, required this.remaining});
  final int total;
  final int remaining;
}

class Track17Client {
  Track17Client(this.token, {http.Client? client}) : _client = client ?? http.Client();

  final String token;
  final http.Client _client;
  static const _base = 'https://api.17track.net/track/v2.2';

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    final http.Response res;
    try {
      res = await _client
          .post(Uri.parse('$_base/$path'),
              headers: {'17token': token, 'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw Track17Exception('Connessione non riuscita');
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Track17Exception('Chiave 17TRACK non valida');
    }
    if (res.statusCode == 429) {
      throw Track17Exception('Troppe richieste, riprova tra poco');
    }
    if (res.statusCode != 200) {
      throw Track17Exception('Errore del servizio (${res.statusCode})');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final code = json['code'];
    if (code != 0) {
      throw Track17Exception(_describeError(code, json['data']),
          quotaExhausted: _isQuota(code));
    }
    return json;
  }

  /// Registra il numero (consuma una spedizione della quota, una volta sola).
  Future<void> register(String number) async {
    final json = await _post('register', [
      {'number': number, 'lang': 'it'}
    ]);
    final rejected = ((json['data'] as Map?)?['rejected'] as List?) ?? const [];
    if (rejected.isEmpty) return;
    final err = Map<String, dynamic>.from((rejected.first as Map)['error'] as Map? ?? {});
    final msg = (err['message'] as String? ?? '').toLowerCase();
    // Già registrato: va benissimo.
    if (msg.contains('registered') || msg.contains('exist')) return;
    throw Track17Exception(_describeError(err['code'], null, fallback: err['message'] as String?),
        quotaExhausted: _isQuota(err['code']));
  }

  Future<Track17Result?> fetch(String number) async {
    final json = await _post('gettrackinfo', [
      {'number': number}
    ]);
    return parseTrack17Response(json);
  }

  Future<Track17Quota> quota() async {
    final json = await _post('getquota', []);
    final d = Map<String, dynamic>.from(json['data'] as Map);
    return Track17Quota(
      total: (d['quota_total'] as num?)?.toInt() ?? 0,
      remaining: (d['quota_remain'] as num?)?.toInt() ?? 0,
    );
  }
}

bool _isQuota(Object? code) => code == -18019907 || code == -18019908;

String _describeError(Object? code, Object? data, {String? fallback}) {
  if (_isQuota(code)) return 'Spedizioni gratuite 17TRACK esaurite';
  return fallback ?? 'Errore 17TRACK ($code)';
}

/// Converte la risposta di /gettrackinfo. Restituisce null se il numero
/// non è (ancora) tra quelli accettati.
Track17Result? parseTrack17Response(Map<String, dynamic> json) {
  final data = json['data'] as Map?;
  final accepted = (data?['accepted'] as List?) ?? const [];
  if (accepted.isEmpty) return null;
  final item = Map<String, dynamic>.from(accepted.first as Map);
  final info = item['track_info'] as Map?;
  if (info == null) return null;

  final latest = info['latest_status'] as Map?;
  final status = ShipStatus.from17(latest?['status'] as String?);

  final events = <TrackEvent>[];
  String? carrierName;
  final providers = ((info['tracking'] as Map?)?['providers'] as List?) ?? const [];
  for (final p in providers) {
    final pm = p as Map;
    carrierName ??= (pm['provider'] as Map?)?['name'] as String?;
    for (final e in (pm['events'] as List?) ?? const []) {
      final em = e as Map;
      final translated = (em['description_translation'] as Map?)?['description'] as String?;
      final desc = (translated != null && translated.isNotEmpty)
          ? translated
          : (em['description'] as String? ?? '');
      if (desc.isEmpty) continue;
      events.add(TrackEvent(
        time: DateTime.tryParse(em['time_iso'] as String? ?? em['time_utc'] as String? ?? '')
            ?.toLocal(),
        description: desc,
        location: (em['location'] as String?)?.trim().isEmpty ?? true
            ? null
            : em['location'] as String,
      ));
    }
  }
  events.sort((a, b) {
    if (a.time == null || b.time == null) return 0;
    return b.time!.compareTo(a.time!);
  });

  final etaRaw = ((info['time_metrics'] as Map?)?['estimated_delivery_date'] as Map?)?['from']
      as String?;
  return Track17Result(
    status: status,
    events: events,
    eta: DateTime.tryParse(etaRaw ?? '')?.toLocal(),
    carrierName: carrierName,
  );
}
