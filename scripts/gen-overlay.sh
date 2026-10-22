#!/usr/bin/env bash
# Usage: gen-overlay.sh <upstream-tree-dir> <out-dir>
# Generates <out-dir>/all.go (8 components only) and <out-dir>/overlay.json (absolute paths)
# for `go build -overlay`. Never modifies the upstream tree.
set -euo pipefail

if [ $# -ne 2 ]; then echo "usage: $0 <upstream-tree-dir> <out-dir>" >&2; exit 2; fi
HERE=$(cd "$(dirname "$0")/.." && pwd)
TREE=$(realpath "$1")
mkdir -p "$2"
OUT=$(realpath "$2")
STUBS="$HERE/overlay"

# name|import path suffix under internal/component/
KEEP="local.file_match|local/file_match
loki.source.file|loki/source/file
loki.write|loki/write
prometheus.exporter.dnsmasq|prometheus/exporter/dnsmasq
prometheus.exporter.unix|prometheus/exporter/unix
discovery.relabel|discovery/relabel
prometheus.scrape|prometheus/scrape
prometheus.remote_write|prometheus/remotewrite"

ALL="$TREE/internal/component/all/all.go"
[ -f "$ALL" ] || { echo "ERROR: missing $ALL" >&2; exit 1; }

# A line is kept only if BOTH its trailing "// Import <name>" comment (exact match)
# and its import path match one of the KEEP entries.
awk -v keep="$KEEP" '
BEGIN { n = split(keep, e, "\n"); for (i = 1; i <= n; i++) { split(e[i], p, "|"); path["// Import " p[1]] = "\"github.com/grafana/alloy/internal/component/" p[2] "\"" } }
/_ "github.com\/grafana\/alloy\/internal\/component\// {
  c = $0; sub(/^.*\/\/ /, "// ", c); sub(/[ \t]+$/, "", c)
  if ((c in path) && index($0, path[c]) > 0) print
  next
}
{ print }' "$ALL" > "$OUT/all.go"

COUNT=$(grep -c '_ "github.com/grafana/alloy/internal/component/' "$OUT/all.go" || true)
if [ "$COUNT" -ne 8 ]; then
  echo "ERROR: expected exactly 8 component imports in generated all.go, got $COUNT (upstream all.go drifted?)" >&2
  exit 1
fi

need() { [ -f "$1" ] || { echo "ERROR: expected upstream file missing: $1" >&2; exit 1; }; }
need "$TREE/collector/components.go"
need "$STUBS/components.go"

{
  echo '{"Replace":{'
  echo "\"$TREE/internal/component/all/all.go\":\"$OUT/all.go\","
  echo "\"$TREE/collector/components.go\":\"$STUBS/components.go\","
  if [ -f "$TREE/internal/converter/install/install.go" ]; then
    echo "gen-overlay: new-style layout (internal/converter/install)" >&2
    echo "\"$TREE/internal/converter/install/install.go\":\"$STUBS/converter-install.go\""
  else
    echo "gen-overlay: old-style layout (converter.go + static install)" >&2
    need "$TREE/internal/converter/converter.go"
    need "$TREE/internal/static/integrations/install/install.go"
    echo "\"$TREE/internal/converter/converter.go\":\"$STUBS/converter.go\","
    echo "\"$TREE/internal/static/integrations/install/install.go\":\"$STUBS/static-install.go\""
  fi
  echo '}}'
} > "$OUT/overlay.json"

echo "gen-overlay: 8 imports OK; wrote $OUT/overlay.json" >&2
