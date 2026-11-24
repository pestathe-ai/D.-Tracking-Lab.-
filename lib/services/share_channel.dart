import 'dart:async';

import 'package:flutter/services.dart';

/// Testo arrivato da un'altra app ("Condividi" o selezione testo →
/// "Aggiungi a D. Tracking lab"), con l'app di provenienza se nota.
class IncomingShare {
  const IncomingShare(this.text, this.source);
  final String text;
  final String? source;
}

class ShareChannel {
  ShareChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final s = _parse(call.arguments);
        if (s != null) _events.add(s);
      }
      return null;
    });
  }

  static const _channel = MethodChannel('dtl/share');
  final _events = StreamController<IncomingShare>.broadcast();

  Stream<IncomingShare> get stream => _events.stream;

  Future<IncomingShare?> initial() async {
    try {
      return _parse(await _channel.invokeMethod<Object?>('getInitial'));
    } catch (_) {
      return null;
    }
  }

  static IncomingShare? _parse(Object? raw) {
    if (raw is! Map) return null;
    final text = (raw['text'] as String?) ?? '';
    final source = raw['source'] as String?;
    if (text.trim().isEmpty) return null;
    return IncomingShare(text, (source == null || source.isEmpty) ? null : source);
  }
}
