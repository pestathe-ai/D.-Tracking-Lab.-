import 'package:d_tracking_lab/core/models.dart';
import 'package:d_tracking_lab/core/page_parser.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 24, 12);

void main() {
  test('pagina con storico: consegnato', () {
    const page = '''
Home  Spedire  Ricevere  Tempi di consegna  Aiuto
Risultato ricerca spedizione
Numero spedizione: 123456789012
23/11/2026 08:10
Partita dal centro di smistamento
Bologna
24/11/2026 09:15
In consegna
24/11/2026 11:42
Consegnata
Milano
Hai bisogno di aiuto?
''';
    final r = parseTrackingPage(page, '123456789012', now: now);
    expect(r.foundNumber, isTrue);
    expect(r.status, ShipStatus.delivered);
    expect(r.events.first.description, 'Consegnata');
    expect(r.events.first.location, 'Milano');
    expect(r.events.first.time, DateTime(2026, 11, 24, 11, 42));
    expect(r.events.length, 3);
  });

  test('in consegna oggi, con data prevista', () {
    const page = '''
Spedizione RR123456789IT
Consegna prevista: oggi
24 nov 2026 07:30 - In consegna - Centro di Milano
23 nov 2026 18:00 - In transito - Bologna
''';
    final r = parseTrackingPage(page, 'RR123456789IT', now: now);
    expect(r.status, ShipStatus.outForDelivery);
    expect(r.eta, DateTime(2026, 11, 24));
    expect(r.events.first.description, contains('In consegna'));
  });

  test('mancata consegna è più importante del semplice "in consegna"', () {
    const page = '''
Spedizione 1234567890
24/11/2026 10:00 Tentativo di consegna, destinatario assente
24/11/2026 08:00 In consegna
''';
    final r = parseTrackingPage(page, '1234567890', now: now);
    expect(r.status, ShipStatus.failed);
  });

  test('non consegnato non è consegnato', () {
    const page = 'Spedizione 1234567890\n24/11/2026 10:00 Il pacco non è stato consegnato, in giacenza presso il punto di ritiro';
    final r = parseTrackingPage(page, '1234567890', now: now);
    expect(r.status, ShipStatus.pickup);
  });

  test('numero non trovato', () {
    const page = 'Cerca la tua spedizione\nNessun risultato trovato per il codice inserito';
    final r = parseTrackingPage(page, 'ABC12345678', now: now);
    expect(r.foundNumber, isFalse);
    expect(r.status, ShipStatus.notFound);
  });

  test('inglese, date senza anno', () {
    const page = '''
Tracking 1Z999AA10123456784
Estimated delivery: 26/11/2026
Nov 23 14:05 Departed from facility - Köln
''';
    final r = parseTrackingPage(page, '1Z999AA10123456784', now: now);
    expect(r.eta, DateTime(2026, 11, 26));
    expect(r.status, ShipStatus.inTransit);
  });
}
