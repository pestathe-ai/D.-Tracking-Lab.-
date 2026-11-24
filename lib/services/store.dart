import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/carriers.dart';
import '../core/models.dart';
import 'carrier_sources.dart';
import 'track17.dart';

/// Tutti i pacchi, salvati sul telefono, e il loro aggiornamento.
class ShipmentStore extends ChangeNotifier {
  ShipmentStore({CarrierSources? sources}) : sources = sources ?? CarrierSources();

  final CarrierSources sources;
  final List<Shipment> _items = [];
  final Set<String> _refreshing = {};
  String apiKey = '';
  bool checkClipboard = true;
  String lastOfferedClipboard = '';
  bool loaded = false;

  /// Colore scelto per ogni luogo di consegna (indice della tavolozza).
  final Map<String, int> placeColors = {};

  List<Shipment> get active => _sorted(_items.where((s) => !s.archived));
  List<Shipment> get archived => _sorted(_items.where((s) => s.archived));
  bool isRefreshing(String id) => _refreshing.contains(id);
  bool get anyRefreshing => _refreshing.isNotEmpty;

  Shipment? byId(String id) {
    for (final s in _items) {
      if (s.id == id) return s;
    }
    return null;
  }

  Shipment? byNumber(String number) {
    final n = normalizeNumber(number);
    for (final s in _items) {
      if (s.number == n) return s;
    }
    return null;
  }

  List<Shipment> _sorted(Iterable<Shipment> it) {
    final l = it.toList();
    int rank(Shipment s) => s.status.needsAttention
        ? 0
        : s.status == ShipStatus.delivered
            ? 2
            : 1;
    l.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final ta = a.latest?.time ?? a.createdAt;
      final tb = b.latest?.time ?? b.createdAt;
      return tb.compareTo(ta);
    });
    return l;
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    apiKey = p.getString('apiKey') ?? '';
    checkClipboard = p.getBool('checkClipboard') ?? true;
    lastOfferedClipboard = p.getString('lastClip') ?? '';
    placeColors.clear();
    try {
      final pc = jsonDecode(p.getString('placeColors') ?? '{}') as Map;
      pc.forEach((k, v) => placeColors[k as String] = (v as num).toInt());
    } catch (_) {}
    final raw = p.getString('shipments');
    _items.clear();
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          _items.add(Shipment.fromJson(Map<String, dynamic>.from(j as Map)));
        }
      } catch (_) {
        // Dati illeggibili: si riparte da zero piuttosto che bloccare l'app.
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('shipments', jsonEncode(_items.map((s) => s.toJson()).toList()));
  }

  Future<void> setApiKey(String key) async {
    apiKey = key.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString('apiKey', apiKey);
    notifyListeners();
  }

  Future<void> setCheckClipboard(bool v) async {
    checkClipboard = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('checkClipboard', v);
    notifyListeners();
  }

  Future<void> markClipboardOffered(String value) async {
    lastOfferedClipboard = value;
    final p = await SharedPreferences.getInstance();
    await p.setString('lastClip', value);
  }

  Future<Shipment> add({
    required String number,
    required String carrierId,
    String? name,
    String? shop,
  }) async {
    final s = Shipment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      number: normalizeNumber(number),
      carrierId: carrierId,
      name: (name?.trim().isEmpty ?? true) ? null : name!.trim(),
      shop: (shop?.trim().isEmpty ?? true) ? null : shop!.trim(),
      createdAt: DateTime.now(),
    );
    _items.add(s);
    await _save();
    notifyListeners();
    return s;
  }

  Future<void> update(Shipment s) async {
    await _save();
    notifyListeners();
  }

  Future<void> setArchived(Shipment s, bool value) async {
    s.archived = value;
    await update(s);
  }

  Future<void> remove(Shipment s) async {
    _items.remove(s);
    await _save();
    notifyListeners();
  }

  Future<void> restore(Shipment s) async {
    if (!_items.contains(s)) _items.add(s);
    await _save();
    notifyListeners();
  }

  /// Aggiorna tutti i pacchi non archiviati e non consegnati da più di un giorno.
  Future<void> refreshAll({bool onlyStale = false}) async {
    final now = DateTime.now();
    for (final s in active) {
      final deliveredLongAgo = s.status == ShipStatus.delivered &&
          (s.latest?.time ?? s.lastChecked ?? now).isBefore(now.subtract(const Duration(days: 1)));
      if (deliveredLongAgo) continue;
      if (onlyStale && s.lastChecked != null && now.difference(s.lastChecked!).inMinutes < 30) {
        continue;
      }
      await refresh(s);
    }
  }

  Future<void> refresh(Shipment s) async {
    if (_refreshing.contains(s.id)) return;
    _refreshing.add(s.id);
    notifyListeners();
    try {
      final carrier = carrierById(s.carrierId);
      var done = false;
      // 1) Servizio pubblico del corriere: gratis, senza account.
      if (sources.supports(s.carrierId)) {
        done = await _refreshDirect(s);
      } else if (s.carrierId == 'other') {
        // Corriere sconosciuto: proviamo quelli leggibili compatibili col formato.
        for (final c in detectCarriers(s.number)) {
          if (!sources.supports(c.id)) continue;
          final previous = s.carrierId;
          s.carrierId = c.id;
          done = await _refreshDirect(s, quietNotFound: true);
          if (done) break;
          s.carrierId = previous;
        }
      }
      // 2) Facoltativo: 17TRACK, se l'utente ha messo la chiave.
      if (!done && apiKey.isNotEmpty) done = await _refreshWith17(s);
      if (!done && s.error == null) {
        s.error = sources.supports(s.carrierId)
            ? null
            : '${carrier.name} non permette la lettura automatica gratuita del suo sito. '
                'Puoi vedere lo stato con "Mostra la pagina originale del corriere" qui sotto '
                'oppure aggiungere una chiave 17TRACK nelle impostazioni.';
      }
      s.lastChecked = DateTime.now();
    } catch (e) {
      s.error = 'Aggiornamento non riuscito: $e';
    } finally {
      _refreshing.remove(s.id);
      await _save();
      notifyListeners();
    }
  }

  /// true se il corriere ha restituito informazioni sul pacco.
  Future<bool> _refreshDirect(Shipment s, {bool quietNotFound = false}) async {
    final carrier = carrierById(s.carrierId);
    try {
      final r = await sources.fetch(s.carrierId, s.number);
      if (r.notFound) {
        if (!quietNotFound) {
          s.status = ShipStatus.notFound;
          s.error = '${carrier.name} non trova ancora questo numero. Se il pacco è appena stato '
              'spedito, riprova tra qualche ora; altrimenti controlla di aver scelto il corriere giusto.';
        }
        return false;
      }
      s.status = r.status;
      if (r.events.isNotEmpty) s.events = r.events;
      s.eta = r.eta ?? (s.status == ShipStatus.delivered ? null : s.eta);
      s.note = r.detail ?? s.note;
      if (s.place == null && r.place != null) {
        s.place = r.place;
        _ensurePlaceColor(r.place!);
        await _savePlaces();
      }
      s.error = null;
      return true;
    } on SourceException catch (e) {
      s.error = e.message;
      return false;
    } on FormatException catch (e) {
      s.error = '${carrier.name}: ${e.message}. Mandami uno screenshot di questo messaggio.';
      return false;
    } catch (e) {
      s.error = 'Risposta di ${carrier.name} non riconosciuta. Riprova più tardi.';
      return false;
    }
  }

  /// true se 17TRACK ha dato una risposta utile.
  Future<bool> _refreshWith17(Shipment s) async {
    final client = Track17Client(apiKey);
    try {
      if (!s.registered) {
        await client.register(s.number);
        s.registered = true;
      }
      final r = await client.fetch(s.number);
      if (r == null || (r.status == ShipStatus.notFound && r.events.isEmpty)) return false;
      s.status = r.status;
      if (r.events.isNotEmpty) s.events = r.events;
      s.eta = r.eta ?? s.eta;
      s.serviceCarrier = r.carrierName ?? s.serviceCarrier;
      s.error = null;
      return true;
    } on Track17Exception {
      return false; // si passa alla lettura della pagina, che è gratuita
    }
  }

  /// Luoghi usati, dal più frequente, più quelli a cui hai dato un colore.
  List<String> get places {
    final count = <String, int>{};
    for (final s in _items) {
      if (s.place != null) count[s.place!] = (count[s.place!] ?? 0) + 1;
    }
    for (final k in placeColors.keys) {
      count.putIfAbsent(k, () => 0);
    }
    final l = count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
    return l;
  }

  int placeColorIndex(String place) => placeColors[place] ?? _ensurePlaceColor(place);

  int _ensurePlaceColor(String place) {
    final existing = placeColors[place];
    if (existing != null) return existing;
    // Primo colore della tavolozza non ancora usato.
    var i = 0;
    while (placeColors.containsValue(i) && i < 64) {
      i++;
    }
    placeColors[place] = i;
    return i;
  }

  Future<void> _savePlaces() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('placeColors', jsonEncode(placeColors));
  }

  Future<void> setPlace(Shipment s, String? place) async {
    final v = place?.trim();
    s.place = (v == null || v.isEmpty) ? null : v;
    if (s.place != null) _ensurePlaceColor(s.place!);
    await _savePlaces();
    await update(s);
  }

  Future<void> setPlaceColor(String place, int index) async {
    placeColors[place] = index;
    await _savePlaces();
    notifyListeners();
  }

  /// Rinomina un luogo su tutti i pacchi.
  Future<void> renamePlace(String from, String to) async {
    final t = to.trim();
    if (t.isEmpty || t == from) return;
    for (final s in _items) {
      if (s.place == from) s.place = t;
    }
    final c = placeColors.remove(from);
    if (c != null) placeColors[t] = c;
    await _savePlaces();
    await _save();
    notifyListeners();
  }

  Future<void> removePlace(String place) async {
    for (final s in _items) {
      if (s.place == place) s.place = null;
    }
    placeColors.remove(place);
    await _savePlaces();
    await _save();
    notifyListeners();
  }

  @visibleForTesting
  void debugAdd(Shipment s) => _items.add(s);
}
