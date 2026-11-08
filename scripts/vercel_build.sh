#!/bin/bash
# Vercel build: AQARATI_TARGET=admin builds the admin console, otherwise the customer app.
set -e
ENTRY=lib/main.dart
if [ "$AQARATI_TARGET" = "admin" ]; then ENTRY=lib/admin_main.dart; fi
./flutter-sdk/bin/flutter build web -t "$ENTRY" --release --pwa-strategy=none --no-web-resources-cdn --dart-define=AQARATI_DEMO_MODE="${AQARATI_DEMO_MODE:-false}"
