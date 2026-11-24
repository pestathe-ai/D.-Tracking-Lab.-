import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models.dart';
import '../core/sources_parse.dart';

/// Legge lo stato direttamente dai servizi pubblici dei corrieri,
/// gratis e senza account. Solo corrieri che lo permettono.
class CarrierSources {
  CarrierSources({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _ua = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36';

  /// Corrieri letti direttamente dall'app.
  static const supported = {'brt', 'inpost', 'poste', 'amazon'};

  bool supports(String carrierId) => supported.contains(carrierId);

  Future<SourceResult> fetch(String carrierId, String number) => switch (carrierId) {
        'brt' => _brt(number),
        'inpost' => _inpost(number),
        'poste' => _poste(number),
        'amazon' => _amazon(number),
        _ => throw UnsupportedError(carrierId),
      };

  Map<String, String> _headers({String accept = 'application/json'}) => {
        'User-Agent': _ua,
        'Accept': accept,
        'Accept-Language': 'it-IT,it;q=0.9',
      };

  Future<http.Response> _send(Future<http.Response> f) async {
    try {
      return await f.timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const SourceException('Connessione non riuscita: controlla internet e riprova.');
    }
  }

  // InPost: servizio pubblico ShipX, prima Italia poi Polonia/Europa.
  Future<SourceResult> _inpost(String number) async {
    SourceResult? last;
    for (final host in ['api-shipx-it.easypack24.net', 'api-shipx-pl.easypack24.net']) {
      final res = await _send(_client.get(
        Uri.https(host, '/v1/tracking/$number'),
        headers: _headers(),
      ));
      if (res.statusCode == 404) {
        last = const SourceResult(status: ShipStatus.notFound, notFound: true);
        continue;
      }
      if (res.statusCode != 200) throw SourceException('InPost non risponde (${res.statusCode})');
      return parseInPost(Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map));
    }
    return last!;
  }

  // BRT: pagina pubblica di vas.brt.it, generata dal server.
  Future<SourceResult> _brt(String number) async {
    final http.Response res;
    if (number.length == 19) {
      // BRTcode (19 cifre): modulo dedicato.
      res = await _send(_client.post(
        Uri.https('vas.brt.it', '/vas/sped_det_show.htm'),
        headers: {..._headers(accept: 'text/html'), 'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'brtCode': number, 'referer': 'sped_numspe_par.htm', 'RicercaBrtCode': 'Ricerca'},
      ));
    } else if (number.length == 12) {
      res = await _send(_client.get(
        Uri.https('vas.brt.it', '/vas/sped_det_show.hsm',
            {'referer': 'sped_numspe_par.htm', 'Nspediz': number}),
        headers: _headers(accept: 'text/html'),
      ));
    } else {
      // ID collo cliente / segnacollo.
      res = await _send(_client.get(
        Uri.https('vas.brt.it', '/vas/sped_det_show.hsm',
            {'referer': 'sped_numspe_par.htm', 'ChiSono': number}),
        headers: _headers(accept: 'text/html'),
      ));
    }
    if (res.statusCode != 200) throw SourceException('BRT non risponde (${res.statusCode})');
    // Il sito BRT usa la codifica iso-8859-15.
    return parseBrtHtml(latin1.decode(res.bodyBytes, allowInvalid: true), number);
  }

  // Poste Italiane: servizio usato dalla ricerca spedizioni di poste.it.
  Future<SourceResult> _poste(String number) async {
    final res = await _send(_client.post(
      Uri.https('www.poste.it', '/online/dovequando/DQ-REST/ricercasemplice'),
      headers: {..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({'tipoRichiedente': 'WEB', 'codiceSpedizione': number, 'periodoRicerca': 1}),
    ));
    if (res.statusCode != 200) throw SourceException('Poste non risponde (${res.statusCode})');
    return parsePoste(Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map));
  }

  // Amazon Logistics (codici TBA).
  Future<SourceResult> _amazon(String number) async {
    final res = await _send(_client.get(
      Uri.https('track.amazon.it', '/api/tracker/$number'),
      headers: _headers(),
    ));
    if (res.statusCode != 200) throw SourceException('Amazon non risponde (${res.statusCode})');
    return parseAmazon(Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map));
  }
}

class SourceException implements Exception {
  const SourceException(this.message);
  final String message;
  @override
  String toString() => message;
}
