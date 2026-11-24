import 'package:d_tracking_lab/core/extract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trova il numero in un\'email', () {
    const text = '''
Ciao Mario, il tuo ordine 405-1234567-1234567 è stato spedito!
Corriere: BRT
Numero di tracking: 0123 4567 8901 2
Chiama il +39 333 1234567 per assistenza.
''';
    final nums = extractTrackingNumbers(text.replaceAll('0123 4567 8901 2', '0123456789012'));
    expect(nums, contains('0123456789012'));
    expect(nums.any((n) => n.contains('1234567') && n.length == 7), isFalse);
  });

  test('UPS scritto a gruppi', () {
    expect(extractTrackingNumbers('Tracking: 1Z 999 AA1 01 2345 6784'), ['1Z999AA10123456784']);
  });

  test('ignora parole e numeri banali', () {
    expect(extractTrackingNumbers('Ordine confermato, grazie per l\'acquisto 00000000'), isEmpty);
    expect(extractTrackingNumbers('https://www.example.com/12345678'), isNot(contains('HTTPS')));
  });

  test('prima i formati noti', () {
    final nums = extractTrackingNumbers('Rif. 2024112400123456789 spedizione RR123456789IT');
    expect(nums.first, 'RR123456789IT');
  });
}
