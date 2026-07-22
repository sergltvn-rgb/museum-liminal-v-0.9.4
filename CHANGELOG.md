# 1.0.0

Полный Windows-релиз.

- Добавлен отдельный интерактивный пролог с проверкой движения, обзора, прыжка, фонаря, взаимодействия, планшета и применения стабилизатора.
- Экран провала теперь показывает причину, прогресс ночи и контекстный совет для конкретного измерения.
- RiftTrialManager разделён на диспетчер, реестр и 10 самостоятельных сцен испытаний.
- Подключены все поставленные GLB/FBX-модели с безопасными процедурными fallback и автоколлизиями.
- Проведён единый арт-, аудио- и сюжетный проход: сектор ориентации, музейный архив моделей, усиленные звуковые статусы и связная рамка смены.
- Добавлены RU/EN-каталог, переключение языка, субтитры, высокий контраст, уменьшение движения, мерцания и крупный UI.
- Добавлен Windows CI: импорт, smoke/map/catalog/full-cycle тесты и release-экспорт EXE.
- Windows-профиль получил версию 1.0.0, встроенный PCK и релизные метаданные.

# 0.9.2

Стабильность и новые измерения.

- Исправлен вылет после завершения ТЁМНОГО СЕКТОРА (обращение к global_position после очистки измерения).
- Монстр в ТЁМНОМ СЕКТОРЕ полностью невидим — его выдают только красные точки лидара.
- Мини-карта (R) убрана: навигация только по точкам лидара (ЛКМ).
- Во всех измерениях невидимый периметр — выпасть за карту нельзя.
- НОВОЕ ИЗМЕРЕНИЕ «ЭХО-КАМЕРА» (аномалия «Резонансное эхо», ключ — Резонансный настройщик):
  4 цветные колонны вспыхивают в случайном порядке — повторите его (3 раунда, длина растёт).
- НОВОЕ ИЗМЕРЕНИЕ «ЗЫБКИЙ МОСТ» (аномалия «Фазовый провал», ключ — Фазовая призма):
  6 рядов плит, в каждом одна фантомная: наступили — возврат на старт. Пройденные плиты подсвечиваются.
- Итого 6 типов аномалий и 6 карманных измерений; ключевых приборов теперь 6.
- Ночь после отключения питания стала заметно светлее (луна 0.10, фон 0.18, яркость 0.86).

# 0.9.1

Исправления багов и применение приборов.

- Исправлена ошибка парсера RiftTrialManager.gd (строка 94) и ошибка global_position на Nil.
- Главный вход больше не перекрыт: портал собран из двух пилонов и перемычки, центр свободен.
- Ночная дверь расширена до 5.6 м и полностью закрывает проём.
- Звук отключения питания: новый power_down.wav + громкий blackout + лязг двери.
- ТЁМНЫЙ СЕКТОР переделан: полная темнота, лидар-скан на ЛКМ расставляет до 4200 светящихся точек
  (синие — стены, голубые — узлы, зелёные — выход, красные — монстр). R — мини-карта.
- Склад: верстаки разбиты на 4 сегмента у стен, центральный проход между дверями свободен.
- У каждого из 12 приборов теперь есть пассивный эффект (см. README, «Применение приборов»).
- Убраны предупреждения о неиспользуемом delta.

# Changelog

## [0.9.4]
### Исправлено
- Тестовая консоль (F9): кнопки теперь нажимаются — на время открытой консоли отключается управление игроком и перехват мыши.
### Добавлено
- Новый UI консоли: карточки измерений с описаниями, цветовые акценты, hover-эффекты, кнопка закрытия. После теста состояние ночи восстанавливается как было.
- Зал отражений: силуэты в зеркалах (дефектные дрожат), люстра, 3 ошибки — зал перестраивается.
- Жёлтые залы: Блуждающий (патруль/преследование, отбирает плёнку), световые панели, жёлто-чёрная разметка выхода.
- Служба извлечения: дрон-сканер с красным лучом (отбирает ношу), ценник в у.е., экспонат виден в руках.
- Восхождение: контрольные точки (зелёные плиты), 3 движущихся уступа, маяк вершины; туман откатывается к чекпоинту.

## [0.9.3]

### Добавлено
- 4 новых измерения: Зал отражений, Жёлтые залы (Backrooms), Служба извлечения (R.E.P.O. / Lethal Company), Восхождение (PEAK). Всего 10 аномалий.
- Новый экран «Протокол локализации»: панель с цветовым акцентом аномалии, назначением прибора и статусом (E/Enter — закрыть, автозакрытие 10 с).

### Изменено
- Эхо-камера: фаза осмотра 7 с, явные вспышки (ярче + свет + звук, паузы между ними), при ошибке показ повторяется с указанием шага.
- Тёмный сектор: стены до 48 м, узлы и выход полностью скрыты — видны только точками лидара и слабым отсветом вблизи.

## 0.9.0

- Переработано движение: плавный разгон, управление в воздухе, coyote time, буфер и высота прыжка, автоматический подъём на ступени, безопасная телепортация.
- Склад получил два верстака и постоянные места для 12 русскоязычных приборов.
- Разрывы привязаны к фактическим точкам экспонатов после перестановки.
- Наблюдатель получил физическое тело, коллизию и корректную проверку прямой видимости.
- Полностью перестроены входное фойе и атриум без изменения координат камер.
- В начале ночи входная дверь закрывается с анимацией, коллизией и отдельным звуком.
- Сломанный obby заменён на Тёмный сектор с радаром, тремя узлами и красным монстром.
- Пользовательский интерфейс, камеры, терминалы и основные подписи переведены на русский язык.

## 0.8.5

- Night now begins precisely on entering the Watcher Office; Storage and Archive no longer trigger it.
- Strengthened the office transition into a true night state: mains power off, near-zero daylight, dark sky, low ambient light, fog and red emergency lighting.
- Added a Player-node fallback for the office trigger during scene initialization.

## 0.8.4

- Fixed strict Godot type inference in the rebuilt street layout; all loop variables and derived coordinates now use explicit types.
- Restored editor map construction after the parser error that left the 3D viewport empty.

## 0.8.3

- Completely rebuilt the street as a symmetrical museum forecourt with a clear arrival axis, formal lawns, crossing, parking bays and grouped visitor amenities.
- Reorganized archive shelving, catalogue furniture and equipment-storage racks around clear circulation aisles.
- Rebalanced Gravity, Time, Space and Mass wing exhibits into readable gallery compositions with aligned accent lighting.
- Made GeneratedMap scene-owned and persistent so every generated object can be moved, rotated, scaled, duplicated or deleted directly in the Godot editor.
- Added an inspector toggle for intentionally rebuilding the default generated layout.
- Fixed RiftTrialManager accessing global_position through a stale or cleared player reference.

## 0.8.2

- Reworked Critical Mass Choir around matching four visible symbols instead of deciphering raw socket arrays.
- Added target-frequency hints and explicit RESONANCE feedback directly above every monolith.
- Added live HUD progress for symbol placement, tuned frequencies and radiation dose.
- Monoliths now swap positions when placed into occupied sockets, removing obscure empty-slot shuffling.
- Slowed radiation accumulation to give players time to read and understand the room.

## 0.8.1

- Fixed RiftTrialManager failing to parse when warnings are treated as errors.
- Added an explicit Node3D cast for the temporal echo removed from the untyped array.
- Restored GameManager initialization after the pocket-dimension script loads successfully.

## 0.8.0

- Expanded Gravity Archive with true directional gravity, wall walking and sequential coordinate anchors.
- Expanded The Missing Minute with 18-second recording loops, two replayed operator echoes and three simultaneous pressure plates.
- Expanded Critical Mass Choir with physically relocated monoliths, six sockets, independent frequency tuning and a radiation-dose failure loop.
- Expanded Negative Space with live flashlight/shadow collision geometry, checkpoints and stamina-powered light bridges.
- Added arbitrary gravity support to PlayerController and safe restoration when leaving a pocket dimension.

## 0.7.1

- Mounted the player flashlight under the camera so its beam follows both yaw and pitch.
- Removed the museum relay, diagnostic-console and scale-calibration puzzle; puzzles now exist only inside pocket dimensions.
- Added a registered safety floor and a one-physics-frame spawn delay to pocket dimensions to prevent endless falling.
- Changed movement so walking is always the default and stamina is consumed only while Shift or the left-stick button is held.

## 0.7.0

- Implemented four playable pocket dimensions: Gravity Archive, The Missing Minute, Critical Mass Choir and Negative Space.
- Stabilizers now open a trial; containment completes only after the player returns with a stability key.
- Added a priority-based objective dispatcher so CCTV, puzzle and trial instructions cannot overwrite each other incorrectly.
- Added Curator line-of-sight occlusion checks and a NavigationAgent3D with direct-motion fallback.
- Added incident-catalog validation covering all twelve exhibits, rule metadata and calibration reachability.
- Moved pocket-world construction and logic out of GameManager into RiftTrialManager.

## 0.6.0

- Added an F/RB player flashlight toggle; the same contextual input controls the CCTV floodlight while cameras are open.
- Added sprint stamina, exhaustion/recovery rules and a bottom-left stamina HUD.
- Decoupled anomaly type from exhibit location: incidents now choose any exhibit in an unlocked wing.
- Moved anomaly influence and rupture visuals from the atrium dome to the selected exhibit.
- Made CCTV confirmation use the camera assigned to the actual incident wing.
- Localized gravity, time, radiation and void effects around the source and made all calibration scales reachable.
- Stabilizers are now applied at the affected exhibit; added a design specification for future pocket-dimension trials.
- Fixed the integration test incorrectly looking for the scene root as its own child.

## 0.5.0

- Replaced anomaly-wide generic relay puzzles with twelve named exhibit incidents across four wings.
- Added diagnosis, four measured relays, rule-based ordering, scale-dependent final calibration and instability penalties.
- Restricted CCTV access to the physical security office.
- Increased Curator speed to 2.4/3.05/3.7 m/s with a long-distance catch-up multiplier.
- Completely rebuilt the security office with an L-desk, six CCTV monitors, control console, server racks, alarm station, locker, incident board, grounded props and task lights.
- Reduced procedural material noise and switched to filtered, subtle surface detail.
- Added SSR and SSIL, restrained bloom and improved cinematic color grading.

## 0.4.0

- Replaced the primitive atrium map with a professionally illustrated 2048×1024 museum directory.
- Added accurate room geometry, wing colors, CCTV markers, locked-wing hatching, legend, north arrow and You Are Here marker.
- Added a backlit unshaded display material and a brushed-metal physical frame.
- Removed the oversized floating Museum Map label and disconnected colored blocks.

## 0.3.4

- Merged the complete procedural map inheritance chain into one standalone FirstMuseumMap script.
- Removed MapIntro, MapDecor, MapLighting, MapStructure and MapPrimitives script dependencies.
- Extended the Godot 4.7 cleanup script to remove stale nested project files from `scenes/`.

## 0.3.3

- Removed the duplicate inherited `MuseumModels` constant from MapDecor.
- Removed obsolete FirstMuseumMap custom-type annotations from map verification tests.
- Added explicit Node types where Godot 4.7 could not infer instantiated scene values.

## 0.3.2

- Removed every `class_name` declaration to prevent stale Godot global-class cache collisions.
- Replaced MapModels global-class calls with local preloaded script references.
- Runtime scripts now load independently of old `.godot/global_script_class_cache.cfg` entries.

## 0.3.1

- Added explicit Godot 4.7 compatibility fixes for script loading.
- Moved runtime code from `scripts/` to `game/` so stale nested `scripts/project.godot` files cannot hide the active source folder.
- Replaced custom class-name inheritance with explicit script-path inheritance.
- Removed compile-time SettingsManager type dependencies from the menu UI.
- Added `prepare_godot_47.cmd` to delete stale pre-0.3 scripts and import cache.

## 0.3.0

- Added safe player-size anomalies through dynamic capsule, camera and flashlight scaling.
- Added per-exhibit three-relay stabilization puzzles and instability penalties.
- Added the procedural Curator monster model with CCTV lens, uniform and handling claw.
- Rejected mislabeled sample GLBs; exhibits now use correctly scaled authored fallbacks.
- Rebuilt Mass Wing D containment fixtures, the security desk and monitor bank.
- Replaced giant billboard labels with compact distance-faded museum plaques.
- Reworked the atrium museum map into a compact color-coded floor plan.
- Fixed SceneTree lifecycle errors in GameManager and GameplayEnhancements.

## 0.2.4

- Increased the default test window to 1600×900 and added selectable window resolutions.
- Added vertical scrolling to every settings section.
- Permanently blocked stale `newton_statue.glb` fox files from loading and forced editor map regeneration.
- Removed three GDScript warnings: inherited unused state, enum typing and integer division.

## 0.2.3

- Removed the oversized fox GLB that was incorrectly stored as `newton_statue.glb`.
- Restored the correctly scaled procedural Newton statue fallback.

## 0.2.2

- Fixed settings UI sound lookup running before SettingsPanel entered the SceneTree.
- Added defensive SceneTree checks for menu hover and selection sounds.

## 0.2.1

- Added a redesigned four-section settings interface with native Godot controls.
- Added continuous volume and sensitivity sliders, quality presets, VSync, fullscreen and accessibility options.
- Added reduced-flashing behavior for emergency lights and void anomalies.
- Fixed the invalid main scene root caused by InputBootstrap missing its parent.

## 0.2.0

- Connected audio, main menu, pause menu and persistent settings.
- Added Windows, Linux and Web export presets plus automated build scripts.
- Added distinct gravity, temporal, radiation and void anomaly mechanics.
- Added CCTV confirmation objectives for nights 2 and 3 and CAM 11.
- Added the Watcher threat from night 2 onward.
- Added keyboard/gamepad action mapping.
- Added master-volume, mouse-sensitivity and fullscreen controls.
- Added collision generation for imported exhibits.
- Reduced physics and shadow overhead for tiny procedural props.
- Added headless map and integration smoke tests.
- Added Russian intro text and updated project documentation.
