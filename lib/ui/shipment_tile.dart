import 'package:flutter/material.dart';

import '../core/carriers.dart';
import '../core/models.dart';
import '../services/store.dart';
import 'detail_screen.dart';
import 'style.dart';

/// Scheda di un pacco nella lista. Scorri a destra per archiviare,
/// a sinistra per eliminare.
class ShipmentTile extends StatelessWidget {
  const ShipmentTile({super.key, required this.store, required this.shipment});

  final ShipmentStore store;
  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final s = shipment;
    final theme = Theme.of(context);
    final color = statusColor(s.status, theme.brightness);
    final carrier = carrierById(s.carrierId);
    final latest = s.latest;
    final refreshing = store.isRefreshing(s.id);

    final carrierName = carrier.id == 'other' ? (s.serviceCarrier ?? carrier.name) : carrier.name;
    final place = s.place;
    final pColor = place == null ? null : placeColor(store.placeColorIndex(place));

    return Dismissible(
      key: ValueKey(s.id),
      background: _swipeBg(context, Icons.archive_rounded,
          s.archived ? 'Ripristina' : 'Archivia', Colors.teal, Alignment.centerLeft),
      secondaryBackground:
          _swipeBg(context, Icons.delete_rounded, 'Elimina', Colors.red, Alignment.centerRight),
      onDismissed: (dir) async {
        final messenger = ScaffoldMessenger.of(context);
        if (dir == DismissDirection.startToEnd) {
          final wasArchived = s.archived;
          await store.setArchived(s, !wasArchived);
          messenger.showSnackBar(SnackBar(
            content: Text(wasArchived ? 'Ripristinato' : 'Archiviato'),
            action: SnackBarAction(
                label: 'Annulla', onPressed: () => store.setArchived(s, wasArchived)),
          ));
        } else {
          await store.remove(s);
          messenger.showSnackBar(SnackBar(
            content: const Text('Pacco eliminato'),
            action: SnackBarAction(label: 'Annulla', onPressed: () => store.restore(s)),
          ));
        }
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => DetailScreen(store: store, id: s.id),
          )),
          child: Container(
            // Barra laterale del colore del luogo di consegna.
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: pColor ?? Colors.transparent, width: 6),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: refreshing
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
                        )
                      : Icon(statusIcon(s.status), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (s.shop != null) ShopBadge(s.shop!),
                          if (place != null) PlaceBadge(place, pColor!),
                          Text(carrierName, style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(s.status.label,
                          style: theme.textTheme.labelLarge?.copyWith(color: color)),
                      if (latest != null)
                        Text(
                          '${latest.time != null ? '${formatWhen(latest.time!)} · ' : ''}${latest.description}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (s.eta != null && s.status != ShipStatus.delivered) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 0,
                    child: Text(formatEta(s.eta!).replaceFirst('Arriva ', ''),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeBg(BuildContext context, IconData icon, String label, Color color, Alignment align) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: align,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
