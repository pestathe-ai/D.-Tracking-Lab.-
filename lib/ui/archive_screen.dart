import 'package:flutter/material.dart';

import '../services/store.dart';
import 'shipment_tile.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key, required this.store});

  final ShipmentStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archivio')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.archived;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nessun pacco archiviato.\nNella lista, scorri un pacco verso destra per archiviarlo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [for (final s in items) ShipmentTile(store: store, shipment: s)],
          );
        },
      ),
    );
  }
}
