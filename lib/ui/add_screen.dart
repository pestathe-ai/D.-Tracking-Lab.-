import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/carriers.dart';
import '../core/extract.dart';
import '../core/shops.dart';
import '../services/store.dart';
import 'detail_screen.dart';
import 'place_picker.dart';
import 'scan_screen.dart';

/// Aggiunta di un pacco. Se arriva testo da un'altra app, numero,
/// corriere e negozio vengono compilati da soli.
class AddScreen extends StatefulWidget {
  const AddScreen({super.key, required this.store, this.initialText, this.source, this.sent = false});

  final ShipmentStore store;
  final String? initialText;
  final String? source;

  /// Apre già impostato su "L'ho spedito".
  final bool sent;

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _shop = TextEditingController();
  List<String> _found = [];
  List<Carrier> _candidates = [];
  String _carrierId = 'other';
  bool _carrierTouched = false;
  String _context = '';
  String? _error;
  bool _saving = false;
  String? _place;
  late bool _sent = widget.sent;
  final _recipient = TextEditingController();

  @override
  void initState() {
    super.initState();
    final text = widget.initialText ?? '';
    _context = text;
    if (text.isNotEmpty) {
      _found = extractTrackingNumbers(text);
      if (_found.isNotEmpty) _number.text = _found.first;
      final shop = detectShop(source: widget.source, text: text);
      if (shop != null) _shop.text = shop;
      if (_found.isEmpty) {
        _error = 'Non ho trovato un numero di tracking nel testo. Scrivilo o scansionalo.';
      }
    } else if (widget.source != null) {
      final shop = detectShop(source: widget.source);
      if (shop != null) _shop.text = shop;
    }
    _detect();
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _shop.dispose();
    _recipient.dispose();
    super.dispose();
  }

  void _detect() {
    final n = normalizeNumber(_number.text);
    _candidates = n.length >= 6 ? detectCarriers(n, context: _context) : [];
    if (!_carrierTouched) {
      _carrierId = _candidates.isNotEmpty ? _candidates.first.id : 'other';
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) return;
    final nums = extractTrackingNumbers(text);
    setState(() {
      _context = text;
      _found = nums;
      _number.text = nums.isNotEmpty ? nums.first : normalizeNumber(text);
      if (_shop.text.isEmpty) _shop.text = detectShop(text: text) ?? '';
      _error = null;
      _detect();
    });
  }

  Future<void> _scan() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (value == null || !mounted) return;
    final nums = extractTrackingNumbers(value);
    setState(() {
      _number.text = nums.isNotEmpty ? nums.first : normalizeNumber(value);
      _error = null;
      _detect();
    });
  }

  Future<void> _save() async {
    final n = normalizeNumber(_number.text);
    if (n.length < 6) {
      setState(() => _error = 'Il numero è troppo corto.');
      return;
    }
    final existing = widget.store.byNumber(n);
    final nav = Navigator.of(context);
    if (existing != null) {
      nav.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => DetailScreen(store: widget.store, id: existing.id),
      ));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Questo pacco c\'è già')));
      return;
    }
    setState(() => _saving = true);
    final s = await widget.store.add(
      number: n,
      carrierId: _carrierId,
      name: _name.text,
      shop: _shop.text,
      sent: _sent,
      recipient: _recipient.text,
    );
    if (_place != null) await widget.store.setPlace(s, _place);
    unawaited(widget.store.refresh(s));
    nav.pushReplacement(MaterialPageRoute<void>(
      builder: (_) => DetailScreen(store: widget.store, id: s.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidateIds = _candidates.map((c) => c.id).toSet();
    final ordered = [
      ..._candidates,
      ...allCarriers.where((c) => !candidateIds.contains(c.id)),
    ];
    final shopSuggestions = [
      ...popularShops.where((s) => s != _shop.text),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_sent ? 'Nuovo pacco spedito' : 'Nuovo pacco')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.call_received_rounded), label: Text('Lo ricevo')),
              ButtonSegment(value: true, icon: Icon(Icons.call_made_rounded), label: Text('L\'ho spedito')),
            ],
            selected: {_sent},
            onSelectionChanged: (v) => setState(() => _sent = v.first),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _number,
            autofocus: widget.initialText == null,
            textCapitalization: TextCapitalization.characters,
            style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 0.5),
            decoration: InputDecoration(
              labelText: 'Numero di tracking',
              border: const OutlineInputBorder(),
              errorText: _error,
              errorMaxLines: 3,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      tooltip: 'Incolla',
                      icon: const Icon(Icons.content_paste_rounded),
                      onPressed: _paste),
                  IconButton(
                      tooltip: 'Scansiona',
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      onPressed: _scan),
                ],
              ),
            ),
            onChanged: (_) => setState(() {
              _error = null;
              _detect();
            }),
            onSubmitted: (_) => _save(),
          ),
          if (_found.length > 1) ...[
            const SizedBox(height: 10),
            Text('Altri codici trovati nel testo', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final n in _found)
                  ChoiceChip(
                    label: Text(n),
                    selected: normalizeNumber(_number.text) == n,
                    onSelected: (_) => setState(() {
                      _number.text = n;
                      _detect();
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            // La chiave fa ripartire il campo quando il corriere viene riconosciuto.
            key: ValueKey('carrier-$_carrierId-${_candidates.length}'),
            initialValue: _carrierId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Corriere',
              border: const OutlineInputBorder(),
              helperText: _candidates.isEmpty
                  ? 'Non riconosciuto: sceglilo tu o lascia "Altro"'
                  : _candidates.length > 1
                      ? 'Più corrieri usano questo formato: controlla che sia giusto'
                      : 'Riconosciuto automaticamente',
            ),
            items: [
              for (final c in ordered)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(candidateIds.contains(c.id) && c.id == _candidates.first.id
                      ? '${c.name}  ✓'
                      : c.name),
                ),
            ],
            onChanged: (v) => setState(() {
              _carrierId = v ?? 'other';
              _carrierTouched = true;
            }),
          ),
          const SizedBox(height: 20),
          if (_sent)
            TextField(
              controller: _recipient,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Destinatario',
                hintText: 'A chi l\'hai spedito',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
          if (!_sent) TextField(
            controller: _shop,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Negozio',
              hintText: 'Da dove l\'hai comprato',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (!_sent) const SizedBox(height: 8),
          if (!_sent) Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in shopSuggestions)
                ActionChip(label: Text(s), onPressed: () => setState(() => _shop.text = s)),
            ],
          ),
          const SizedBox(height: 20),
          Text(_sent ? 'Dove va (facoltativo)' : 'Dove arriva (facoltativo)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          PlacePicker(store: widget.store, value: _place, onChanged: (v) => setState(() => _place = v)),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome (facoltativo)',
              hintText: 'Es. Scarpe da corsa',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              minimumSize: const Size.fromHeight(54),
              textStyle: theme.textTheme.titleMedium,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Aggiungi pacco'),
          ),
        ],
      ),
    );
  }
}
