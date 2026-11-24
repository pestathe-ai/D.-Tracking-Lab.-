import 'package:d_tracking_lab/core/models.dart';
import 'package:d_tracking_lab/ui/style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('salvataggio e lettura di un pacco', () {
    final s = Shipment(
      id: '1',
      number: 'RR123456789IT',
      carrierId: 'poste',
      shop: 'Zalando',
      createdAt: DateTime(2026, 11, 20),
      status: ShipStatus.inTransit,
      events: [TrackEvent(time: DateTime(2026, 11, 23, 18), description: 'In transito', location: 'Bologna')],
      eta: DateTime(2026, 11, 25),
    );
    final back = Shipment.fromJson(s.toJson());
    expect(back.number, s.number);
    expect(back.status, ShipStatus.inTransit);
    expect(back.events.single.location, 'Bologna');
    expect(back.title, 'Pacco Zalando');
    expect(back.eta, DateTime(2026, 11, 25));
  });

  test('date in italiano', () {
    final now = DateTime(2026, 11, 24, 12);
    expect(formatWhen(DateTime(2026, 11, 24, 9, 5), now: now), 'oggi 09:05');
    expect(formatWhen(DateTime(2026, 11, 23, 18), now: now), 'ieri 18:00');
    expect(formatWhen(DateTime(2026, 11, 20), now: now), '20 nov');
    expect(formatEta(DateTime(2026, 11, 25), now: now), 'Arriva domani');
    expect(formatEta(DateTime(2026, 11, 26), now: now), 'Arriva gio 26 nov');
  });

  test('stesso negozio, stesso colore', () {
    expect(shopColor('Zalando'), shopColor(' zalando '));
    expect(placeColor(0), placeColor(placePalette.length));
  });

  test('il luogo viene salvato', () {
    final s = Shipment(id: '2', number: 'X1', carrierId: 'brt', createdAt: DateTime(2026), place: 'Ufficio');
    expect(Shipment.fromJson(s.toJson()).place, 'Ufficio');
  });

  test('pacco spedito: destinatario e titolo', () {
    final s = Shipment(
        id: '3', number: 'X2', carrierId: 'brt', createdAt: DateTime(2026), sent: true, recipient: 'Marco', shop: 'eBay');
    final back = Shipment.fromJson(s.toJson());
    expect(back.sent, isTrue);
    expect(back.recipient, 'Marco');
    expect(back.title, 'Per Marco');
    expect(Shipment.fromJson({'id': '4', 'number': 'X3'}).sent, isFalse);
  });
}
