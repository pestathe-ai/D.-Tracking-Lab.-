/// Riconosce il negozio da cui arriva un pacco: dall'app di provenienza
/// (nome pacchetto Android) o dal testo condiviso (mittente, link, nome).
library;

class Shop {
  const Shop(this.name, {this.packages = const [], this.keywords = const []});
  final String name;
  final List<String> packages;
  final List<String> keywords;
}

const shops = <Shop>[
  Shop('Amazon',
      packages: ['com.amazon.mShop.android.shopping', 'in.amazon.mShop.android.shopping'],
      keywords: ['amazon']),
  Shop('Zalando', packages: ['de.zalando.mobile'], keywords: ['zalando']),
  Shop('Shein', packages: ['com.zzkko'], keywords: ['shein']),
  Shop('Temu', packages: ['com.einnovation.temu'], keywords: ['temu']),
  Shop('AliExpress',
      packages: ['com.alibaba.aliexpresshd'], keywords: ['aliexpress']),
  Shop('eBay', packages: ['com.ebay.mobile'], keywords: ['ebay']),
  Shop('Vinted', packages: ['fr.vinted'], keywords: ['vinted']),
  Shop('Subito', packages: ['it.subito'], keywords: ['subito.it']),
  Shop('Wallapop', packages: ['com.wallapop'], keywords: ['wallapop']),
  Shop('IKEA', packages: ['com.ingka.ikea.app'], keywords: ['ikea']),
  Shop('Zara', packages: ['com.inditex.zara'], keywords: ['zara.com']),
  Shop('Decathlon', keywords: ['decathlon']),
  Shop('MediaWorld', keywords: ['mediaworld']),
  Shop('Unieuro', keywords: ['unieuro']),
  Shop('Euronics', keywords: ['euronics']),
  Shop('Leroy Merlin', keywords: ['leroy merlin', 'leroymerlin']),
  Shop('Yoox', keywords: ['yoox']),
  Shop('Asos', keywords: ['asos']),
  Shop('Nike', keywords: ['nike.com']),
  Shop('Apple', keywords: ['apple store', 'apple.com']),
  Shop('Lidl', keywords: ['lidl']),
  Shop('H&M', keywords: ['h&m', 'hm.com']),
  Shop('Veepee', keywords: ['veepee', 'privalia']),
  Shop('Farmacia online', keywords: ['farmacia', 'farmae', 'efarma']),
];

/// Negozi proposti come scelta rapida quando non si riconosce nulla.
const popularShops = ['Amazon', 'Zalando', 'Shein', 'Temu', 'AliExpress', 'eBay', 'Vinted'];

/// [source] è il pacchetto dell'app che ha condiviso il testo, se noto.
String? detectShop({String? source, String text = ''}) {
  if (source != null && source.isNotEmpty) {
    for (final s in shops) {
      if (s.packages.contains(source)) return s.name;
    }
  }
  final t = text.toLowerCase();
  if (t.isEmpty) return null;
  // Prima il mittente/dominio email (es. "ordini@zalando.it").
  final domains = RegExp(r'@([a-z0-9\-]+)\.').allMatches(t).map((m) => m.group(1)!);
  for (final d in domains) {
    for (final s in shops) {
      if (s.keywords.any((k) => k.replaceAll(RegExp(r'\..*$'), '') == d)) {
        return s.name;
      }
    }
  }
  for (final s in shops) {
    if (s.keywords.any((k) => _containsWord(t, k))) return s.name;
  }
  return null;
}

bool _containsWord(String text, String word) => RegExp(
        '(^|[^a-z])${RegExp.escape(word)}([^a-z]|\$)')
    .hasMatch(text);
