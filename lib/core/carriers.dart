/// Corrieri supportati: riconoscimento dal numero e link alla pagina
/// ufficiale di tracking. Solo Dart puro, così è testabile in CI.
library;

class Carrier {
  const Carrier({
    required this.id,
    required this.name,
    required this.patterns,
    this.keywords = const [],
    this.urlTemplate,
  });

  final String id;
  final String name;

  /// Espressioni regolari (su numero normalizzato, maiuscolo, senza spazi).
  final List<String> patterns;

  /// Parole che, se compaiono nel testo condiviso, fanno preferire il corriere.
  final List<String> keywords;

  /// Pagina di tracking; `{n}` viene sostituito dal numero.
  final String? urlTemplate;

  bool matches(String normalized) =>
      patterns.any((p) => RegExp('^$p\$').hasMatch(normalized));

  Uri trackingUri(String number) {
    final n = Uri.encodeComponent(normalizeNumber(number));
    final template = urlTemplate ?? genericTrackingTemplate;
    return Uri.parse(template.replaceAll('{n}', n));
  }
}

/// Pagina universale (17TRACK, consultazione gratuita via web).
const genericTrackingTemplate = 'https://t.17track.net/it#nums={n}';

const otherCarrier = Carrier(id: 'other', name: 'Altro corriere', patterns: []);

/// L'ordine conta: a parità di formato vince chi viene prima
/// (pensato per spedizioni ricevute in Italia).
const carriers = <Carrier>[
  Carrier(
    id: 'amazon',
    name: 'Amazon Logistics',
    patterns: [r'TBA\d{12}'],
    keywords: ['amazon'],
    urlTemplate: 'https://track.amazon.it/tracking/{n}',
  ),
  Carrier(
    id: 'ups',
    name: 'UPS',
    patterns: [r'1Z[0-9A-Z]{16}'],
    keywords: ['ups'],
    urlTemplate: 'https://www.ups.com/track?loc=it_IT&tracknum={n}',
  ),
  Carrier(
    id: 'poste',
    name: 'Poste Italiane',
    patterns: [r'[A-Z]{2}\d{9}IT', r'\d[A-Z]{2}[0-9A-Z]{10}'],
    keywords: ['poste', 'poste italiane', 'postedelivery', 'crono'],
    urlTemplate:
        'https://www.poste.it/cerca/index.html#/risultati-spedizioni/{n}',
  ),
  Carrier(
    id: 'postal',
    name: 'Posta internazionale',
    patterns: [r'[A-Z]{2}\d{9}[A-Z]{2}'],
    keywords: ['china post', 'cainiao', 'correos', 'la poste', 'royal mail'],
  ),
  Carrier(
    id: 'inpost',
    name: 'InPost',
    patterns: [r'\d{24}'],
    keywords: ['inpost', 'locker'],
    urlTemplate: 'https://inpost.it/trova-il-tuo-pacco?number={n}',
  ),
  Carrier(
    id: 'brt',
    name: 'BRT',
    patterns: [r'\d{12}', r'\d{15}', r'\d{19}'],
    keywords: ['brt', 'bartolini'],
    urlTemplate:
        'https://www.mybrt.it/it/mybrt/my-parcels/search?parcelNumber={n}',
  ),
  Carrier(
    id: 'gls',
    name: 'GLS',
    patterns: [r'\d{11}', r'\d{12}', r'[A-Z]{2}\d{9}'],
    keywords: ['gls'],
    urlTemplate:
        'https://gls-group.com/IT/it/servizi-online/ricerca-spedizioni?match={n}',
  ),
  Carrier(
    id: 'sda',
    name: 'SDA',
    patterns: [r'\d{13}', r'[0-9A-Z]{13}'],
    keywords: ['sda'],
    urlTemplate:
        // I servizi corriere SDA sono passati a Poste: si cerca su poste.it.
        'https://www.poste.it/cerca/index.html#/risultati-spedizioni/{n}',
  ),
  Carrier(
    id: 'dhl',
    name: 'DHL',
    patterns: [r'\d{10}', r'JJD\d{16,22}', r'JVGL\d{8,}', r'GM\d{16,22}'],
    keywords: ['dhl'],
    urlTemplate:
        'https://www.dhl.com/it-it/home/tracciabilita.html?tracking-id={n}&submit=1',
  ),
  Carrier(
    id: 'dpd',
    name: 'DPD',
    patterns: [r'\d{14}'],
    keywords: ['dpd'],
    // In Italia DPD è consegnato da BRT: pagina BRT in italiano.
    urlTemplate: 'https://www.mybrt.it/it/mybrt/my-parcels/search?parcelNumber={n}',
  ),
  Carrier(
    id: 'fedex',
    name: 'FedEx / TNT',
    patterns: [r'\d{12}', r'\d{15}', r'\d{20}', r'\d{22}', r'\d{9}'],
    keywords: ['fedex', 'tnt'],
    urlTemplate: 'https://www.fedex.com/fedextrack/?trknbr={n}',
  ),
];

final allCarriers = <Carrier>[...carriers, otherCarrier];

Carrier carrierById(String? id) =>
    allCarriers.firstWhere((c) => c.id == id, orElse: () => otherCarrier);

/// Maiuscolo, senza spazi, trattini o punti.
String normalizeNumber(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[\s\-\.]'), '');

/// Corrieri compatibili col numero, dal più probabile.
/// Se [context] (es. testo di un'email) nomina un corriere, quello passa avanti.
List<Carrier> detectCarriers(String number, {String context = ''}) {
  final n = normalizeNumber(number);
  final found = carriers.where((c) => c.matches(n)).toList();
  final ctx = context.toLowerCase();
  if (ctx.isNotEmpty) {
    bool mentioned(Carrier c) => c.keywords
        .any((k) => RegExp('(^|[^a-z])${RegExp.escape(k)}([^a-z]|\$)')
            .hasMatch(ctx));
    final hinted = carriers.where(mentioned).toList();
    // Il corriere citato nel testo vince, anche se il formato non è tra quelli noti.
    for (final c in hinted.reversed) {
      found.remove(c);
      found.insert(0, c);
    }
  }
  return found;
}
