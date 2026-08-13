# STATE — где мы сейчас

ОДИН источник состояния проекта. Расходится с любым другим документом — прав этот.
Обновляется после каждого шага, а не в конце сессии.

ОБНОВЛЕНО: 2026-08-13 15:10
ЗАДАЧА: улица V2 — перевести остатки кодовой геометрии в Blender
ШАГ: 2 из 5 — инвентаризация закончена, список на перенос собран
СТАТУС: ждёт решения пользователя по списку A-F
ДОКУМЕНТ ЗАДАЧИ: STREET_SCHEME_V2.md
ВЕТКА: wip/audit-2026-07-26 · последний коммит f571f51 (2026-08-13 14:55)

## Следующее действие (один шаг)

Согласовать с пользователем список A-F ниже, затем строить первый согласованный
пакет в tools/lowpoly/blender_street_v2.py. Координаты V2 не трогать.

## Сделано и проверено (цифры)

- Улица V2 в игре. MeshInstance3D 9563 · StaticBody3D 550 · CollisionShape3D 565 · камер 11
  (verify.cmd geometry, 2026-08-13). Дельта -2 меша / -2 тела к 11 августа: цифры 9565 / 552
  сняты в 12:45, а в 13:05 удалили лампу (20, 68.9) и счётчики не пересняли.
- run_tests.cmd целиком зелёный: [OK] All tests passed, 7 наборов (2026-08-11).
- _verify_drive_alignment(): трасса заезда держит полосу z 57.25.
- Court Gate снят с тротуара (z 51.50, пирсы ±5.9).
- Из .blend приходят 8 модулей + мост: lp_street_road_20, lp_street_walk_20,
  lp_street_verge_20, lp_street_bay_2, lp_street_drive_apron, lp_street_bollard,
  lp_street_lamp, lp_street_shelter, lp_street_bridge.
- verify.cmd geometry прогнан 2026-08-13: ALL CHECKS PASSED, весь test_map_verification.gd
  зелёный (форекорт 582 меша, полоса z 57.25, подход 1.60 м, 513 ключей локализации).
  Пути game/tools/check_*.gd подтверждены. Ложный [ATTENTION] от ошибки terrabrush .dll
  отфильтрован. Ещё не гонялись: verify.cmd materials и verify.cmd full.
- Коммит f571f51: AGENTS.md, WORKLOG.md, STATE.md, verify.cmd, .gitignore впервые
  попали в гит, 795 строк. До этого правила и журнал не были под контролем версий.

## Инвентаризация: что на улице ещё НЕ модель (2026-08-13)

Строится кодом из примитивов:

A. Деревья вдоль улицы — ExteriorProps.build_birch/oak/pine
   (FirstMuseumMap :3266, :3268, :3421, :3422, :3494-3498; GroundsProps :530-534).
B. Две гостевые машины в кармане — build_parked_car (:3248, :3251);
   ещё три на парковке (:3481-3485).
C. Машина игрока — build_player_car (:3258). Визуально забракована,
   переделывать отдельно; салон и стёкла в модель НЕ идут.
D. Фонари — build_lamp_post (:3124; GroundsProps :840-850). Второй источник ламп
   помимо lp_street_lamp: два пайплайна на одну и ту же вещь.
E. Дальний фон — build_mountain_range / build_river (:3385-3397;
   GroundsProps :459, :516).
F. Разметка парковки и ограждение (:3445-3479) — примитивы.

## Ждёт тебя (не агента)

1. Приёмка глазами: shots/street_v2/contact_sheet.jpg — не закрыта ни разу.
2. Проём ворот стал 10.6 м вместо 8.2 (следствие радиуса фонтана) — ок или нет.
3. Что из A-F переносим в Blender и в каком порядке.
4. Судьба осиротевших моделей P0 — удалять нельзя без тебя.
5. 25 отслеживаемых файлов игры (FirstMuseumMap.gd, GameManager.gd, MapModels.gd,
   GroundsProps.gd, DoorSwing.gd, test_map_verification.gd, check_doors.gd,
   run_tests.cmd, 11 атласов .import, blender_build.py) изменены прошлыми сессиями
   и не закоммичены. Это не мои правки — отдельным чекпойнтом только с твоего слова.

## Не трогать

main; координаты V2 из STREET_SCHEME_V2.md; константы тестов.

## Архив (НЕ источник состояния)

AGENT_HANDOFF.md, HANDOFF.md, NEXT_CHAT_PROMPT.md, IMPROVEMENT_PLAN.md,
DECOR_AUDIT_SUMMARY.md, STREET_MASTER_REPORT.md — история, читать только по ссылке.
