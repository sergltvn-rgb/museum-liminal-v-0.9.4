class_name RiftTrialRegistry
extends RefCounted
## Central catalogue of every pocket-dimension trial. Splitting the former
## 900-line monolith into declarative scene descriptors lets GameManager,
## the tutorial layer and the localization pass share one source of truth.

## Ordered list. Each entry is a self-contained "scene" definition for a trial:
##   kind          – runtime match key used by RiftTrialManager
##   title_key     – localization key (see localization/museum.csv)
##   title_ru/en   – fallback titles when no translation is loaded
##   objective_*   – first status line shown on entry
##   tutorial_*    – one-shot micro hints (\n separated) before first attempt
##   fail_tip_*    – shown on the failure feedback panel
const TRIALS := [
	{
		"kind": "gravity_surge",
		"title_key": "TRIAL_GRAVITY_TITLE",
		"title_ru": "ГРАВИТАЦИОННЫЙ АРХИВ", "title_en": "GRAVITY ARCHIVE",
		"objective_ru": "Поверните архив: ПОЛ → ЗАПАДНАЯ СТЕНА → ДАЛЬНЯЯ СТЕНА. Ищите фиолетовые якоря.",
		"objective_en": "Rotate the archive: FLOOR -> WEST WALL -> FAR WALL. Look for the violet anchors.",
		"tutorial_ru": "Каждый якорь меняет направление гравитации.\nАктивируйте их строго по порядку (E).",
		"tutorial_en": "Each anchor changes the gravity direction.\nActivate them strictly in order (E).",
		"fail_tip_ru": "Идите к следующему якорю только после смены гравитации.",
		"fail_tip_en": "Move to the next anchor only after gravity flips.",
	},
	{
		"kind": "temporal_drift",
		"title_key": "TRIAL_TIME_TITLE",
		"title_ru": "ПРОПАВШАЯ МИНУТА", "title_en": "THE MISSING MINUTE",
		"objective_ru": "Запишите себя на плитах. После 18 секунд ваше эхо повторит маршрут. Нужны три версии одновременно.",
		"objective_en": "Record yourself on the plates. After 18 seconds your echo repeats the route. You need three of you at once.",
		"tutorial_ru": "Плиты нужно нажать одновременно тремя эхо.\nЗапишите разные маршруты за каждый цикл.",
		"tutorial_en": "Three echoes must press the plates at once.\nRecord a different route each loop.",
		"fail_tip_ru": "Планируйте маршрут так, чтобы прошлые эхо остались на плитах.",
		"fail_tip_en": "Plan a route so earlier echoes stay on their plates.",
	},
	{
		"kind": "radiation_bloom",
		"title_key": "TRIAL_RADIATION_TITLE",
		"title_ru": "КРИТИЧЕСКАЯ МАССА", "title_en": "CRITICAL MASS CHOIR",
		"objective_ru": "ШАГ 1: совместите одинаковые символы. ШАГ 2: клавишей G настройте частоту до РЕЗОНАНСА.",
		"objective_en": "STEP 1: match identical symbols. STEP 2: press G to tune frequency to RESONANCE.",
		"tutorial_ru": "E — поднять и поставить монолит в гнездо с тем же символом.\nG — настроить частоту монолита. Доза растёт при ошибках.",
		"tutorial_en": "E - carry a monolith to a socket with the same symbol.\nG - tune its frequency. Dose rises while wrong.",
		"fail_tip_ru": "Сначала расставьте символы, потом настраивайте частоты — доза падает.",
		"fail_tip_en": "Place symbols first, then tune frequencies to lower the dose.",
	},
	{
		"kind": "echo_chamber",
		"title_key": "TRIAL_ECHO_TITLE",
		"title_ru": "ЭХО-КАМЕРА", "title_en": "ECHO CHAMBER",
		"objective_ru": "Осмотритесь: запомните, где какая колонна.",
		"objective_en": "Look around and memorize each column's position.",
		"tutorial_ru": "Запомните порядок вспышек колонн.\nПовторите его, нажимая E у нужных колонн.",
		"tutorial_en": "Memorize the order the columns flash.\nRepeat it by pressing E at each column.",
		"fail_tip_ru": "Дождитесь конца показа, затем повторяйте последовательность спокойно.",
		"fail_tip_en": "Wait for the full playback, then repeat the sequence calmly.",
	},
	{
		"kind": "glass_bridge",
		"title_key": "TRIAL_BRIDGE_TITLE",
		"title_ru": "ЗЫБКИЙ МОСТ", "title_en": "GLASS BRIDGE",
		"objective_ru": "Половина плит — фантомы: они возвращают на старт. Доберитесь до ключа.",
		"objective_en": "Half the tiles are phantoms that reset you. Reach the key.",
		"tutorial_ru": "Настоящие плиты держат вес, фантомные — нет.\nПробуйте по одной и запоминайте безопасный путь.",
		"tutorial_en": "Real tiles hold your weight, phantoms don't.\nTest one at a time and memorize the safe path.",
		"fail_tip_ru": "Запоминайте, какие плиты оказались фантомами, и обходите их.",
		"fail_tip_en": "Remember which tiles were phantoms and avoid them.",
	},
	{
		"kind": "mirror_maze",
		"title_key": "TRIAL_MIRROR_TITLE",
		"title_ru": "ЗАЛ ОТРАЖЕНИЙ", "title_en": "MIRROR MAZE",
		"objective_ru": "Найдите 3 дефектных зеркала: их силуэты дрожат (E). 3 ошибки — зал перестроится.",
		"objective_en": "Find 3 defective mirrors: their silhouettes tremble (E). 3 mistakes reshuffle the hall.",
		"tutorial_ru": "Дефектные отражения дрожат и мерцают.\nОтмечайте только их — стабильные зеркала штрафуют.",
		"tutorial_en": "Defective reflections tremble and flicker.\nTag only those - stable mirrors penalize you.",
		"fail_tip_ru": "Присмотритесь к дрожащим силуэтам, не спешите с выбором.",
		"fail_tip_en": "Watch for trembling silhouettes before you commit.",
	},
	{
		"kind": "yellow_halls",
		"title_key": "TRIAL_YELLOW_TITLE",
		"title_ru": "ЖЁЛТЫЕ ЗАЛЫ", "title_en": "YELLOW HALLS",
		"objective_ru": "Соберите 3 плёнки, избегайте Блуждающего и найдите выход с разметкой.",
		"objective_en": "Collect 3 tapes, avoid the Wanderer and find the striped exit.",
		"tutorial_ru": "Блуждающий отнимает плёнку, если поймает.\nДержите дистанцию и слушайте его шаги.",
		"tutorial_en": "The Wanderer steals a tape if it catches you.\nKeep your distance and listen for its steps.",
		"fail_tip_ru": "Не идите на Блуждающего в лоб — уводите его и петляйте.",
		"fail_tip_en": "Don't rush the Wanderer - lure it away and loop around.",
	},
	{
		"kind": "scrap_run",
		"title_key": "TRIAL_SCRAP_TITLE",
		"title_ru": "СЛУЖБА ИЗВЛЕЧЕНИЯ", "title_en": "SCRAP RUN",
		"objective_ru": "Перенесите 3 ценности к точке извлечения по одной. Дрон-сканер патрулирует склад!",
		"objective_en": "Carry 3 valuables to the extraction pad one at a time. A scanner drone patrols!",
		"tutorial_ru": "Носите ценности по одной (E), сдавайте на зелёной точке.\nЛуч дрона возвращает ношу на стеллаж.",
		"tutorial_en": "Carry valuables one by one (E), deliver on the green pad.\nThe drone beam returns your load to the shelf.",
		"fail_tip_ru": "Ждите, пока луч дрона отвернётся, и перебегайте короткими рывками.",
		"fail_tip_en": "Wait for the drone beam to turn away, then dash in short bursts.",
	},
	{
		"kind": "ascent",
		"title_key": "TRIAL_ASCENT_TITLE",
		"title_ru": "ВОСХОЖДЕНИЕ", "title_en": "THE ASCENT",
		"objective_ru": "Вверх по уступам! Зелёные плиты — контрольные точки, фиолетовые — движутся.",
		"objective_en": "Climb the ledges! Green tiles are checkpoints, violet ones move.",
		"tutorial_ru": "Туман поднимается — не задерживайтесь.\nАктивируйте зелёные контрольные точки по пути.",
		"tutorial_en": "The fog keeps rising - don't linger.\nActivate the green checkpoints on the way up.",
		"fail_tip_ru": "Двигайтесь ритмично и активируйте каждую контрольную точку.",
		"fail_tip_en": "Keep a steady rhythm and hit every checkpoint.",
	},
	{
		"kind": "void_rift",
		"title_key": "TRIAL_VOID_TITLE",
		"title_ru": "ТЁМНЫЙ СЕКТОР", "title_en": "NEGATIVE SPACE",
		"objective_ru": "ЛКМ — импульс лидара · активируйте 3 узла и найдите выход.",
		"objective_en": "LMB - lidar pulse. Activate 3 nodes and find the exit.",
		"tutorial_ru": "Сектор чёрный — стреляйте лидаром (ЛКМ), чтобы видеть.\nКрасные точки — Наблюдатель, держитесь от него.",
		"tutorial_en": "The sector is pitch black - fire the lidar (LMB) to see.\nRed dots are the Watcher, stay away from it.",
		"fail_tip_ru": "Сканируйте чаще и обходите красные точки по краю сектора.",
		"fail_tip_en": "Scan more often and skirt the red dots along the edges.",
	},
]

static func kinds() -> PackedStringArray:
	var result := PackedStringArray()
	for entry in TRIALS:
		result.append(String(entry["kind"]))
	return result

static func find(kind: String) -> Dictionary:
	for entry in TRIALS:
		if String(entry["kind"]) == kind:
			return entry
	return {}

static func title_for(kind: String, use_en: bool) -> String:
	var entry := find(kind)
	if entry.is_empty():
		return kind
	return String(entry["title_en" if use_en else "title_ru"])

static func objective_for(kind: String, use_en: bool) -> String:
	var entry := find(kind)
	if entry.is_empty():
		return ""
	return String(entry["objective_en" if use_en else "objective_ru"])

static func tutorial_for(kind: String, use_en: bool) -> PackedStringArray:
	var entry := find(kind)
	if entry.is_empty():
		return PackedStringArray()
	return String(entry["tutorial_en" if use_en else "tutorial_ru"]).split("\n", false)

static func fail_tip_for(kind: String, use_en: bool) -> String:
	var entry := find(kind)
	if entry.is_empty():
		return ""
	return String(entry["fail_tip_en" if use_en else "fail_tip_ru"])
