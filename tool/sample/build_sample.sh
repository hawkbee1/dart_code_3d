#!/usr/bin/env bash
# Rebuilds assets/samples/sample.dc3d from tool/sample/sample_source.txt (a
# small weather app, one "=== <path>" header per file) with the engine and
# layout CLIs. Run from anywhere inside the hawkbee checkout.
set -euo pipefail
app="$(cd "$(dirname "$0")/../.." && pwd)"
root="$(cd "$app/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -r "$work"' EXIT

awk -v out="$work/weather_sample" '
  /^=== / { file = out "/" substr($0, 5); system("mkdir -p \"$(dirname \"" file "\")\""); next }
  { print > file }
' "$app/tool/sample/sample_source.txt"

cd "$root/packages/code_analysis_engine"
dart run code_analysis_engine:analyze "$work/weather_sample" --out "$work/graph.json" --stats
cd "$root/packages/code_layout"
dart run code_layout:layout "$work/graph.json" --out "$app/assets/samples/sample.dc3d"
echo "wrote $app/assets/samples/sample.dc3d"
