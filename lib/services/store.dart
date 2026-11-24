import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/carriers.dart';
import '../core/models.dart';
import '../core/page_parser.dart';
import 'page_reader.dart';
import 'track17.dart';

/// Tutti i pacchi, salvati sul telefono, e il loro aggiornamento.
class ShipmentStore extends ChangeNotifier {
  ShipmentStore(this.reader);

  final PageReader reader;
  final List<Shipment> _items = [];
  final Set<String> _refreshing = {};
  String apiKey = '';
  bool checkClipboard = true;
  String lastOfferedClipboard = '';
  bool loaded = false;

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
      var done = false;
      if (apiKey.isNotEmpty) done = await _refreshWith17(s);
      if (!done) await _refreshFromPage(s);
      s.lastChecked = DateTime.now();
    } catch (e) {
      s.error = 'Aggiornamento non riuscito: $e';
    } finally {
      _refreshing.remove(s.id);
      await _save();
      notifyListeners();
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

  Future<void> _refreshFromPage(Shipment s) async {
    final carrier = carrierById(s.carrierId);
    final text = await reader.readText(carrier.trackingUri(s.number), mustContain: s.number);
    if (text.trim().isEmpty) {
      s.error = 'La pagina di ${carrier.name} non ha risposto. Riprova più tardi.';
      return;
    }
    final r = parseTrackingPage(text, s.number);
    if (!r.foundNumber && r.events.isEmpty) {
      s.error = r.status == ShipStatus.notFound
          ? '${carrier.name} non trova ancora questo numero. Se è appena stato spedito, riprova tra qualche ora; altrimenti controlla il corriere.'
          : 'Non sono riuscito a leggere la pagina di ${carrier.name}. Prova a cambiare corriere o riprova più tardi.';
      if (r.status == ShipStatus.notFound) s.status = ShipStatus.notFound;
      return;
    }
    s.status = r.status;
    if (r.events.isNotEmpty) s.events = r.events;
    s.eta = r.eta ?? (s.status == ShipStatus.delivered ? null : s.eta);
    s.error = null;
  }

  @visibleForTesting
  void debugAdd(Shipment s) => _items.add(s);
}
