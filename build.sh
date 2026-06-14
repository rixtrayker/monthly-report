#!/usr/bin/env bash
#
# build.sh — re-embed report-data.json into index.html
#
# The page reads its data two ways:
#   1. fetch('report-data.json')  — used when served over HTTP (e.g. GitHub Pages)
#   2. window.__EMBED__           — a fallback baked into index.html so the page
#                                   still works when opened directly (file://, double-click)
#
# When you edit report-data.json you MUST re-run this so the embedded fallback
# stays in sync with the fetched data. Otherwise file:// shows stale numbers.
#
# Usage:
#   ./build.sh            # re-embed, then report status
#   ./build.sh --check    # verify embed is in sync; exit 1 if it drifted (no writes)
#
set -euo pipefail

cd "$(dirname "$0")"

DATA="report-data.json"
HTML="index.html"

if [ ! -f "$DATA" ] || [ ! -f "$HTML" ]; then
  echo "error: must be run from the repo root (missing $DATA or $HTML)" >&2
  exit 1
fi

python3 - "$DATA" "$HTML" "${1:-}" <<'PY'
import json, re, sys

data_path, html_path, mode = sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""

data = open(data_path, encoding="utf-8").read()
json.loads(data)  # validate JSON before touching the HTML

html = open(html_path, encoding="utf-8").read()

pat = re.compile(r"(window\.__EMBED__ = )\{.*?\}(;)", re.S)
m = pat.search(html)
if not m:
    sys.exit("error: could not find 'window.__EMBED__ = {...};' block in " + html_path)

current = json.loads(m.group(0)[len(m.group(1)):-1])
in_sync = current == json.loads(data)

if mode == "--check":
    if in_sync:
        print("OK: embedded data is in sync with " + data_path)
        sys.exit(0)
    print("DRIFT: index.html embed differs from " + data_path + " — run ./build.sh", file=sys.stderr)
    sys.exit(1)

if in_sync:
    print("Already in sync — nothing to do.")
    sys.exit(0)

new = pat.sub(lambda mm: mm.group(1) + data.strip() + mm.group(2), html, count=1)
open(html_path, "w", encoding="utf-8").write(new)
print("Re-embedded " + data_path + " into " + html_path + ".")
PY
