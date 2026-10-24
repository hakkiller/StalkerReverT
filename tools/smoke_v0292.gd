extends SceneTree

## Смок v0.29.2 «СВАЙП И СЧЁТ»: ключ trader.biomass (корень "не списывается"),
## цена в тексте покупки, товар/цены торговца, SwipeHelper (attach, невидимые полосы)

func _initialize() -> void:
	var fails: Array[String] = []

	# --- Локализация торговца ---
	var loc = load("res://core/localization.gd").new()
	loc.set_lang("ru")
	var bm_ru: String = loc.t("trader.biomass", {"n": 43672})
	if bm_ru != "Биомасса: 43672":
		fails.append("trader.biomass ru broken: " + bm_ru)
	var bt_ru: String = loc.t("trader.bought", {"name": "АПТЕЧКА", "cost": 202})
	if bt_ru != "Куплено: АПТЕЧКА (-202 биомассы)":
		fails.append("trader.bought ru broken: " + bt_ru)
	loc.set_lang("en")
	if loc.t("trader.biomass", {"n": 43672}) != "Biomass: 43672":
		fails.append("trader.biomass en broken")
	if loc.t("trader.bought", {"name": "MEDKIT", "cost": 202}) != "Bought: MEDKIT (-202 biomass)":
		fails.append("trader.bought en broken")
	loc.set_lang("ru")

	# --- Товар торговца: состав/цены не тронуты ---
	var items: Array = RunEventsData.TRADER_ITEMS
	if items.size() != 6:
		fails.append("trader items size %d" % items.size())
	var ids := {}
	for it in items:
		var id: String = str(it["id"])
		if ids.has(id) or str(it.get("name_ru", "")) == "" or str(it.get("desc_ru", "")) == "":
			fails.append("trader item broken: " + id)
		ids[id] = true
	var mk: Dictionary = items[0]
	if str(mk["id"]) != "medkit":
		fails.append("medkit not first")
	if int(RunEventsData.trader_cost(mk, 1)) != 180:
		fails.append("trader cost w1 broken")
	if int(RunEventsData.trader_cost(mk, 2)) != 202:
		fails.append("trader cost w2 broken")
	if int(RunEventsData.trader_cost(mk, 3)) != 223:
		fails.append("trader cost w3 broken")

	# --- SwipeHelper: обёртка, проводка, невидимые скроллбары ---
	var sh = load("res://ui/base/swipe_helper.gd")
	if sh == null:
		fails.append("swipe_helper.gd not loaded")
	else:
		var sc := ScrollContainer.new()
		var wrap: Control = sh.attach(sc, false)
		if wrap == null or wrap.get_child_count() != 2:
			fails.append("attach wrap broken")
		else:
			var lay = wrap.get_child(1)
			if lay.get("scroll") != sc:
				fails.append("attach scroll wiring broken")
			if bool(lay.get("horiz")):
				fails.append("attach horiz wiring broken")
			var vb = sc.get_v_scroll_bar()
			if vb.custom_minimum_size != Vector2(0, 0) or absf(float(vb.modulate.a)) > 0.001:
				fails.append("v scrollbar not hidden")
			var hb = sc.get_h_scroll_bar()
			if absf(float(hb.modulate.a)) > 0.001:
				fails.append("h scrollbar not hidden")
			if lay.get("mouse_filter") != Control.MOUSE_FILTER_STOP:
				fails.append("layer mouse_filter broken")
		wrap.free()

	# --- Компиляция новых/не зависящих от autoload скриптов ---
	if load("res://ui/base/swipe_helper.gd") == null:
		fails.append("swipe_helper compile fail")
	if load("res://core/localization.gd") == null:
		fails.append("localization compile fail")

	if fails.is_empty():
		print("SMOKE v0.29.2: ALL OK (loc trader x2, items 6, costs 180/202/223, SwipeHelper attach+hide)")
		quit(0)
	else:
		for f in fails:
			printerr("FAIL: " + f)
		quit(1)
