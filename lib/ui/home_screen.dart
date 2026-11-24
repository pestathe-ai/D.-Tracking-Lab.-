import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/extract.dart';
import '../core/models.dart';
import '../services/store.dart';
import 'add_screen.dart';
import 'archive_screen.dart';
import 'settings_screen.dart';
import 'shipment_tile.dart';
import 'style.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, required this.onAdd});

  final ShipmentStore store;
  final VoidCallback onAdd;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? _clipNumber;
  String? _placeFilter;
  bool _showSent = false;
  String _clipText = '';

  ShipmentStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
      store.refreshAll(onlyStale: true);
    }
  }

  /// Se hai appena copiato un numero di tracking, l'app lo propone.
  Future<void> _checkClipboard() async {
    if (!store.loaded) await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!store.checkClipboard) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isEmpty || text.length > 5000) return;
      for (final n in extractTrackingNumbers(text)) {
        if (store.byNumber(n) != null || n == store.lastOfferedClipboard) continue;
        if (mounted) {
          setState(() {
            _clipNumber = n;
            _clipText = text;
          });
        }
        return;
      }
    } catch (_) {}
  }

  void _dismissClip() {
    if (_clipNumber != null) store.markClipboardOffered(_clipNumber!);
    setState(() => _clipNumber = null);
  }

  void _addFromClip() {
    final text = _clipText;
    _dismissClip();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AddScreen(store: store, initialText: text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final places = store.places;
        if (_placeFilter != null && !places.contains(_placeFilter)) _placeFilter = null;
        final incomingCount = store.active.where((s) => !s.sent).length;
        final sentCount = store.active.where((s) => s.sent).length;
        final active = store.active
            .where((s) => s.sent == _showSent)
            .where((s) => _placeFilter == null || s.place == _placeFilter)
            .toList();
        final attention = active.where((s) => s.status.needsAttention).toList();
        final delivered = active.where((s) => s.status == ShipStatus.delivered).toList();
        final transit = active
            .where((s) => !s.status.needsAttention && s.status != ShipStatus.delivered)
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/icon/icon.png', width: 30, height: 30),
                ),
                const SizedBox(width: 10),
                const Flexible(child: Text('D. Tracking lab', overflow: TextOverflow.ellipsis)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Archivio',
                icon: const Icon(Icons.inventory_2_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ArchiveScreen(store: store),
                )),
              ),
              IconButton(
                tooltip: 'Impostazioni',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(store: store),
                )),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AddScreen(store: store, sent: _showSent),
            )),
            icon: const Icon(Icons.add_rounded),
            label: Text(_showSent ? 'Aggiungi spedito' : 'Aggiungi'),
          ),
          body: !store.loaded
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => store.refreshAll(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 4, bottom: 100),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: false,
                              icon: const Icon(Icons.call_received_rounded),
                              label: Text('In arrivo ($incomingCount)'),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: const Icon(Icons.call_made_rounded),
                              label: Text('Spediti ($sentCount)'),
                            ),
                          ],
                          selected: {_showSent},
                          onSelectionChanged: (v) => setState(() => _showSent = v.first),
                        ),
                      ),
                      if (_clipNumber != null) _clipCard(theme),
                      if (places.length >= 2) _placeFilterBar(places),
                      if (active.isEmpty && _placeFilter == null && !_showSent) _empty(theme),
                      if (active.isEmpty && _placeFilter == null && _showSent)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 48, 32, 12),
                          child: Text(
                            'Nessun pacco spedito.\nTocca "Aggiungi spedito" per seguire un pacco che hai mandato tu: '
                            'resi, vendite su Vinted o eBay, regali.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                          ),
                        ),
                      if (active.isEmpty && _placeFilter != null)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(_showSent ? 'Nessun pacco spedito verso "$_placeFilter".' : 'Nessun pacco in arrivo a "$_placeFilter".',
                              textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                        ),
                      if (attention.isNotEmpty) ...[
                        _header(theme, 'Da tenere d\'occhio'),
                        for (final s in attention) ShipmentTile(store: store, shipment: s),
                      ],
                      if (transit.isNotEmpty) ...[
                        _header(theme, 'In viaggio'),
                        for (final s in transit) ShipmentTile(store: store, shipment: s),
                      ],
                      if (delivered.isNotEmpty) ...[
                        _header(theme, 'Consegnati'),
                        for (final s in delivered) ShipmentTile(store: store, shipment: s),
                      ],
                      const SizedBox(height: 24),
                      Center(
                        child: Text('un\'app Dom Studio',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _placeFilterBar(List<String> places) => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          children: [
            ChoiceChip(
              label: const Text('Tutti'),
              selected: _placeFilter == null,
              onSelected: (_) => setState(() => _placeFilter = null),
            ),
            for (final p in places) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: placeColor(store.placeColorIndex(p)), radius: 7),
                label: Text(p),
                selected: _placeFilter == p,
                onSelected: (sel) => setState(() => _placeFilter = sel ? p : null),
              ),
            ],
          ],
        ),
      );

  Widget _header(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Text(text,
            style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
      );

  Widget _clipCard(ThemeData theme) => Card(
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hai copiato un codice di tracking',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
              const SizedBox(height: 2),
              Text(_clipNumber!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer, letterSpacing: 0.5)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _dismissClip,
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onPrimaryContainer),
                    child: const Text('No, grazie'),
                  ),
                  FilledButton(
                    onPressed: _addFromClip,
                    style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.onPrimaryContainer,
                        foregroundColor: theme.colorScheme.primaryContainer),
                    child: const Text('Aggiungi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _empty(ThemeData theme) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 12),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset('assets/icon/icon.png', width: 112, height: 112),
            ),
            const SizedBox(height: 20),
            Text('Nessun pacco in arrivo', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              'Tocca "Aggiungi", oppure da qualsiasi app:\n'
              '• tieni premuto sul numero di tracking → "Aggiungi a D. Tracking lab"\n'
              '• Condividi → D. Tracking lab\n'
              '• copia il numero e apri l\'app',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      );
}
