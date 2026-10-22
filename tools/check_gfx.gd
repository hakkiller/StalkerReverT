extends Node
## Автоверификация стенда: компиляция .gd, сцены, Environment, туман, небо.

var errors: Array = []

func _ready() -> void:
        call_deferred("_run")

func _run() -> void:
        await get_tree().process_frame
        _scan_scripts()
        await _check_showcase()
        await _check_main_scene()
        _scan_scenes()
        print("RESULT: DONE ok")
        get_tree().quit(0)

func _scan_scripts() -> void:
        var bad := []
        var total := 0
        var stack := ["res://"]
        while stack.size() > 0:
                var dir_path: String = stack.pop_back()
                var da := DirAccess.open(dir_path)
                if da == null:
                        continue
                da.list_dir_begin()
                var f := da.get_next()
                while f != "":
                        var full := dir_path.path_join(f)
                        if da.current_is_dir():
                                if not f.begins_with("."):
                                        stack.push_back(full)
                        elif f.ends_with(".gd") and not f.ends_with(".gd.uid"):
                                total += 1
                                var s = load(full)
                                if s == null:
                                        bad.append(full)
                        f = da.get_next()
        print("SCRIPTS: total=", total, " failed=", bad.size())
        for b in bad:
                print("  SCRIPT_FAIL: ", b)

func _check_showcase() -> void:
        var ps = load("res://anomaly_fx/demo/anomaly_showcase.tscn")
        if ps == null:
                errors.append("showcase: scene failed to LOAD")
                print("SHOWCASE: LOAD_FAIL")
                return
        var inst = ps.instantiate()
        var fx := 0
        var dup_check := {}
        for ch in inst.get_children():
                dup_check[ch.name] = dup_check.get(ch.name, 0) + 1
                if String(ch.name).begins_with("Fx"):
                        fx += 1
        var dups := 0
        for k in dup_check:
                if dup_check[k] > 1:
                        dups += 1
        print("SHOWCASE: fx_nodes=", fx, " duplicate_names=", dups)
        inst.free()

func _check_main_scene() -> void:
        var ps = load("res://scenes/main/main.tscn")
        if ps == null:
                errors.append("main.tscn failed to LOAD")
                print("MAIN: LOAD_FAIL")
                return
        var main = ps.instantiate()
        get_tree().root.add_child(main)
        # TerrainGenerator._ready - корутина (2 await) + чанки + небо; FogManager._process - каждый кадр
        for i in range(14):
                await get_tree().process_frame

        var we_nodes := []
        var stack := [main]
        while stack.size() > 0:
                var nd = stack.pop_back()
                if nd is WorldEnvironment:
                        we_nodes.append(nd)
                for ch in nd.get_children():
                        stack.append(ch)
        print("MAIN: worldenvironment_count=", we_nodes.size())
        if we_nodes.size() == 0:
                errors.append("main: нет WorldEnvironment")
                print("MAIN: NO_WE")
        else:
                var env: Environment = we_nodes[0].environment
                print("MAIN: tonemap_mode=", env.tonemap_mode, " (ожидается 3=ACES)")
                print("MAIN: ssao_enabled=", env.ssao_enabled, " glow_enabled=", env.glow_enabled)
                print("MAIN: ambient=", env.ambient_light_color, " sky_affect=", env.fog_sky_affect)
                print("MAIN: bg_mode=", env.background_mode, " (2=BG_SKY) sky=", env.sky != null)
                if env.tonemap_mode != 3:
                        errors.append("tonemap != ACES")
                if not env.glow_enabled:
                        errors.append("glow off")
                if env.sky == null or env.background_mode != Environment.BG_SKY:
                        errors.append("небо не применилось (_apply_sky не сработал)")
                # FogManager должен писать в ГЛАВНЫЙ env мрачный цвет
                var fc := env.fog_light_color
                print("MAIN: fog_color=", fc)
                if fc.r > 0.6:
                        errors.append("туман молочный - FogManager нашёл свой второй WE")
                var fm_count := 0
                var st2 := [main]
                while st2.size() > 0:
                        var n2 = st2.pop_back()
                        if n2.get_script() != null and String(n2.get_script().resource_path).ends_with("fog_manager.gd"):
                                fm_count += 1
                        for c2 in n2.get_children():
                                st2.append(c2)
                print("MAIN: fogmanager_count=", fm_count, " fog_density=", env.fog_density)

        var light: DirectionalLight3D = main.get_node_or_null("DirectionalLight3D")
        if light:
                print("MAIN: light_angular=", light.light_angular_distance, " shadow_blur=", light.shadow_blur)
                if light.light_angular_distance == 0.0:
                        errors.append("мягкие тени не применились")
        else:
                errors.append("нет DirectionalLight3D")

        var cam: Camera3D = main.get_node_or_null("GameCamera")
        print("MAIN: camera=", cam != null)
        if cam == null:
                errors.append("нет GameCamera")
        main.queue_free()
        await get_tree().process_frame

func _scan_scenes() -> void:
        var bad := []
        var total := 0
        var stack := ["res://"]
        while stack.size() > 0:
                var dir_path: String = stack.pop_back()
                var da := DirAccess.open(dir_path)
                if da == null:
                        continue
                da.list_dir_begin()
                var f := da.get_next()
                while f != "":
                        var full := dir_path.path_join(f)
                        if da.current_is_dir():
                                if not f.begins_with("."):
                                        stack.push_back(full)
                        elif f.ends_with(".tscn"):
                                total += 1
                                var ps = load(full)
                                if ps == null:
                                        bad.append(full)
                        f = da.get_next()
        print("SCENES: total=", total, " failed=", bad.size())
        for b in bad:
                print("  SCENE_FAIL: ", b)
