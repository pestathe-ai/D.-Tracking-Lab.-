import 'package:d_tracking_lab/core/carriers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizza il numero', () {
    expect(normalizeNumber(' 1z 999-aa1.01 '), '1Z999AA101');
  });

  test('riconosce i formati principali', () {
    expect(detectCarriers('1Z999AA10123456784').first.id, 'ups');
    expect(detectCarriers('TBA123456789012').first.id, 'amazon');
    expect(detectCarriers('RR123456789IT').first.id, 'poste');
    expect(detectCarriers('LP123456789CN').first.id, 'postal');
    expect(detectCarriers('123456789012345678901234').first.id, 'inpost');
    expect(detectCarriers('1234567890').first.id, 'dhl');
    expect(detectCarriers('12345678901234').first.id, 'dpd');
  });

  test('un numero di 12 cifre propone più corrieri', () {
    final ids = detectCarriers('123456789012').map((c) => c.id).toList();
    expect(ids, containsAll(['brt', 'gls', 'fedex']));
    expect(ids.first, 'brt');
  });

  test('il corriere citato nel testo passa avanti', () {
    final ids = detectCarriers('123456789012', context: 'Il tuo pacco GLS è partito').map((c) => c.id);
    expect(ids.first, 'gls');
    // "ups" non deve scattare dentro altre parole (es. "groups")
    final ids2 = detectCarriers('123456789012', context: 'groups and setups').map((c) => c.id);
    expect(ids2.first, 'brt');
  });

  test('link di tracking', () {
    final u = carrierById('ups').trackingUri('1z999aa10123456784');
    expect(u.toString(), contains('tracknum=1Z999AA10123456784'));
    expect(carrierById('postal').trackingUri('LP123456789CN').toString(), contains('17track'));
    expect(carrierById('nonesiste').id, 'other');
  });
}
