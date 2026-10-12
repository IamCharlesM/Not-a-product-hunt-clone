#!/usr/bin/env bash
# Fails (exit 1) if a known PolinRider payload indicator is found in tracked files.
# Reads files only. Runs no repo code. Run it BEFORE any install.
# See the PolinRider incident notes (2026-10-12).
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 2

# Marker strings of the PolinRider payload (any tracked text file).
SIG='global\[.!.\]|global\[.?_V.?\]|global\.i *=|rm[c]ej%otb%|_\$_1e42|Cot%3[t]=shtP|function MD[y]|temp_auto_pus[h]\.bat'
# Obfuscation decoder: only checked in config and root tooling files.
DECODER='fromCharCode'
SKIP='(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|scripts/check-payload\.sh|\.yarn|node_modules|vendor)(/|$)|\.min\.'
# Config, tooling and root-level files: any line over 1000 characters fails.
STRICT='(^[^/]+\.(js|mjs|cjs)$|\.config\.(js|mjs|cjs|ts|mts|cts)$|^\.storybook/|^\.github/|^\.claude/|^scripts/.*\.(js|mjs|cjs|sh)$)'

fail=0
files=$(git ls-files 2>/dev/null | grep -Ev "$SKIP")
if [ -z "$files" ]; then echo "check-payload: OK (no files)"; exit 0; fi

while IFS= read -r f; do
  [ -f "$f" ] || continue
  hit=$(grep -naE "$SIG" "$f" 2>/dev/null | head -1 | cut -c1-120 | tr -d '\t')
  if [ -n "$hit" ]; then echo "SIGNATURE: $f : $hit"; fail=1; fi
  if printf '%s\n' "$f" | grep -qE "$STRICT"; then
    hit=$(grep -naE "$DECODER" "$f" 2>/dev/null | head -1 | cut -c1-120 | tr -d '\t')
    if [ -n "$hit" ]; then echo "DECODER: $f : $hit"; fail=1; fi
    max=$(awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$f")
    if [ "$max" -gt 1000 ]; then echo "LONG LINE: $f : $max characters (limit 1000)"; fail=1; fi
  fi
done <<< "$files"

# Known launchers: root api.js with a marker, fake .fml fonts, folder-open tasks that run node.
if [ -f api.js ] && grep -qE "$SIG|$DECODER" api.js; then echo "LOADER: api.js has payload markers"; fail=1; fi
if git ls-files | grep -qE '\.fml$'; then echo "FAKE FONT: a tracked .fml file exists"; fail=1; fi
if [ -f .vscode/tasks.json ] && grep -q folderOpen .vscode/tasks.json && grep -qE 'node ' .vscode/tasks.json; then
  echo "TASK: .vscode/tasks.json runs node when the folder opens"; fail=1
fi
# package.json: scripts that call api.js, or install hooks that run node, a JS file or a shell.
if [ -f package.json ]; then
  if grep -nE 'node +(\./)?api\.js' package.json >/dev/null; then
    echo "HOOK: package.json script runs node api.js"; fail=1
  fi
  if grep -E '"(preinstall|install|postinstall|prepare)"[[:space:]]*:' package.json | grep -qE 'node |curl|wget|bash|sh -c|eval|base64|\.(js|mjs|cjs)'; then
    echo "HOOK: package.json install-time script runs node, a JS file or a shell"; fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "check-payload: FAILED. Do not install or run anything. Read the incident notes."
  exit 1
fi
echo "check-payload: OK"
