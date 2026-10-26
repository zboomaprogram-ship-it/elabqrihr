#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "================================================================"
echo "T063 Android Dynamic Outbox Process-Restart Acceptance"
echo "Invoking Dart acceptance runner on connected Android target..."
echo "================================================================"

cd "${MOBILE_DIR}"
dart run tool/run_dynamic_restart_acceptance.dart
