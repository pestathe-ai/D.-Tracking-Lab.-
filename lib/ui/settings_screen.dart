import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/store.dart';
import '../services/track17.dart';
import 'place_picker.dart';
import 'style.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final ShipmentStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _key;
  bool _checking = false;
  String? _keyInfo;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController(text: widget.store.apiKey);
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _saveAndCheck() async {
    final key = _key.text.trim();
    await widget.store.setApiKey(key);
    if (key.isEmpty) {
      setState(() => _keyInfo = 'Chiave rimossa: l\'app usa solo la lettura gratuita delle pagine.');
      return;
    }
    setState(() {
      _checking = true;
      _keyInfo = null;
    });
    try {
      final q = await Track17Client(key).quota();
      _keyInfo = 'Chiave valida: ${q.remaining} spedizioni rimaste su ${q.total}.';
    } catch (e) {
      _keyInfo = 'Verifica non riuscita: $e';
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget section(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(t,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            section('Come si aggiornano i pacchi'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Gratis e senza account: per BRT, DPD (consegnato da BRT), InPost, Poste, SDA e Amazon l\'app chiede '
                'lo stato direttamente ai servizi pubblici del corriere e ti mostra qui stato e passaggi. '
                'Si aggiorna quando apri l\'app (al massimo ogni 30 minuti) o quando tiri giù la lista.\n'
                'Alcuni corrieri (DHL, UPS, GLS) vietano la lettura automatica del loro sito: '
                'per loro puoi aprire la pagina dentro l\'app o usare la chiave 17TRACK qui sotto.',
                style: muted,
              ),
            ),
            SwitchListTile(
              title: const Text('Proponi i codici copiati'),
              subtitle: const Text(
                  'All\'apertura controlla gli appunti e ti propone di aggiungere il numero copiato.'),
              value: widget.store.checkClipboard,
              onChanged: (v) => widget.store.setCheckClipboard(v),
            ),
            section('Luoghi di consegna'),
            if (widget.store.places.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Nessun luogo ancora. Scegline uno quando aggiungi o modifichi un pacco.',
                    style: muted),
              ),
            for (final p in widget.store.places)
              ListTile(
                leading: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => pickPlaceColor(context, widget.store, p),
                  child: CircleAvatar(radius: 14, backgroundColor: placeColor(widget.store.placeColorIndex(p))),
                ),
                title: Text(p),
                subtitle: const Text('Tocca il pallino per cambiare colore'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final n = await askPlaceName(context, initial: p, title: 'Rinomina luogo');
                      if (n != null) await widget.store.renamePlace(p, n);
                    } else if (v == 'remove') {
                      await widget.store.removePlace(p);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                    PopupMenuItem(value: 'remove', child: Text('Elimina')),
                  ],
                ),
              ),
            section('Scorciatoie dalle altre app'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '• Tieni premuto sul numero di tracking in qualsiasi app, poi scegli '
                '"Aggiungi a D. Tracking lab" nel menu (a volte è sotto i tre puntini).\n'
                '• Da un\'email o da un\'app di un negozio: Condividi → D. Tracking lab.\n'
                'Se arrivi da un\'app di un negozio (Amazon, Zalando, Shein, Temu…) o da un\'email '
                'di conferma, il negozio viene riconosciuto da solo.',
                style: muted?.copyWith(height: 1.5),
              ),
            ),
            section('Precisione extra (facoltativa)'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Se un corriere non si legge bene, puoi aggiungere una chiave gratuita di 17TRACK: '
                'le prime 200 spedizioni sono gratis, poi il servizio è a pagamento. '
                'Quando le spedizioni finiscono, l\'app torna da sola alla lettura gratuita.',
                style: muted,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _key,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Chiave 17TRACK (facoltativa)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  FilledButton(
                    onPressed: _checking ? null : _saveAndCheck,
                    child: Text(_checking ? 'Verifico…' : 'Salva e verifica'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse('https://www.17track.net/en/api'),
                        mode: LaunchMode.externalApplication),
                    child: const Text('Crea una chiave'),
                  ),
                ],
              ),
            ),
            if (_keyInfo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(_keyInfo!, style: theme.textTheme.bodyMedium),
              ),
            const SizedBox(height: 32),
            Center(child: Text('D. Tracking lab · versione 0.6', style: muted)),
            const SizedBox(height: 4),
            Center(child: Text('un\'app Dom Studio', style: theme.textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}
