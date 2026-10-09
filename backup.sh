#!/usr/bin/env bash
# Обновляет config-backup/ копиями живых файлов из ~/.claude и plugins.json
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HOME/.claude"
DST="$REPO/config-backup"

mkdir -p "$DST/agents"
cp -f "$SRC/settings.json" "$DST/"
cp -f "$SRC/CLAUDE.md" "$DST/"
cp -f "$SRC"/agents/*.md "$DST/agents/"
if [ -d "$SRC/skill-library" ]; then
  mkdir -p "$DST/skill-library"
  cp -rf "$SRC/skill-library/." "$DST/skill-library/"
fi
echo "Backup updated: $DST"

if command -v node >/dev/null 2>&1; then
  node "$REPO/lib/export-plugins.js" "$REPO/plugins.json"
else
  echo "node не найден, plugins.json не обновлён"
fi
