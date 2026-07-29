#!/usr/bin/env bash
# Regenerate the PDTF entity-graph diagrams from source, and mirror them to public/.
#
# Requires:
#   d2            https://d2lang.com          (schema diagram)
#   twopi         graphviz                    (radial worked example)
#   rsvg-convert  librsvg                     (SVG -> PNG, since d2's PNG path needs a browser)
#
# Usage:  ./render.sh
set -euo pipefail
cd "$(dirname "$0")"

PUB="$(git rev-parse --show-toplevel)/public/diagrams"
mkdir -p "$PUB"

# ── Schema-level entity graph (D2, top-down, Offer nests buyer-side credentials) ──
d2 --theme 0 entity-graph.d2 entity-graph.svg
rsvg-convert -z 2 entity-graph.svg -o entity-graph.png

# ── Worked example (Graphviz twopi, radial, nested two-intents) ──
twopi -Tsvg               entity-graph-example-intents.dot -o entity-graph-example-intents.svg
twopi -Tpng -Gdpi=192     entity-graph-example-intents.dot -o entity-graph-example-intents.png

# ── Mirror sources + renders to public/ for the site ──
cp entity-graph.d2  entity-graph.svg  entity-graph.png \
   entity-graph-example-intents.dot  entity-graph-example-intents.svg  entity-graph-example-intents.png \
   "$PUB"/

echo "✓ Rendered and mirrored to $PUB"
