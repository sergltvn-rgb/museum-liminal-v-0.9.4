# Промпт для следующего чата

Скопировать целиком в новый чат:

---

Ты продолжаешь работу над Godot-проектом museum-liminal. Корень: `C:\Users\litvi\OneDrive\Документы\museum-liminal-v-0.9.4`, Godot 4.7 (`C:\Users\litvi\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe`). Работай через MCP-сервер opencode (command_run, file_read_text, file_read_media, file_write, file_edit, tests_run, tests_run_single). Общий поиск не использовать.

Первым делом прочитай: `DECOR_AUDIT_SUMMARY.md`, `AGENT_PLAN.md`, `decor_shots.json`, `game/test_decor_capture.gd`.

## ГЛАВНОЕ ПРАВИЛО — ЖЁСТКОСТЬ ПРОВЕРКИ

Предыдущая проверка была СЛИШКОМ МЯГКОЙ. Будь максимально придирчивым:

- Любой объект не на своём месте = СРАЗУ переделка (source fix → recapture → визуальная проверка). Пример от пользователя: модель монитора стоит не там, где должна, — это переделка, а не заметка. Никаких «необычно, но валидно».
- Дефекты, требующие правки: криво стоит, висит в воздухе, уходит в стену/пол/потолок, не тот размер/масштаб, развёрнут не той стороной, плавает над поверхностью, пересекается с соседями, z-fighting, дырки, backface/inverted normals, не читается назначение объекта.
- Сверяй положение каждого пропа со смыслом сцены: монитор на столе экраном к рабочему месту, часы ровно на стене, вывеска по центру проёма, скамья ногами на полу, автомобиль на разметке, инструмент на подносе и т.д.
- Структурный тест PASS НЕ считается доказательством. Доказательство — только реально открытое изображение. MCP file_read_media часто обрезает output: тогда декодируй полный JSON из `/data/tool-results/...json` в локальный файл и открой его.
- Обзорный contact sheet — только первый фильтр. Решения по геометрии и положению принимай по native-кадрам (640×268) и tile mosaics без ресайза.

## ЗАДАЧИ (по приоритету)

1. Завершить прерванный native-detail аудит: реально открыть 8 листов `shots/decor_audit/after/final_detail_review/final_detail_review_1..8.jpg` и 3 lab mosaics (`lab_exhibit_sheet_tiles.jpg`, `lab_covered_west_tiles.jpg`, `lab_covered_east_tiles.jpg`). По lab проверить: continuity shell, normals/backface, дырки, z-fighting, волнистый подол, складки, отсутствие отдельной «головы»/шара, bottle/mannequin silhouette, коробочных панелей.
2. Пройти заново ВСЕ 132 ракурса из `decor_shots.json` строго на ПРАВИЛЬНОСТЬ ПОЛОЖЕНИЯ объектов (не только геометрию). Особое внимание: office (мониторы и вся техника!), imports, service_lights, exterior, lab. Всё, что стоит не на месте, — переделка.
3. Каждый подтверждённый дефект: правка в `game/props/*.gd` или `game/FirstMuseumMap.gd` → focused capture (override `DECOR_CONFIG`) → реальное открытие кадра → только потом отметка «исправлено».
4. Создать `shots/decor_audit/audit.tsv`: ровно 132 строки, колонки `name`, `status`, `issue`, `game_or_capture`, `planned_fix`, `after_status`. Включая валидные и camera-only случаи.
5. При необходимости расширить `game/test_decor_layout.gd`: banners NE/EN/ES, symmetric Exit/Emergency checks, doorway/jamb clearance.
6. Прогнать: `run_tests.cmd` (в нём новые `test_decor_quality.gd` и `test_decor_layout.gd`), `check_materials.gd`, `check_localization.py`, `git diff --check`.
7. Обновить `AGENT_PLAN.md`: итоги аудита, актуальный mesh count, актуальные значения ночной яркости, статус decor-тестов и экспорта.
8. Сделать НОВЫЙ Windows export и smoke-test именно нового `build/windows/MuseumLiminal.exe` (текущий устарел).
9. Не коммитить без явного разрешения пользователя.

## Как снимать

```
"C:\Users\litvi\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe" --path . --script res://game/test_decor_capture.gd
```
Без `--headless`. Config: `decor_shots.json` (132 canonical ракурсов, out `res://shots/decor_audit/after`, tiles=2, settle=40, frames=6). Формат кадра: `<dir>/<name>.png`, `view/<name>.jpg` (640×268), `tiles/<name>_rNcN.jpg`.

## Ключевые файлы

- `game/props/ArchiveProps.gd` — `_fabric_shell`, `build_rolling_stacks`, `build_shrouded_exhibit`, `build_shrouded_lump`.
- `game/FirstMuseumMap.gd:2710–2719` — Wing Banners (актуальные позиции ±1.7).
- `game/test_decor_quality.gd`, `game/test_decor_layout.gd` — decor-тесты (в runner и CI уже добавлены).
- `DECOR_AUDIT_SUMMARY.md` — полный статус предыдущего этапа и известные отложенные проблемы (leaks, карниз ~850 зубцов, Palette, TreeLib).

## Временные файлы (кандидаты на удаление после завершения — спросить пользователя)

`game/test_wall_probe.gd`, `run_decor_probes.cmd`, `run_decor_probes.ps1`, `run_decor_focus_round2.ps1`, `run_decor_focus_round3.ps1`, `run_decor_focus_round4.ps1`, `run_decor_final.ps1`, `decor_camera_probes.json`, `decor_focus_round2.json`, `decor_focus_round3.json`, `decor_focus_round4.json`, `tools/make_decor_probe_sheets.py`, `tools/make_focus_round2_sheets.py`, `tools/make_focus_round3_sheets.py`, `tools/make_focus_round3_detail_sheets.py`, `tools/make_focus_round4_detail_sheets.py`, `tools/make_remaining_after_detail_sheets.py`, `tools/make_final_contact_review.py`, `tools/make_final_decor_detail_review.py`.

---
