# Museum Liminal — рабочий документ проекта (для агента)

Единая точка входа для следующего агента (Godot 4.7). Сверено с реальным кодом и git
2026-08-02. Читать целиком до первой правки.

> **Правило документа:** здесь пишется только то, что проверено командой или чтением кода.
> Непроверенное помечается явно. Код — источник истины.

Зеркало этого файла ведётся в Notion; при расхождении верить репозиторию.

---

## 1. Что это за проект

Хоррор от первого лица про три ночные смены в ПЕРВОМ МУЗЕЕ — музее аномальной физики.
Игрок работает НАБЛЮДАТЕЛЕМ: находит разрыв, диагностирует его с терминала, подтверждает
по CCTV, приносит нужный прибор со склада и уходит в карманное измерение, чтобы закрыть
аномалию изнутри. Измерений десять. Со второй ночи по музею ходит КУРАТОР. RU + EN.

Порядок величин: ~11 300 строк игрового GDScript + ~1 200 строк тестов, 398 ключей
локализации, 42 сцены, 312 скриптов, 22 GLB, 20 WAV, 5 headless-наборов тестов.

**Проект состоит из двух почти независимых слоёв, и агенты обычно видят только один:**

1. **Геймплейный слой** — ночи, аномалии, приборы, Куратор, 10 карманных измерений, CCTV,
   меню, локализация, аудио. Написан, покрыт тестами, описан в `README.md`, `HANDOFF.md`,
   `RIFT_TRIALS.md`.
2. **Визуально-архитектурный слой** — процедурная генерация здания, материалы, экстерьер,
   освещение. Именно им идёт активная работа, и именно он описан в разделах 4–8.

Правки в визуальном слое почти всегда безопасны для геймплейного, но **обратное неверно**:
правка геометрии может сломать навмеш, проходимость дверей и тесты карты.

---

## 2. Пути и окружение

- Корень: `C:\Users\litvi\OneDrive\Документы\museum-liminal-v-0.9.4`
- Godot: `C:\Users\litvi\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe`
  (4.7.stable, D3D12, RTX 3070)
- Физика Jolt, рендер Forward+, главная сцена `scenes/FirstMuseumMap.tscn`
- Сейвы: `C:\Users\litvi\AppData\Roaming\Godot\app_userdata\Museum liminal\` →
  `museum_progress.cfg` (флаг `story/drive_seen`), `museum_save.cfg`, `museum_settings.cfg`
- Игнорировать при обходе файлов: `.claude/`, `.qoder/`, `.godot/`, `models/` (1.67 ГБ)

---

## 3. Инструменты агента (MCP)

Сервер называется `mcpServer_opencode`. Вызов строго такой:

```js
connections.mcpServer_opencode.runTool({
  toolName: "file_read_text",
  toolArguments: { path: "project.godot" },
})
```

То есть `{toolName, toolArguments}` — **не** `args`. Рабочая папка сервера = корень проекта,
все пути в `file_*` относительные.

Группы инструментов: `file_*` (чтение, запись, правка, поиск, дерево, перемещение, удаление),
`godot_*` (версия, редактор, отладочный вывод, UID), `scene_*`, `project_run` / `project_stop` /
`project_get_info`, `tests_run` / `tests_run_single` / `tests_audit`, `command_run`.

**MCP живёт внутри Godot-редактора и регулярно отваливается** с «Failed to connect to MCP
server». Это норма: подождать и повторить. Если лежит долго — попросить пользователя открыть
Godot.

### Быстрая проверка состояния

| Что | Команда |
|---|---|
| Материалы (14 наборов) | `cmd /c ""<godot>" --headless --path . --script res://game/tools/check_materials.gd" 2>&1 \| findstr /v /c:"registered mcp"` |
| Скриншоты 6 ракурсов (НЕ headless) | `cmd /c ""<godot>" --path . --script res://game/test_shot.gd" 2>&1 \| findstr /v /c:"registered mcp"` |
| Просмотр кадра | `file_read_media {"path": "shots/view/<name>.jpg"}` — только до ~30 КБ |
| Полные тесты | `tests_run` (склонен к таймауту) либо `run_tests.cmd` через `command_run` |
| Локализация | `python tools/check_localization.py` |

---

## 4. Структура проекта

### Сцены

Геометрии карты в репозитории нет. `scenes/FirstMuseumMap.tscn` — 38 строк: корень и девять
пустых узлов-менеджеров. Весь музей строит `FirstMuseumMap.build_map()` в рантайме при каждом
запуске. Правьте геометрию в коде, а не мышью в сцене.

- `scenes/FirstMuseumMap.tscn` — основная карта
- `scenes/TutorialPrologue.tscn` — интерактивный пролог из семи шагов
- `scenes/trials/*.tscn` — 10 сцен-дескрипторов карманных измерений

### Визуально-архитектурный слой (`game/props/`, 17 файлов)

- `MaterialLib.gd` — `@tool class_name MaterialLib`, 14 текстурных наборов, API
  `get_material(pack_name, tint, scale, triplanar)`. Наборы: `travertine, mosaic, quartzite,
  concrete, steel, painted_metal, corroded_metal, window_grime, rust, plastic_dry,
  plastic_worn, dirt, asphalt, wood`
- Экстерьер: `BuildingShell.gd` (оболочка/крыша), `FacadeProps.gd` (портик),
  `ExteriorProps.gd` (деревья, фонари, машины, горы, река), `GroundsProps.gd` (территория
  и парадный двор)
- Вестибюль: `LobbyProps.gd` — стиль одобрен пользователем
- Интерьерные крылья: `AtriumProps`, `OfficeProps`, `ArchiveProps`, `StorageProps`,
  `MassProps`, `TimeProps`, `CorridorProps`, `LightProps`, `PlanetariumProps`,
  `GravityProps`, `SpaceProps`

Итого 16 файлов пропсов + `MaterialLib.gd`. Во всех 16 есть `_pack_for` и врезка
pack-маршрутизации в единую точку материала.

### Геймплейный слой (`game/`)

- `GameManager.gd` (1540 строк) — цикл ночей, состояния, приборы, HUD, экран провала
- `GameplayEnhancements.gd` — эффекты аномалий, CCTV-задачи, синхронизация Куратора
- `CuratorMonster.gd` — Куратор: `CharacterBody3D` со своим `_physics_process`
- `ExhibitPuzzleController.gd` — 12 экспонатов, выбор носителя разрыва, привязка камеры
- `RiftTrialManager.gd` (1070 строк) + `game/trials/` — механики всех десяти измерений
- `SecurityCameraTablet.gd` — планшет на 11 камер и процедурная мини-карта
- `MenuManager.gd`, `SettingsPanel.gd`, `SettingsManager.gd` — меню и настройки
- `PlayerController.gd`, `PlayerScaleController.gd` — движение и масштаб игрока
- `AudioManager.gd` (20 WAV, музыки нет), `CRTOverlay.gd` + `shaders/`, `UITheme.gd`,
  `Compass.gd`, `InventoryBar.gd`, `HideSpot.gd`, `RiftGate.gd`, `MonitorWall.gd`,
  `TerminalFrame.gd`, `Cutscene.gd`
- `Loc.gd` — безопасная замена `tr(KEY) % args`; `InputBootstrap.gd` — действия в рантайме
- `FeedbackManager.gd` + `notion_worker/` — приём отзывов, в сборку не попадает

### Карта: 11 комнат

`Entrance Zone` (0,25) · `Central Atrium` (0,0) · `Watcher Office` (−25,0) ·
`Equipment Storage` (−25,12) · `Archive` (−25,−12) · `Restoration Lab` (−25,22) ·
`Gravity Wing A` (28,0) · `Mass Wing D` (52,0) · `Time Wing B` (0,−24) ·
`Space Wing C` (24,−24) · `Planetarium` (0,−41)

### Тесты — их 13, а не 3

В `run_tests.cmd` и CI входят пять: `test_project_integration`, `test_map_verification`,
`test_incident_catalog`, `test_full_game_cycle`, `test_blocker_regressions`.
Вручную: `test_shell_intrusion` (интрузии оболочки в комнаты), `test_shot` (грузит всю сцену,
ловит parse error), `test_visual_capture`, `test_lobby_capture`, `test_exterior_capture`,
`test_facade_capture`, `test_drive_capture`, `test_full_walkthrough_capture`,
`test_10_runs_audit`.

### Инструменты и ассеты

- `game/tools/check_materials.gd` — эталон «Проверено карт: 59, наборов: 14, ошибок: 0»
- `game/tools/make_wood.gd`, `make_roughness.gd` — генераторы текстур
- `game/AgentShots.gd` + `game/test_shot.gd` + `agent_shots.json` — 6 ракурсов, JPEG до ~31 КБ
- `tools/scan.ps1`, `tools/extract_textures.ps1` — PowerShell только через
  `cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File tools\<name>.ps1"`
- `textures/` — 14 наборов (Poliigon даёт готовый `_Roughness`; ambientCG требует конверсии
  GLOSS→ROUGHNESS; `WoodProcedural/`)
- `models/` — 1.67 ГБ, 22 GLB + FBX + 42 исходных ZIP; кандидат на диету
- `localization/game.csv` (398 ключей, `keys,en,ru`) + скомпилированные
  `game.en.translation` / `game.ru.translation`

> Правка `game.csv` без пересборки `.translation` ни на что не влияет — игра грузит
> скомпилированные файлы, они перечислены в `project.godot`.

---

## 5. Плагины (`addons/`)

| Плагин | Может ли агент использовать | Вердикт |
|---|---|---|
| PlantGenerator | **ДА** — чистый GDScript, кодовый API (`PlantGenerator` RefCounted: axiom/rules/steps; `Plant3D extends MeshInstance3D`). Гонять из `--script`, сохранять меш через `ResourceSaver` в `.tres` | Главный кандидат: реальные деревья вместо цилиндро-сфер |
| SimpleGrassTextured | Частично — `grass.gd` это `@tool MultiMeshInstance3D`, инстанцируется из кода | Опционально: живая трава на газонах |
| Asset Placer | НЕТ — док редактора, нужна мышь | Только для пользователя в GUI |
| MaterialLayers | Практически нет — настраивается в редакторе | Низкий приоритет |
| TerraBrush | НЕТ — GDExtension dll не грузится (ошибка при `--import`) | Не трогать, из git исключён |
| godot_ai | Уже используется — через него подключён MCP | Единственный включённый в `project.godot` |

Для использования Plant3D/SimpleGrass из кода включать плагин не обязательно (preload по пути).

---

## 6. Что уже сделано

1. **Вестибюль, экстерьер, оболочка** — стили одобрены; интрузии устранены
   (`[OK] No shell geometry reaches into any room`)
2. **Территория и парадный двор** — принято пользователем
3. **Инструментарий агента** — AgentShots / test_shot / check_materials / scan
4. **Катсцена приезда возвращена** (сброшен `drive_seen`)
5. **Текстурная база** — 14 наборов, «Проверено карт: 59, наборов: 14, ошибок: 0»
6. **Pack-маршрутизация во всех 16 файлах пропсов + карта.** Сознательно НЕ текстурятся:
   стекло, светящиеся элементы, вода, бумага, экраны, двусторонние поверхности купола
   планетария
7. **Git приведён в порядок** — см. раздел 9

---

## 7. План работ (по приоритету)

1. **Освещение вестибюля и атриума.** По кадрам `lobby_reception.jpg` и `atrium_centre.jpg`
   слишком темно, новые текстуры не читаются. Перебалансировать
   `LobbyProps.build_lobby_lighting :466` и свет атриума.
2. **PlantGenerator → деревья.** Сгенерировать 2–3 вида (дуб, берёза, сосна), экспортировать
   меши в `.tres`, заменить процедурные `build_oak` / `build_birch` / `build_pine`
   в `ExteriorProps.gd`, **сохранив сигнатуры билдеров**.
3. **Двор.** Заменить кустарные 6 фонарей (x ±4.5, z 39.5/45/50.5), 4 дерева
   (±25, z 39.5/50.5) и коробочные машины (z 59) на `ExteriorProps.build_lamp_post`,
   деревья и `build_parked_car`.
4. **`FirstMuseumMap._cylinder` — пробросить `pack`** (колонны, трубы, светильники).
   Подтверждено 2026-08-02: сигнатура на строке 77 —
   `(parent, node_name, cylinder_position, radius, height, color, horizontal,
   emission_energy, with_collision)`, параметра `pack` нет. Вызовов ~30, добавлять
   с параметром по умолчанию.
5. **Кнопка пересмотра катсцены** в `MenuManager._build_main_page()` рядом
   с `MENU_RESET_PROGRESS` (строка 602); сброс `story/drive_seen`; ключи
   в `localization/game.csv` (en+ru) с пересборкой `.translation`; затем
   `python tools/check_localization.py`. Подтверждено 2026-08-02: в `MenuManager.gd` нет ни
   одного упоминания `drive_seen` — не сделано.
6. **Траектория катсцены** — проверить `_drive_track` / `_drive_shots` на пересечение
   с `Court Gate` (z 54.2, x ±4.7) и `Fountain Collision` (0, 0.40, 49.5, r 3.06).
7. **Регрессы** — полный `tests_run`; `test_shell_intrusion.gd` при правках оболочки;
   `check_materials.gd` при правках материалов.
8. **Вес репозитория** — `models/` 1.67 ГБ + `textures/`; кандидаты на удаление или
   даунскейл: `DirtWindowStains005_ALPHAMASKED_2K.png` (16.8 МБ), `_BUMP16` / `_DISP16`,
   отработанные `_GLOSS` / `_REFL` / `_DISP`.

### Долги геймплейного слоя (не из этой очереди, но их спросят)

Подробности в `HANDOFF.md` и `IMPROVEMENT_PLAN.md`: нет ни одного музыкального трека;
нет системы субтитров; готовой сборки не существует (`--export-release` не выполнялся ни
разу); нет мид-сейва; Куратор бинарен (замер / бег по прямой); ночь не встаёт на паузу внутри
карманного измерения; автозагрузка `_mcp_game_helper` указывает на `addons/godot_ai`, который
вырезан из экспорта — первый же экспорт может упасть на старте.

---

## 8. Технические правила и ловушки

- `tests_run` без аргументов склонен к таймауту MCP. Быстрая проверка правок:
  `check_materials.gd` + прогон `test_shot.gd`
- `file_read_media` принимает только `{"path"}`, файлы до ~30 КБ; PNG таймаутят
- `command_run` — это **cmd, не PowerShell**. PowerShell только через `.ps1` файл:
  `cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File tools\<name>.ps1"`.
  Однострочники через `-Command` с запятыми и скобками ломаются на экранировании —
  проверено, не тратьте на это попытки
- Capture нельзя запускать с `--headless`
- `--import` ругается на terrabrush dll — норма, игнорировать
- `class_name` в голом `--script` НЕ регистрируется → всюду `preload`
- Pack игнорируется при `transparent` или `emission > 0` — сознательно
- `BoxMesh` разворачивает UV 0..1 на грань → обязателен трипланар с `uv1_scale` от мировых
  координат
- ambientCG отдаёт GLOSS → конвертер `make_roughness.gd`; Poliigon даёт готовый `_Roughness`
- `Label3D` не билбордить; `Object.tr()` недоступен из static →
  `TranslationServer.translate(key)`
- Тени off при `size.length() < 0.65`; компланарные плиты дают z-fighting — смещать
  на миллиметры
- `file_write` НЕ создаёт каталоги → сначала `file_create_directory`
- Навигация настроена впритык: `agent_radius` 0.45 и `cell_size` 0.15 дают ровно 0.9 м
  навмеша в дверном проёме. При 0.5 / 0.2 останется 0.6 м и Куратор начнёт застревать.
  **Не менять эти числа и не сужать дверные проёмы**

---

## 9. Git и GitHub

Репозиторий: <https://github.com/sergltvn-rgb/museum-liminal-v-0.9.4>

**Рабочая ветка — `wip/audit-2026-07-26`.** Она опережает `main` на 69 коммитов и не отстаёт
ни на один: вся актуальная работа живёт в ней, а `main` — старое состояние.

Что было не так и исправлено 2026-08-02: весь визуальный слой (14 текстурных наборов,
`MaterialLib`, `BuildingShell`, `ExteriorProps`, `FacadeProps`, `GroundsProps`, `LobbyProps`,
инструменты агента, capture-тесты) лежал вне git как untracked, а рядом копились мусорные
артефакты — скриншоты прогонов, временные скрипты, каталог `.qoder/`, неработающий terrabrush.

Правила:

- Коммитить в `wip/audit-2026-07-26`, в `main` напрямую не писать
- Скриншоты (`shots/`, `*_captures/`) и временные скрипты (`tools/tmp_*`) в git не попадают —
  они в `.gitignore`. Это рабочие артефакты, а не исходники
- Перед коммитом прогонять `check_materials.gd`, а при правках геометрии — ещё
  и `test_shell_intrusion.gd`
- Секреты живут только в `.env`, который в `.gitignore`. Никогда не вписывать ключи
  в исходники

---

## 10. Правила приёмки

- Отчитываться по каждому этапу отдельно, со скриншотами: `test_shot.gd` →
  `shots/view/*.jpg` → `file_read_media`
- Ничего не считать готовым без визуального подтверждения пользователем
- Модели качественные, переиспользование разрешено, процедурные текстуры равноправны
  с фото из `models/`

---

## 11. Ключевые сигнатуры

```gdscript
MaterialLib.get_material(pack_name, tint := Color.WHITE, scale := 0.0, triplanar := true) -> StandardMaterial3D
```

Приём pack-маршрутизации — шаблон во всех файлах пропсов:

```gdscript
const MatLib := preload("res://game/props/MaterialLib.gd")

static func _pack_for(color: Color) -> String:
    if color.is_equal_approx(STEEL): return "steel"
    return ""

# в точке материала, сразу после проверки кэша:
if not transparent and emission <= 0.0:
    var pack := _pack_for(color)
    if not pack.is_empty():
        var photo := MatLib.get_material(pack, color)
        _materials[key] = photo
        return photo
```

Якоря `_material`: `AtriumProps :853` · `OfficeProps :277` · `ArchiveProps :282` ·
`StorageProps :713` · `MassProps :885` · `TimeProps :618` · `CorridorProps :697` ·
`LightProps :824` · `PlanetariumProps :577` (кэш `_mats`) · `GravityProps._mat :~922` ·
`SpaceProps._mat :~110`

Прочее:

- `MapModels.place(parent, name, world_position, scale_factor, rotation_y_deg, pitch_x_deg)`
- Спавн игрока: (0, 0.05, 46), камера y 1.65, fov 72
- Навигация: `agent_radius` 0.45, `cell_size` 0.15

---

## 12. Куда смотреть дальше

| Файл | О чём |
|---|---|
| `README.md` | геймплей целиком: цикл ночей, приборы, измерения, управление, сборка |
| `HANDOFF.md` | честное состояние работ и известные расхождения |
| `IMPROVEMENT_PLAN.md` | дорожная карта геймплея |
| `RIFT_TRIALS.md` | механики десяти карманных измерений |
| `MODELS_GUIDE.md` | слоты моделей и правила коллизий |
| `CHANGELOG.md` | история версий |
| `game/AGENT_TOOLS.md` | инструментарий агента подробно |
