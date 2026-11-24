library;

enum ShipStatus {
  pending,
  notFound,
  infoReceived,
  inTransit,
  pickup,
  outForDelivery,
  failed,
  delivered,
  exception,
  expired;

  String get label => switch (this) {
        ShipStatus.pending => 'Da controllare',
        ShipStatus.notFound => 'In attesa di informazioni',
        ShipStatus.infoReceived => 'Etichetta creata',
        ShipStatus.inTransit => 'In viaggio',
        ShipStatus.pickup => 'Pronto da ritirare',
        ShipStatus.outForDelivery => 'In consegna oggi',
        ShipStatus.failed => 'Consegna non riuscita',
        ShipStatus.delivered => 'Consegnato',
        ShipStatus.exception => 'Problema con la spedizione',
        ShipStatus.expired => 'Nessun aggiornamento da tempo',
      };

  /// Da tenere d'occhio subito.
  bool get needsAttention => const {
        ShipStatus.outForDelivery,
        ShipStatus.pickup,
        ShipStatus.failed,
        ShipStatus.exception,
      }.contains(this);

  static ShipStatus from17(String? s) => switch (s) {
        'NotFound' => ShipStatus.notFound,
        'InfoReceived' => ShipStatus.infoReceived,
        'InTransit' => ShipStatus.inTransit,
        'AvailableForPickup' => ShipStatus.pickup,
        'OutForDelivery' => ShipStatus.outForDelivery,
        'DeliveryFailure' => ShipStatus.failed,
        'Delivered' => ShipStatus.delivered,
        'Exception' => ShipStatus.exception,
        'Expired' => ShipStatus.expired,
        _ => ShipStatus.pending,
      };

  static ShipStatus byName(String? n) => ShipStatus.values
      .firstWhere((s) => s.name == n, orElse: () => ShipStatus.pending);
}

class TrackEvent {
  const TrackEvent({this.time, required this.description, this.location});
  final DateTime? time;
  final String description;
  final String? location;

  Map<String, dynamic> toJson() => {
        't': time?.toIso8601String(),
        'd': description,
        'l': location,
      };

  factory TrackEvent.fromJson(Map<String, dynamic> j) => TrackEvent(
        time: DateTime.tryParse(j['t'] as String? ?? ''),
        description: j['d'] as String? ?? '',
        location: j['l'] as String?,
      );
}

class Shipment {
  Shipment({
    required this.id,
    required this.number,
    required this.carrierId,
    this.name,
    this.shop,
    required this.createdAt,
    this.status = ShipStatus.pending,
    this.events = const [],
    this.eta,
    this.lastChecked,
    this.archived = false,
    this.registered = false,
    this.error,
    this.serviceCarrier,
    this.note,
  });

  final String id;
  String number;
  String carrierId;
  String? name;
  String? shop;
  final DateTime createdAt;
  ShipStatus status;
  List<TrackEvent> events;
  DateTime? eta;
  DateTime? lastChecked;
  bool archived;

  /// Già registrato su 17TRACK (consuma una spedizione della quota).
  bool registered;
  String? error;

  /// Nome del corriere secondo il servizio di tracking.
  String? serviceCarrier;

  /// Informazione in più dal corriere (es. locker di ritiro).
  String? note;

  TrackEvent? get latest => events.isEmpty ? null : events.first;

  String get title {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (shop != null && shop!.isNotEmpty) return 'Pacco $shop';
    return number;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'carrier': carrierId,
        'name': name,
        'shop': shop,
        'created': createdAt.toIso8601String(),
        'status': status.name,
        'events': events.map((e) => e.toJson()).toList(),
        'eta': eta?.toIso8601String(),
        'checked': lastChecked?.toIso8601String(),
        'archived': archived,
        'registered': registered,
        'error': error,
        'svc': serviceCarrier,
        'note': note,
      };

  factory Shipment.fromJson(Map<String, dynamic> j) => Shipment(
        id: j['id'] as String,
        number: j['number'] as String,
        carrierId: j['carrier'] as String? ?? 'other',
        name: j['name'] as String?,
        shop: j['shop'] as String?,
        createdAt: DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.now(),
        status: ShipStatus.byName(j['status'] as String?),
        events: ((j['events'] as List?) ?? const [])
            .map((e) => TrackEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        eta: DateTime.tryParse(j['eta'] as String? ?? ''),
        lastChecked: DateTime.tryParse(j['checked'] as String? ?? ''),
        archived: j['archived'] as bool? ?? false,
        registered: j['registered'] as bool? ?? false,
        error: j['error'] as String?,
        serviceCarrier: j['svc'] as String?,
        note: j['note'] as String?,
      );
}
