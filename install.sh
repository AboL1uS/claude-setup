#!/usr/bin/env bash
# Установка настройки Claude Code на Linux. Повторный запуск = обновление.
# Флаг --dry-run: только показать действия.
set -u

DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    *) echo "Неизвестный флаг: $a (доступен --dry-run)"; exit 2 ;;
  esac
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CFG="$REPO/config-backup"
FAILS=()

run() {
  if [ "$DRY" = 1 ]; then
    echo "[dry-run] $*"
    return 0
  fi
  "$@"
}

step() { echo; echo "== $* =="; }

step "Проверка программ"
if ! command -v claude >/dev/null 2>&1; then
  echo "Claude Code не найден в PATH. Установи его: https://code.claude.com/docs"
  echo "После установки запусти этот скрипт снова."
  exit 1
fi
echo "claude: найден"
HAVE_NODE=1
if ! command -v node >/dev/null 2>&1; then
  HAVE_NODE=0
  echo "ВНИМАНИЕ: node не найден. Слияние настроек и список плагинов недоступны."
fi

step "Резервная копия текущих файлов"
STAMP="$(date +%Y%m%d-%H%M%S)"
BK="$CLAUDE_DIR/backup-$STAMP"
for f in settings.json CLAUDE.md; do
  if [ -f "$CLAUDE_DIR/$f" ]; then
    run mkdir -p "$BK"
    run cp -f "$CLAUDE_DIR/$f" "$BK/$f"
    echo "Копия $f -> $BK"
  fi
done

step "Копирование файлов"
run mkdir -p "$CLAUDE_DIR/agents" "$CLAUDE_DIR/skill-library"
run cp -f "$CFG/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
for f in "$CFG"/agents/*.md; do
  run cp -f "$f" "$CLAUDE_DIR/agents/"
done
if [ -d "$CFG/skill-library" ]; then
  run cp -rf "$CFG/skill-library/." "$CLAUDE_DIR/skill-library/"
fi

step "Настройки (settings.json)"
if [ "$HAVE_NODE" = 1 ]; then
  run node "$REPO/lib/merge-settings.js" "$CFG/settings.json" "$CLAUDE_DIR/settings.json"
elif [ ! -f "$CLAUDE_DIR/settings.json" ]; then
  run cp -f "$CFG/settings.json" "$CLAUDE_DIR/settings.json"
else
  echo "node нет, а settings.json уже существует. Объедини вручную с $CFG/settings.json"
fi

step "Плагины"
if [ "$HAVE_NODE" = 1 ]; then
  list() {
    node -e "const p=require(process.argv[1]);console.log((p[process.argv[2]]||[]).join('\n'))" "$REPO/plugins.json" "$1"
  }
  # Запускает claude, не прерывая скрипт при ошибке
  try() {
    local label="$1"; shift
    if [ "$DRY" = 1 ]; then echo "[dry-run] claude $*"; return 0; fi
    local out
    if ! out="$(claude "$@" 2>&1)"; then
      case "$out" in
        *already*) echo "  уже есть: $label" ;;
        *) echo "  ОШИБКА: $label"; FAILS+=("$label: $out") ;;
      esac
    else
      echo "  ok: $label"
    fi
  }
  while IFS= read -r m; do
    [ -n "$m" ] && try "marketplace $m" plugin marketplace add "$m"
  done < <(list marketplaces)
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    try "install $p" plugin install "$p"
    try "enable $p" plugin enable "$p" --scope user
  done < <(list enabled)
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    try "install $p" plugin install "$p"
    try "disable $p" plugin disable "$p" --scope user
  done < <(list disabled)
  while IFS= read -r p; do
    [ -n "$p" ] && try "disable $p" plugin disable "$p" --scope user
  done < <(list disabledSynced)
else
  echo "Пропускаю плагины: нужен node для чтения plugins.json."
fi

step "Настройки VS Code"
VSC="$HOME/.config/Code/User/settings.json"
if [ -f "$VSC" ]; then
  if [ "$HAVE_NODE" = 1 ]; then
    if [ "$DRY" = 1 ]; then echo "[dry-run] node lib/merge-vscode.js $VSC"; else node "$REPO/lib/merge-vscode.js" "$VSC"; fi
  fi
else
  echo "Настройки VS Code не найдены ($VSC). Если пользуешься расширением, добавь: \"claudeCode.initialPermissionMode\": \"plan\""
fi

step "Итог"
if [ "$DRY" = 1 ]; then
  echo "[dry-run] claude plugin list"
else
  claude plugin list
fi
if [ "${#FAILS[@]}" -gt 0 ]; then
  echo
  echo "Не удалось выполнить:"
  for f in "${FAILS[@]}"; do echo " - $f"; done
fi
echo
echo "Сделай вручную:"
echo " 1. Открой новый чат в Claude Code."
echo " 2. Выполни /mcp и авторизуй context7."
echo " 3. Проверь, что чат открылся в режиме Plan и с моделью Opus."
