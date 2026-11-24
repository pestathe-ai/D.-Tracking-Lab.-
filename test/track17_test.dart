import 'package:d_tracking_lab/core/models.dart';
import 'package:d_tracking_lab/services/track17.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legge la risposta di gettrackinfo', () {
    final json = {
      'code': 0,
      'data': {
        'accepted': [
          {
            'number': 'RR123456789IT',
            'carrier': 1,
            'track_info': {
              'latest_status': {'status': 'OutForDelivery', 'sub_status': 'OutForDelivery_Other'},
              'time_metrics': {
                'estimated_delivery_date': {'from': '2026-11-24T00:00:00+01:00', 'to': null}
              },
              'tracking': {
                'providers': [
                  {
                    'provider': {'name': 'Poste Italiane'},
                    'events': [
                      {
                        'time_iso': '2026-11-23T18:00:00+01:00',
                        'description': 'In transit',
                        'description_translation': {'lang': 'it', 'description': 'In transito'},
                        'location': 'Bologna'
                      },
                      {
                        'time_iso': '2026-11-24T07:30:00+01:00',
                        'description': 'Out for delivery',
                        'location': ''
                      }
                    ]
                  }
                ]
              }
            }
          }
        ],
        'rejected': []
      }
    };
    final r = parseTrack17Response(json)!;
    expect(r.status, ShipStatus.outForDelivery);
    expect(r.carrierName, 'Poste Italiane');
    expect(r.events.first.description, 'Out for delivery');
    expect(r.events.first.location, isNull);
    expect(r.events.last.description, 'In transito');
    expect(r.eta, isNotNull);
  });

  test('nessun numero accettato', () {
    expect(parseTrack17Response({'code': 0, 'data': {'accepted': [], 'rejected': []}}), isNull);
  });
}
