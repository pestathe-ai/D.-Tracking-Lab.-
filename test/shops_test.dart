import 'package:d_tracking_lab/core/shops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dall\'app di provenienza', () {
    expect(detectShop(source: 'com.amazon.mShop.android.shopping'), 'Amazon');
    expect(detectShop(source: 'com.zzkko'), 'Shein');
    expect(detectShop(source: 'com.google.android.gm'), isNull);
  });

  test('dal mittente dell\'email', () {
    expect(detectShop(text: 'Da: ordini@zalando.it\nIl tuo ordine è in viaggio'), 'Zalando');
  });

  test('dal testo', () {
    expect(detectShop(text: 'Grazie per aver acquistato su Temu!'), 'Temu');
    expect(detectShop(text: 'Nessun negozio qui'), isNull);
  });

  test('Gmail ma testo con il negozio', () {
    expect(detectShop(source: 'com.google.android.gm', text: 'Il tuo pacco AliExpress'), 'AliExpress');
  });
}
