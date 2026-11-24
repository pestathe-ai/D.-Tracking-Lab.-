import 'package:flutter/material.dart';

import '../services/store.dart';
import 'style.dart';

/// Scelta rapida del luogo di consegna: luoghi già usati, i più comuni,
/// oppure uno nuovo scritto a mano.
class PlacePicker extends StatelessWidget {
  const PlacePicker({super.key, required this.store, required this.value, required this.onChanged});

  final ShipmentStore store;
  final String? value;
  final ValueChanged<String?> onChanged;

  static const suggestions = ['Casa', 'Ufficio', 'Fermopoint', 'Locker'];

  @override
  Widget build(BuildContext context) {
    final options = <String>[
      ...store.places,
      ...suggestions.where((s) => !store.places.contains(s)),
      if (value != null && !store.places.contains(value) && !suggestions.contains(value)) value!,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final p in options)
          ChoiceChip(
            avatar: CircleAvatar(
              radius: 7,
              backgroundColor: store.placeColors.containsKey(p) || value == p
                  ? placeColor(store.placeColorIndex(p))
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            label: Text(p),
            selected: value == p,
            onSelected: (sel) => onChanged(sel ? p : null),
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Altro…'),
          onPressed: () async {
            final name = await askPlaceName(context);
            if (name != null) onChanged(name);
          },
        ),
      ],
    );
  }
}

Future<String?> askPlaceName(BuildContext context, {String initial = '', String title = 'Nuovo luogo'}) async {
  final c = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Es. Casa al mare, Ufficio Milano'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
      ],
    ),
  );
  final v = r?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

/// Scelta del colore di un luogo.
Future<void> pickPlaceColor(BuildContext context, ShipmentStore store, String place) async {
  final current = store.placeColorIndex(place);
  final chosen = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Colore di "$place"', style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (var i = 0; i < placePalette.length; i++)
                Tooltip(
                  message: placePaletteNames[i],
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(ctx, i),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: placePalette[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == current ? Theme.of(ctx).colorScheme.onSurface : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: i == current ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
  if (chosen != null) await store.setPlaceColor(place, chosen);
}
