# Временная проверка компиляции всех .gd проекта (не входит в сборку).
# Запуск: godot --headless --path <proj> -s res://tmp_compile_check.gd
extends SceneTree


func _init() -> void:
        var ok := 0
        var bad := 0
        var files: Array = []
        _collect("res://", files)
        for p in files:
                var s = load(p)
                if s == null:
                        bad += 1
                        printerr("FAIL_LOAD: " + p)
                elif s is GDScript and not (s as GDScript).can_instantiate():
                        bad += 1
                        printerr("FAIL_COMPILE: " + p)
                else:
                        ok += 1
        print("CHECK_DONE ok=%d bad=%d total=%d" % [ok, bad, ok + bad])
        quit(1 if bad > 0 else 0)


func _collect(path: String, out: Array) -> void:
        var d := DirAccess.open(path)
        if d == null:
                return
        d.list_dir_begin()
        var f := d.get_next()
        while f != "":
                var full := path.path_join(f)
                if d.current_is_dir():
                        if f != ".godot" and f != "android":
                                _collect(full, out)
                elif f.ends_with(".gd"):
                        out.append(full)
                f = d.get_next()
        d.list_dir_end()
