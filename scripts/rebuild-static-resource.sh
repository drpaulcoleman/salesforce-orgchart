#!/usr/bin/env bash
# Rebuild OrgChartAssets.zip after editing assets/orgchart_magic_salesforce.js
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp "$ROOT/../assets/orgchart_magic_salesforce.js" "$STAGE/orgchart_magic.js"
cp "$ROOT/../assets/d3.v3.min.js" "$ROOT/../assets/jquery-3.3.1.min.js" \
  "$ROOT/../assets/style.css" \
  "$STAGE/"
# SLDS: strip @font-face block (lines 2–45). Relative font URLs break on VF — fonts load via OrgChart.page URLFOR.
SLDS_SRC="$ROOT/../assets/styles/salesforce-lightning-design-system.min.css"
{ head -n 1 "$SLDS_SRC"; echo '/*! @font-face omitted — registered in OrgChart.page */'; tail -n +47 "$SLDS_SRC"; } > "$STAGE/salesforce-lightning-design-system.min.css"
# Salesforce Sans webfonts (same major SLDS version). Run: curl from unpkg @salesforce-ux/design-system if missing.
if [[ -d "$ROOT/../assets/fonts/webfonts" ]] && compgen -G "$ROOT/../assets/fonts/webfonts/*.woff2" >/dev/null; then
  mkdir -p "$STAGE/fonts/webfonts"
  cp "$ROOT/../assets/fonts/webfonts/"*.woff2 "$ROOT/../assets/fonts/webfonts/"*.woff "$STAGE/fonts/webfonts/"
else
  echo "WARN: No fonts in assets/fonts/webfonts — download from @salesforce-ux/design-system (see README)." >&2
fi
cp -R "$ROOT/orgchart-ui/features" "$STAGE/"
( cd "$STAGE" && zip -r "$ROOT/force-app/main/default/staticresources/OrgChartAssets.zip" . )
echo "Updated force-app/main/default/staticresources/OrgChartAssets.zip"
