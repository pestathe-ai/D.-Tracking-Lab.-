import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

/// Browser invisibile interno all'app: apre la pagina ufficiale del
/// corriere e ne restituisce il testo, come lo vedrebbe una persona.
/// Una pagina alla volta.
class PageReader {
  PageReader() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          final c = _finished;
          if (c != null && !c.isCompleted) c.complete();
        },
      ));
  }

  late final WebViewController controller;
  Completer<void>? _finished;
  Future<void> _queue = Future.value();

  /// Legge [uri]. Aspetta che compaia [mustContain] (il numero del pacco)
  /// e che il testo smetta di cambiare, fino a [maxWait].
  Future<String> readText(Uri uri,
      {String? mustContain, Duration maxWait = const Duration(seconds: 25)}) {
    final job = _queue.then((_) => _read(uri, mustContain, maxWait));
    _queue = job.then((_) {}, onError: (_) {});
    return job;
  }

  Future<String> _read(Uri uri, String? mustContain, Duration maxWait) async {
    final deadline = DateTime.now().add(maxWait);
    _finished = Completer<void>();
    await controller.loadRequest(uri);
    try {
      await _finished!.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      // Alcune pagine non "finiscono" mai: proviamo comunque a leggerle.
    }

    var text = '';
    var previous = '';
    var stableRounds = 0;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      text = await _bodyText();
      final hasNumber = mustContain == null ||
          text.toUpperCase().replaceAll(RegExp(r'[\s\-\.]'), '').contains(mustContain);
      if (text.isNotEmpty && text == previous) {
        stableRounds++;
      } else {
        stableRounds = 0;
      }
      previous = text;
      if (hasNumber && stableRounds >= 1) break;
      if (!hasNumber && stableRounds >= 4) break; // la pagina non cambierà più
    }
    // Libera memoria e ferma eventuali script della pagina.
    unawaited(controller.loadRequest(Uri.parse('about:blank')).catchError((_) {}));
    return text;
  }

  Future<String> _bodyText() async {
    try {
      final r = await controller.runJavaScriptReturningResult(
          'document.body ? document.body.innerText : ""');
      if (r is String) {
        // Android restituisce la stringa codificata in JSON ("...").
        if (r.length >= 2 && r.startsWith('"')) {
          try {
            return jsonDecode(r) as String;
          } catch (_) {}
        }
        return r;
      }
      return r.toString();
    } catch (_) {
      return '';
    }
  }
}
