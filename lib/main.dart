import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'services/page_reader.dart';
import 'services/share_channel.dart';
import 'services/store.dart';
import 'ui/add_screen.dart';
import 'ui/home_screen.dart';
import 'ui/style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TrackingLabApp());
}

class TrackingLabApp extends StatefulWidget {
  const TrackingLabApp({super.key});

  @override
  State<TrackingLabApp> createState() => _TrackingLabAppState();
}

class _TrackingLabAppState extends State<TrackingLabApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final PageReader _reader;
  late final ShipmentStore _store;
  late final ShareChannel _share;
  StreamSubscription<IncomingShare>? _sub;

  @override
  void initState() {
    super.initState();
    _reader = PageReader();
    _store = ShipmentStore(_reader);
    _share = ShareChannel();
    _start();
  }

  Future<void> _start() async {
    await _store.load();
    _sub = _share.stream.listen((s) => _openAdd(text: s.text, source: s.source));
    final first = await _share.initial();
    if (first != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAdd(text: first.text, source: first.source));
    }
    unawaited(_store.refreshAll(onlyStale: true));
  }

  void _openAdd({String? text, String? source}) {
    final nav = _navigator.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute<void>(
      builder: (_) => AddScreen(store: _store, initialText: text, source: source),
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      title: 'D. Tracking lab',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (context, child) => Stack(
        children: [
          // Browser invisibile che legge le pagine dei corrieri:
          // sta sotto l'interfaccia, non si vede e non si tocca.
          Positioned(
            left: 0,
            top: 0,
            width: 380,
            height: 760,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.01,
                child: WebViewWidget(controller: _reader.controller),
              ),
            ),
          ),
          Positioned.fill(child: child ?? const SizedBox.shrink()),
        ],
      ),
      home: HomeScreen(store: _store, onAdd: () => _openAdd()),
    );
  }
}
