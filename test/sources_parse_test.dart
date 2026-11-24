import 'dart:convert';

import 'package:d_tracking_lab/core/models.dart';
import 'package:d_tracking_lab/core/sources_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InPost', () {
    test('pacco nel locker', () {
      final r = parseInPost({
        'tracking_number': '123456789012345678901234',
        'status': 'ready_to_pickup',
        'custom_attributes': {
          'target_machine_id': 'MIL123M',
          'target_machine_detail': {
            'name': 'MIL123M',
            'address': {'line1': 'Via Roma 1', 'line2': '20100 Milano'}
          }
        },
        'tracking_details': [
          {'status': 'adopted_at_target_branch', 'agency': null, 'datetime': '2026-11-23T18:00:00.000+01:00'},
          {'status': 'ready_to_pickup', 'agency': null, 'datetime': '2026-11-24T09:12:00.000+01:00'},
          {'status': 'confirmed', 'agency': null, 'datetime': '2026-11-21T10:00:00.000+01:00'},
        ],
      });
      expect(r.status, ShipStatus.pickup);
      expect(r.events.first.description, 'Nel locker: pronto da ritirare');
      expect(r.events.length, 3);
      expect(r.detail, 'Locker MIL123M, Via Roma 1, 20100 Milano');
    });

    test('stato sconosciuto resta leggibile', () {
      final r = parseInPost({'status': 'delivered_to_neighbour', 'tracking_details': []});
      expect(r.events.single.description, 'Delivered to neighbour');
      expect(r.status, ShipStatus.delivered);
    });

    test('risposta "non trovato" reale', () {
      final r = parseInPost(jsonDecode(
              '{"trackingNumber":"123","message":"Tracking information about 123 shipment has not been found."}')
          as Map<String, dynamic>);
      expect(r.notFound, isTrue);
    });
  });

  group('BRT', () {
    test('pagina di errore reale', () {
      const html = '<html><body><div>Errori riscontrati</div><div>Ritorno</div>'
          '<p>TIS0564 Spedizione non trovata oppure ancora in elaborazione nei nostri sistemi.</p></body></html>';
      expect(parseBrtHtml(html, '123456789012').notFound, isTrue);
    });

    test('tabella dei passaggi', () {
      const html = '''
<html><body>
<table><tr><td>Home</td><td>FAQ</td><td>Rintraccia</td></tr></table>
<div>Benvenuto</div><div>Servizi</div><div>Ritiri</div><div>Spedizione</div><div>Lingua</div>
<h2>Dettaglio spedizione</h2>
<table>
<tr><td>Numero spedizione</td><td>123456789012</td></tr>
<tr><td>Consegna prevista</td><td>25.11.2026</td></tr>
</table>
<table>
<tr><th>Data</th><th>Ora</th><th>Filiale</th><th>Evento</th></tr>
<tr><td>24.11.2026</td><td>08.45</td><td>MILANO</td><td>IN CONSEGNA</td></tr>
<tr><td>23.11.2026</td><td>22.10</td><td>BOLOGNA</td><td>PARTITA</td></tr>
<tr><td>23.11.2026</td><td>14.02</td><td>BOLOGNA</td><td>RITIRATA</td></tr>
</table>
<div>Area informativa</div><div>Consegnata la newsletter</div>
</body></html>''';
      final r = parseBrtHtml(html, '123456789012', now: DateTime(2026, 11, 24, 12));
      expect(r.notFound, isFalse);
      expect(r.status, ShipStatus.outForDelivery);
      expect(r.events.first.description, 'In consegna');
      expect(r.events.first.location, 'Milano');
      expect(r.events.first.time, DateTime(2026, 11, 24, 8, 45));
      expect(r.events.length, 3);
      expect(r.eta, DateTime(2026, 11, 25));
    });

    test('html in testo', () {
      expect(htmlToText('<td>A&amp;B</td><td>&agrave; posto</td>'), 'A&B | à posto');
    });
  });

  group('Poste', () {
    test('risposta "non trovato" reale', () {
      final r = parsePoste(jsonDecode(
              '{"idTracciatura":"CC123456789IT","tipoSpedizione":"P","esitoRicerca":"2","azioni":"","listaMovimenti":[],"actionsMap":{},"statoDaVerificare":false}')
          as Map<String, dynamic>);
      expect(r.notFound, isTrue);
    });

    test('movimenti', () {
      final r = parsePoste({
        'esitoRicerca': '1',
        'listaMovimenti': [
          {'dataOra': DateTime(2026, 11, 23, 9).millisecondsSinceEpoch, 'statoLavorazione': 'In transito', 'luogo': 'Bologna'},
          {'dataOra': DateTime(2026, 11, 24, 8).millisecondsSinceEpoch, 'statoLavorazione': 'In consegna', 'luogo': 'Milano'},
        ],
      });
      expect(r.status, ShipStatus.outForDelivery);
      expect(r.events.first.location, 'Milano');
    });
  });

  group('Amazon', () {
    test('risposta "non trovato" reale', () {
      final r = parseAmazon({
        'progressTracker':
            '{"progressMeter":null,"errors":[{"errorCode":"TRACKING_ID_NOT_FOUND","errorMessage":"INVALID TRACKING_ID"}],"summary":{"status":null},"expectedDeliveryDate":null}',
        'eventHistory': null,
      });
      expect(r.notFound, isTrue);
    });

    test('in consegna', () {
      final r = parseAmazon({
        'progressTracker': jsonEncode({
          'errors': [],
          'summary': {'status': 'OUT_FOR_DELIVERY'},
          'expectedDeliveryDate': '2026-11-24T18:00:00Z',
        }),
        'eventHistory': jsonEncode({
          'eventHistory': [
            {'eventCode': 'Departed', 'eventTime': '2026-11-24T05:00:00Z', 'location': {'city': 'Milano'}},
            {'eventCode': 'OutForDelivery', 'eventTime': '2026-11-24T07:00:00Z', 'location': {'city': 'Milano'}},
          ]
        }),
      });
      expect(r.status, ShipStatus.outForDelivery);
      expect(r.events.first.description, 'In consegna');
      expect(r.eta, isNotNull);
    });
  });
}
