import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/carriers.dart';
import '../core/models.dart';
import '../services/store.dart';
import 'page_screen.dart';
import 'place_picker.dart';
import 'style.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.store, required this.id});

  final ShipmentStore store;
  final String id;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.byId(id);
        if (s == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Pacco eliminato')));
        }
        return _Detail(store: store, s: s);
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.store, required this.s});

  final ShipmentStore store;
  final Shipment s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = statusColor(s.status, theme.brightness);
    final carrier = carrierById(s.carrierId);
    final refreshing = store.isRefreshing(s.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Modifica',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              final nav = Navigator.of(context);
              if (v == 'archive') {
                await store.setArchived(s, !s.archived);
                nav.pop();
              } else if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Eliminare il pacco?'),
                    content: Text(s.title),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Elimina')),
                    ],
                  ),
                );
                if (ok == true) {
                  await store.remove(s);
                  nav.pop();
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'archive', child: Text(s.archived ? 'Ripristina' : 'Archivia')),
              const PopupMenuItem(value: 'delete', child: Text('Elimina')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => store.refresh(s),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            // Stato
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(statusIcon(s.status), color: color, size: 44),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.status.label,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: color, fontWeight: FontWeight.w700)),
                        if (s.eta != null && s.status != ShipStatus.delivered)
                          Text(formatEta(s.eta!), style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          refreshing
                              ? 'Aggiornamento in corso…'
                              : s.lastChecked == null
                                  ? 'Mai aggiornato'
                                  : 'Controllato ${formatWhen(s.lastChecked!)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (refreshing)
                    SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: color))
                  else
                    IconButton(
                      tooltip: 'Aggiorna',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () => store.refresh(s),
                    ),
                ],
              ),
            ),
            if (s.error != null) ...[
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(s.error!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Informazioni
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.place_rounded,
                        color: s.place == null ? null : placeColor(store.placeColorIndex(s.place!))),
                    title: Text(s.place ?? 'Scegli dove arriva'),
                    subtitle: Text(s.note ?? 'Luogo di consegna'),
                    trailing: s.place == null
                        ? null
                        : IconButton(
                            tooltip: 'Colore',
                            icon: CircleAvatar(
                                radius: 11, backgroundColor: placeColor(store.placeColorIndex(s.place!))),
                            onPressed: () => pickPlaceColor(context, store, s.place!),
                          ),
                    onTap: () => _edit(context),
                  ),
                  if (s.sent)
                    ListTile(
                      leading: const Icon(Icons.call_made_rounded),
                      title: Align(
                        alignment: Alignment.centerLeft,
                        child: s.recipient == null
                            ? const Text('Destinatario non indicato')
                            : RecipientBadge(s.recipient!, large: true),
                      ),
                      subtitle: const Text('Spedito da te a'),
                      onTap: () => _edit(context),
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Align(
                        alignment: Alignment.centerLeft,
                        child: s.shop == null ? const Text('Negozio non indicato') : ShopBadge(s.shop!, large: true),
                      ),
                      subtitle: const Text('Negozio'),
                      onTap: () => _edit(context),
                    ),
                  ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(carrier.id == 'other' ? (s.serviceCarrier ?? carrier.name) : carrier.name),
                    subtitle: const Text('Corriere'),
                    onTap: () => _edit(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.tag_rounded),
                    title: SelectableText(s.number),
                    subtitle: const Text('Numero di tracking'),
                    trailing: IconButton(
                      tooltip: 'Copia',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: s.number));
                        store.markClipboardOffered(s.number);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Numero copiato')));
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Passaggi', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (s.events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  refreshing
                      ? 'Sto leggendo le informazioni del corriere…'
                      : 'Ancora nessun passaggio. Tira giù per aggiornare.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              for (var i = 0; i < s.events.length; i++)
                _EventRow(event: s.events[i], first: i == 0, last: i == s.events.length - 1, color: color),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PageScreen(
                  title: carrier.id == 'other' ? 'Tracking' : carrier.name,
                  uri: carrier.trackingUri(s.number),
                ),
              )),
              icon: const Icon(Icons.public_rounded),
              label: const Text('Mostra la pagina originale del corriere'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final name = TextEditingController(text: s.name ?? '');
    final shop = TextEditingController(text: s.shop ?? '');
    var carrierId = s.carrierId;
    String? place = s.place;
    var sent = s.sent;
    final recipient = TextEditingController(text: s.recipient ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (c, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Modifica pacco', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('L\'ho spedito io'),
                subtitle: const Text('Lo sposta nella sezione "Spediti"'),
                value: sent,
                onChanged: (v) => setSheet(() => sent = v),
              ),
              if (sent)
                TextField(
                  controller: recipient,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Destinatario', border: OutlineInputBorder()),
                )
              else
                TextField(
                  controller: shop,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Negozio', border: OutlineInputBorder()),
                ),
              const SizedBox(height: 14),
              Text(sent ? 'Dove va' : 'Dove arriva', style: Theme.of(c).textTheme.labelLarge),
              const SizedBox(height: 6),
              PlacePicker(store: store, value: place, onChanged: (v) => setSheet(() => place = v)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: carrierId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Corriere', border: OutlineInputBorder()),
                items: [
                  for (final c in allCarriers) DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setSheet(() => carrierId = v ?? carrierId),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salva')),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;
    s.name = name.text.trim().isEmpty ? null : name.text.trim();
    s.shop = shop.text.trim().isEmpty ? null : shop.text.trim();
    s.sent = sent;
    s.recipient = recipient.text.trim().isEmpty ? null : recipient.text.trim();
    final carrierChanged = carrierId != s.carrierId;
    s.carrierId = carrierId;
    await store.setPlace(s, place);
    if (carrierChanged) await store.refresh(s);
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.first, required this.last, required this.color});

  final TrackEvent event;
  final bool first;
  final bool last;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.colorScheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(width: 2, height: 6, color: first ? Colors.transparent : lineColor),
                Container(
                  width: first ? 14 : 10,
                  height: first ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: first ? color : lineColor,
                  ),
                ),
                Expanded(child: Container(width: 2, color: last ? Colors.transparent : lineColor)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.description,
                      style: first
                          ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
                          : theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (event.time != null) formatWhen(event.time!),
                      if (event.location != null) event.location!,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
