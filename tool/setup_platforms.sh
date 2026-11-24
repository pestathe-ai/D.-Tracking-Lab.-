#!/usr/bin/env bash
# Rigenera le cartelle di piattaforma (non salvate nel repository)
# e applica le personalizzazioni Android.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --project-name d_tracking_lab --org dev.dtrackinglab --platforms=android .
rm -f test/widget_test.dart
python3 tool/patch_android.py .
flutter pub get
dart run flutter_launcher_icons
