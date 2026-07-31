# Audio Handoff — состояние звука

Дата: 2026-07-31. Ветка: `wip/audit-2026-07-26`.
Документ для следующей сессии: что сделано по звуку, что открыто и как с этим проектом работать, не повторяя ошибок.

---

## 1. Что сделано (на момент записи test_project_integration и test_full_game_cycle — зелёные)

### §26.1 Музыкальные слои
- `music_tension.mp3` обрезан до 149.000 с контента. Godot читает его как **148.992 с** против 149.000 у `music_bed_night.mp3` — расхождение 0.008 с при пороге 0.05, warning `music layers differ in length` устранён.
- **Важно про движок**: Godot меряет MP3 по сырым кадрам (gapless/LAME-тег не читает). Bed = 6208⅓ кадра при 48000 Гц, поэтому «ровно 149.000» недостижимо — ближайшие варианты 148.992 / 149.016 / 149.040.
- Оригинал: `%TEMP%\museum_audio_backup\music_tension.mp3.bak`.
- По «8 compiler warnings»: sweep `--check-only` всех 51 скриптов `game/` — чисто; в игровом коде была ровно одна warning (про длины слоёв), она и закрыта.

### §26.2 Четыре файла из «новые звуки»
- **дыхание в шкафу.mp3** → луп, пока игрок в шкафу: `AudioManager.set_hide_breath()` (+4 dB); старт/стоп в `GameManager._enter_hiding/_leave_hiding/_fail/_resolve`. Позже содержимое заменено на мужское slow breathe (см. вторую партию).
- **свет выключается.mp3** → blackout-ивент в `FirstMuseumMap._trigger_blackout()` через `AudioManager.play_path()` (заменила пару blackout+power_down на этом месте).
- **звук ламп бекрумс.mp3** → `звук ламп луп.mp3` (бесшовный луп 24 с) → гул на трёх `LightProps.failing_tube()` (группа `lamp_hum`, глохнет с blackout через `call_group("lamp_hum","stop")`). Позже содержимое заменено на transformer_hum (см. вторую партию).
- **curator_catch2.mp3** → `CATCH_SOUND` в `CuratorMonster.gd`, `CATCH_VOLUME_DB = -11.0` (файл на 7.4 дБ горячее старого, пик 0.0 dBFS).

### §26.3/26.4 Первая партия замен из библиотеки Sonniss
- ui_beep → `tablet_click` ×1.00 / `tablet_open` ×0.85 / `menu_move` ×0.92 / `menu_select` ×1.08 (вариспид, уровни 1:1 со старыми).
- wood_drop → `pickup` ×1.15 / `drop` ×1.0 / `land` ×0.82.
- haunted_boom_02 → `fail` (6.6 с, долгий спад); powerup_resolve → `resolve` (3.3 с).
- drone_geofon17 → `anomaly_hum` (бесшовный луп 14 с, −12.9 RMS как старый).
- hinge_creaks → `locker_creak.wav` (1.4 с): `HideSpot.set_closed()` — открытие Куратором полная громкость, закрытие игроком −8 dB / питч 0.8.
- `alien_texture.wav` — акцент аномалии при входе в шкаф (−12 dB, `GameManager._enter_hiding`).
- Тяжёлые шаги Куратору НЕ делались: при 4.9–6.3 м/с медленные шаги не ложатся.

### Вторая партия (опрос пользователя)
- `ambience_night` = basement_boilerroom (луп 45 с, **−16.5 RMS**; старый был −13.5 — если гул покажется тихим, +3 дБ).
- `ambience_day` = quiet_livingroom (луп 45 с, −29.7 RMS 1:1).
- `terminal_beep` = морзянка morse_1 (1.125 с).
- `door_lock` = cell_door_lock (чистый от клиппинга, **но ~на 10 дБ тише старого** — транзиентная запись, RMS не разогнать без лимитера; если тихо — поднять с лимитером ~+5 дБ).
- `power_down`, `blackout` = нарезки из «свет выключается.mp3» (свисание 2.5–6.0 с и удар 0–2.5 с).
- `exhausted_breath` = pant_loop_tanja (луп 10.4 с): пантинг при пустой стамине — `PlayerController._set_panting()` на флаге `_exhausted`, стоп при восстановлении 25 % и в `_fail/_resolve`.
- `monitor_static` = interference_cable (луп 10 с, −28 RMS): гул мониторной стены, `MonitorWall._ready`, группа `lamp_hum`.
- `seismic_hum` = seismic_cabinet (луп 12 с, −24 RMS): второй слой в `set_anomaly_hum()`, на 4 дБ под геофонным дроном.
- `music_spill` = music_spill_026 (луп 30 с, −30 RMS): музыка-интерком над атриумом в `FirstMuseumMap`, группа `lamp_hum`.
- Разлом: `rift_open` = DSGN VORTEX IN (в `RiftGate.build()`), `rift_cross` = WHOOSH PASS SF LOW (в `RiftGate._on_body_entered()`), `rift_return` = тот же whoosh ×0.75 тише (в `RiftTrialManager._cleanup()` — единая точка для clear/abort/fall).
- `дыхание в шкафу.mp3` заменено на breathe_slow_owen (луп 12 с, калибровка −33.4 RMS сохранена).

### Третья партия (папка 20 «шаги и сирена», 2026-07-31)
- **6of9 оказался не тем**: файл `Sonniss.com-GDC2024-GameAudioBundle6of9.zip` содержит контент Part 8 (Rescopic / Rogue Waves / Sonic Bat / Pole Position). «(Part 8) Filelist.xlsx» лежит во ВСЕХ частях — это сводная опись всего бандла, не манифест части. Шагов по бетону (Ultimate Footstep Collection, STEPS Dirt & Gravel, PM_SDNG, S23_SFX) и alarm-лупов из описи (gizmo_alarm_loop_001, BC0242 alarm_002, BC0243 cockpit_alarm_006) нет НИ В ОДНОМ из 9 зипов — это отдельные позиции на странице GDC, они не скачаны. Замены взяты из папки пользователя `sound_candidates\20 шаги и сирена\`.
- `alarm.wav` = «тревога что нужно но потише сделай.mp3» → бесшовный луп 9.06 с (экспоненциальный фолд 1 с), уровень натуральный **−19.1 RMS / −3.8 peak** — на ~4 дБ тише старого синта (−15.3), как просили. `_alarm.volume_db = -9.0` без изменений.
- `footstep1..3` = нарезки из freesound 073303 footsteps-on-stone (3 × 0.30 с, фейды 5/60 мс), RMS 1:1 со старыми (−35.7/−42.0/−40.0), пики −13.5/−18.0/−15.5.
- `door_lock` = +5 дБ через envelope-лимитер (−1.0 dBFS): −28.3 → **−26.3 RMS**, пик −1.0. Транзиент съедает почти весь подъём; если ещё тихо — крутить `play_at` в FirstMuseumMap (сейчас −2.0 dB), а не файл.
- `ambience_night` = +3 дБ через тот же лимитер: ровно **−13.5 RMS**, пик −1.0 — обратно на референс.
- Бэкап шести оригиналов: `%TEMP%\museum_audio_backup\audio_wav3\`. Обработка: `tools/tmp_batch6.py` (идемпотентен: door_lock/ambience_night читает из бэкапа). Пересборка кешей: `tools/tmp_reimport.gd` (универсальный, список в NAMES, dest читает из `.import`, пишет `.sample`+`.md5`, самопроверка длин через remap).
- Не задействовано из папки 20: dragon-studio-colossal-footsteps (Куратору по-прежнему не ложится из-за темпа 4.9–6.3 м/с) и soundreality-radioactive-zone-525013 (48 с эмбиент, −20.1 RMS — запас на будущее).

---

## 2. Открыто
- Ничего критичного. Мелочь: door_lock всё ещё на ~7 дБ тише самого старого синта (упирается в транзиент, см. выше); если alarm захочется другого характера — в `sound_candidates\19_alarm\` лежат 4 кандидата из бандла (bc0304_alarm_005, bc0303_alert_003, beechcraft stall warning, uialert_confirm_12) с замерами.
- Тяжёлые шаги Куратору не делались (темп 4.9–6.3 м/с).

## 3. Ресурсы
- Кандидаты на прослушку: `C:\Users\litvi\sound_candidates\` (папки 01–18: шаги Куратора, скрип шкафа, UI, дроны, замки, стингеры, гул ламп, тоны, бипы, alarm, разлом, дыхание, статика, door_lock, power_down, экстра; **19_alarm** — alarm-кандидаты из бандла; **20 шаги и сирена** — папка пользователя, источник третьей партии).
- Бэкапы оригиналов: `%TEMP%\museum_audio_backup\` (audio_wav, audio_wav2, **audio_wav3**, mp3, music_tension.mp3.bak).
- pip на машине уже стоит: `miniaudio`, `lameenc`, `numpy`.
- Сканер зипов без распаковки: `tools/tmp_extract6.py` (python zipfile, central directory).

## 4. Как работать с этим проектом (важно)
- Доступ: OpenCode MCP (`command_run`, `file_*`, `godot_*`, `tests_run_single`). Мост иногда падает — лечится перезапуском `start-mcp.cmd`. Не гонять тяжёлые base64-чтения файлов через MCP — от них он и лагает.
- Godot: `%USERPROFILE%\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe`, headless. Редактор для импорта открывать НЕ нужно: замена аудио = перезапись файла + пересборка кеша `.godot/imported/<имя>-<md5(res://путь)>.sample` (wav) / `.mp3str` (mp3) headless-скриптом `extends SceneTree` (AudioStreamWAV/MP3 → ResourceSaver.save → rename → обновить `.md5`).
- `.import` для wav: `compress/mode=2` (QOA), но ручная пересборка пишет 16-bit PCM `.sample` — рантайм его ест, а редактор при следующем открытии пережмёт сам. Loop выставляется кодом (`AudioManager._stream` для имён из `LOOPED`; loop_end считать через `get_length()`, НЕ через `data.size()` — там QOA-пayload). Пересборка кеша: `tools/tmp_reimport.gd`.
- Уровни: всегда измерять RMS/peak и писать цифры в комментарий (стиль репо). Референс: ночной комнатный тон ≈ −23.5 dBFS RMS после гейна плеера.
- Проверка после правок: `--check-only` по каждому правленому скрипту, затем
  `"<godot>" --headless --path . --script res://game/test_project_integration.gd` и `.../test_full_game_cycle.gd` — оба должны быть 0 failures. `test_map_verification.gd` тоже зелёный (починен, см. §5) — гонять все три, карту желательно несколько раз подряд.
- Кириллица в консоли: `chcp 65001` + `PYTHONIOENCODING=utf-8`.

## 5. test_map_verification.gd — починен (2026-07-31)
- Падение «Route covers: Time capsule 1.760/0.814, Archive capsule 1.446/1.044» — флейк ~1 прогон из 5, не от props: правки props — переименования (`clamp`→`collar`, `reference`→`ref_axis`) и явный int-каст деления, геометрию не меняют.
- Корень: `GameplayEnhancements._update_player_scale()` гоняет осциллятор размера игрока, пока жива аномалия, а пробы каверов телепортируют игрока вплотную к пьедесталам Gravity/Time — капсула замерялась посреди качели (2.274 м = скейл 1.263; воспроизведено: «Gravity sees true/true, capsule 1.845/1.351, Time 2.274/1.044»). Допуск ±0.02 м и не мог это пережить.
- Фикс в `_verify_curator_cover` и `_verify_route_covers`: на время замеров `gameplay_enhancements.set_process(false)` + `scaler.set_target(1.0)` и два `_process(1.0)` (snap), после — restore процесса. 10/10 прогонов зелёные.
