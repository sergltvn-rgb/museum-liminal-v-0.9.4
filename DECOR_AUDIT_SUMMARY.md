# Декор-аудит 2026-07-26 → 2026-08-05: что сделано и что НЕ закончено

> Честный статус перед handoff. Обзорная проверка пройдена, детальная — нет.
> Оценка пользователя: проверка была слишком мягкой; см. NEXT_CHAT_PROMPT.md.

## Сделано

### Инструментарий аудита
- `game/test_decor_inventory.gd` — инвентаризация `GeneratedMap`: `shots/decor_audit/inventory.tsv`, 416 кандидатов, 9812 мешей.
- `game/test_decor_capture.gd` + `decor_shots.json` — harness съёмки: 132 ракурса, tiles=2, settle=40, frames=6, авто FOV 54, поддержка `DECOR_CONFIG`.
- Python-утилиты в `tools/` (contact sheets, emitters, detail-review генераторы). Часть — временные, список на удаление в NEXT_CHAT_PROMPT.md.

### Игровые правки
1. **Archive Rolling Stacks** (`game/props/ArchiveProps.gd`) — были почти чёрными монолитными кубоидами → добавлены `_STACK_FACE/_STACK_TRIM/_STACK_LABEL`, рамы, швы, карточки, маховики, механика. Подтверждено native tile mosaics.
2. **Exhibit 9 Under Sheet + оба Lab Covered Object** (`ArchiveProps.gd`) — были белыми коробками со скошенной крышкой → `ArrayMesh`-ткань `_fabric_shell` (SurfaceTool, 16 сегментов, закрытый верх, волнистый подол, directional lobe, `_marker` вместо отдельного шара-«кроны»). 4 итерации; Exhibit v4 принят по four-view native review, Covered Objects v3 приняты.
3. **Wing Banner NW/NE/EN/ES** (`game/FirstMuseumMap.gd:2710–2719`) — перенесены с ±3.2 на ±1.7: перекрывали Exit Sign и Emergency Luminaire. Подтверждено `game/test_decor_layout.gd` + визуально.

### Тесты
- `game/test_decor_quality.gd` — структурные проверки ткани/стеллажей (red → green, 16 → 0 failures).
- `game/test_decor_layout.gd` — окклюзия banner/exit/emergency (red → green, 2 → 0).
- Оба добавлены в `run_tests.cmd` и `.github/workflows/windows-release.yml` после Map verification.
- ⚠️ Полный `run_tests.cmd` после правок runner/CI НЕ прогонялся.

### Камеры
- 11 ракурсов в `decor_shots.json` переведены на canonical-координаты (lab_exhibit_sheet, lab_tool_tray, lab_covered_west/east, import_flashlight, import_vents, import_wall_clock, service_exit_sign, service_hose_reel, light_emergency, exterior_player_car).
- `player_car_medium` — canonical для машины игрока.

### Финальная съёмка
- 132 PNG / 132 views / 528 tiles, manifest 133 строки, stdout `[DECOR CAPTURE] done: 132 shots`, stderr пуст. PID 30112 завершён.
- 15 contact sheets пересобраны (`thumbnail`, аспект сохранён) и реально просмотрены: HUD нет, чёрных/пустых кадров нет, стеллажи читаются как стеллажи, ткань не выглядит коробками на обзорном масштабе, exit/emergency не перекрыты, parking/car/exterior в кадре.

## НЕ закончено

1. **Native-detail аудит 30 рискованных ракурсов НЕ завершён.** Созданы `shots/decor_audit/after/final_detail_review/final_detail_review_1..8.jpg` + 3 lab mosaics (`lab_exhibit_sheet_tiles.jpg`, `lab_covered_west_tiles.jpg`, `lab_covered_east_tiles.jpg`), но реально открыты и проверены НЕ были (первые 4 прочитаны через MCP, outputs обрезаны, не декодированы/не открыты).
2. **Проверка положения объектов была слишком мягкой.** Пример от пользователя: модель монитора стоит не на месте — такое = сразу переделка, без «необычно, но валидно». Требуется повторный строгий проход по всем 132 ракурсам именно на ПРАВИЛЬНОСТЬ ПОЛОЖЕНИЯ (см. NEXT_CHAT_PROMPT.md).
3. `shots/decor_audit/audit.tsv` (ровно 132 строки: name, status, issue, game_or_capture, planned_fix, after_status) не создан.
4. Windows export не делался — `build/windows/MuseumLiminal.exe` устарел относительно исходников.
5. Smoke-test нового exe не делался.
6. Удаление временных probe-скриптов не решено (список в NEXT_CHAT_PROMPT.md).
7. `AGENT_PLAN.md` не обновлён итогами аудита (mesh count, ночная яркость устарели).

## Известные отложенные проблемы
- `WARNING: ObjectDB instances were leaked at exit` + `resources still in use at exit` (23/8, 14/3, 4/2 в разных прогонах).
- ~850 зубцов карниза ≈14% геометрии здания — вероятный geometry tail, точка правки `BuildingShell._build_face`.
- `game/props/Palette.gd` создан, но ~352 литерала `Color(` ещё не переведены на палитру.
- `TreeLib.build_field` написан, но не используется.

## Прогоны тестов (до decor-правок runner/CI)
- Импорт проекта — pass; `test_project_integration.gd`, `test_incident_catalog.gd`, `test_full_game_cycle.gd`, `test_blocker_regressions.gd` — 0 failures; `test_map_verification.gd` — ALL CHECKS PASSED.
- Материалы: 59 карт / 14 наборов / 0 ошибок. Оболочка: 4229 мешей, проникновений в комнаты нет. Локализация 513/513 RU+EN.
- UI capture: 3 окна без выхода за границы. Night capture: office 0.0360, atrium 0.0341, lobby 0.1725, corridor 0.0313.

## Как снимать
```
"C:\Users\litvi\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe" --path . --script res://game/test_decor_capture.gd
```
Без `--headless` (нет framebuffer). Формат: `<dir>/<name>.png`, `view/<name>.jpg` (640×268), `tiles/<name>_rNcN.jpg`.
