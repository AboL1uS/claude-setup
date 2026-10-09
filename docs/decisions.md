# Журнал решений

## 2026-10-09 — первичная настройка

### Режим и модель
- `defaultMode: plan` — каждый чат начинается с плана.
- Основной чат: Opus, effort medium (был xhigh). Opus — «дирижёр»: планирует и решает, рутину отдаёт сабагентам.

### Сабагенты (`~/.claude/agents/`)
- `implementer` (Sonnet, medium) — понятные шаги утверждённого плана.
- `quick-helper` (Haiku, low) — тесты/сборка с пересказом, мелкие правки.
- `build-fixer` (Sonnet, medium) — починка сборки/тестов минимальными правками.
- Описания без «MUST BE USED», чтобы не вызывались на каждый чих.

### Плагины
Включены постоянно (без хуков, почти бесплатны):
- `claude-code-setup` — анализ проекта и рекомендации автоматизаций.
- `context7` — актуальная документация библиотек (меньше переделок).
- `session-report` — отчёт, куда ушли токены.
- `claude-md-management` — ведение CLAUDE.md проектов, `/revise-claude-md`.

Установлены, но выключены (включать `claude plugin enable <имя> --scope project`):
- `impeccable@impeccable` — фронтенд-дизайн, `/impeccable animate|polish|audit|critique…`. Во включённом виде хуки проверяют UI после правок.
- `playwright` — браузер для проверки сайтов.
- `typescript-lsp`, `pyright-lsp` — навигация по коду; нужны `npm i -g typescript-language-server typescript` / `npm i -g pyright`.
- `security-guidance` — 4 хука, ревью безопасности каждого ответа → дорого; только для проектов с логином/оплатой.
- `commit-commands` — `/commit`, `/commit-push-pr`.
- `figma@synced`, `brightdata-plugin@synced` (~5.3k токенов в каждом чате), `desktop-commander@synced` (MCP не подключался) — синхронизированы с claude.ai, выключены локально.

Библиотека `~/.claude/skill-library/`:
- `design-taste-frontend` (Taste Skill, Leonxlnx) — только основной вариант из 13. ~22k токенов при вызове; для лендингов/портфолио. Подключение — копированием в `<проект>/.claude/skills/`.

### Отвергнуто
- **Everything Claude Code** (worldflowai / affaan-m) целиком: хук блокирует dev-серверы вне tmux (на Windows ломает `npm run dev`); агенты на Opus с «MUST BE USED for all code changes» (дорого); TDD 80% навязано; многое уже встроено. Взята только идея агента для ошибок сборки.
- `superpowers`, `feature-dev` — тяжёлые сценарии, конфликтуют со схемой «дирижёр + сабагенты».
- `ralph-loop` — крутит задачу по кругу, сжигает токены.
- `remember` — дублирует встроенную память.
- `frontend-design` — пересекается с Impeccable/Taste.
- `pr-review-toolkit`, плагин `code-review` — хватает встроенного `/code-review`.

### Отложено
- Агент `test-writer` (Sonnet) — добавить, когда в проектах появятся тесты.

### Наблюдения из `/context`
- MCP-инструменты с пометкой «deferred» (Figma, Google Drive и т.п. из коннекторов claude.ai) в итоговый расход не входят — грузятся только по запросу.
- Скиллы плагина `design:*` приходят не из локальных плагинов (их нет в `claude plugin list`) — вероятно, из claude.ai; при желании отключать там.

## 2026-10-09 — режим плана в VS Code
- В расширении VS Code новые чаты открывались в режиме Auto, несмотря на `defaultMode: plan` в `~/.claude/settings.json`.
- Исправлено настройкой расширения `"claudeCode.initialPermissionMode": "plan"` в `%APPDATA%\Code\User\settings.json`.
- На предложение «Make auto mode your default» отвечать «No, keep plan mode».

## 2026-10-09 — сторонние рекомендации
- Тест в новом проекте прошёл как задумано (режим плана, рекомендации, агенты).
- В `~/.claude/CLAUDE.md` (пункт «Скиллы и плагины») разрешено предлагать стороннее (GitHub, другие маркетплейсы), если в установленном и `claude-plugins-official` нет подходящего и задача заметно выиграет. Пометка «стороннее», источник/популярность, состав (хуки, MCP, скрипты), стоимость контекста; файлы проверять перед установкой.
- Правило «одобрение плана = разрешение» не добавлено — оставлено как есть.

## 2026-10-09 — выбор подключаемого после одобрения плана
- В `~/.claude/CLAUDE.md`: после одобрения плана Claude задаёт вопрос с множественным выбором по пунктам «Рекомендуемой настройки», подключает только выбранное, затем говорит, какие команды ввести мне (`/reload-plugins`, `/model`, `/mcp`). Если подключать нечего — вопрос не задаётся.

## 2026-10-09 — синхронизация между устройствами
- Настройка хранится в приватном репозитории GitHub `claude-setup`. Устройства: этот ноутбук (Windows), второй (Windows), третий (Windows + Linux).
- `install.ps1` / `install.sh`: копируют CLAUDE.md, агентов, skill-library; **сливают** settings.json (локальные ключи вроде темы сохраняются); ставят и включают/выключают плагины по `plugins.json`; прописывают режим плана в VS Code. Повторный запуск безопасен.
- `backup.ps1` / `backup.sh` дополнительно обновляют `plugins.json` из `claude plugin list --json`. Synced-плагины в этом списке не видны — их записи в `disabledSynced` сохраняются.
- `chat-archive/*.jsonl` не отправляется в GitHub (личное, большое).
- `.ps1` файлы сохранены в UTF-8 с BOM — иначе PowerShell 5.1 ломает русский текст.
