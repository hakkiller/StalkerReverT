extends SceneTree

func _init():
	for path in ["res://models/flesh.glb", "res://models/snork_mutant.glb"]:
		var scene: PackedScene = load(path)
		if scene == null:
			print("FAIL ", path)
			continue
		var inst: Node = scene.instantiate()
		root.add_child(inst)
		var world_aabb := AABB()
		var first := true
		var anims := ""
		for n in inst.find_children("*", "AnimationPlayer", true, false):
			anims += str((n as AnimationPlayer).get_animation_list()) + " "
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var wa: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			if first:
				world_aabb = wa
				first = false
			else:
				world_aabb = world_aabb.merge(wa)
		print("RESULT ", path.get_file(), " size=", world_aabb.size, " min_y=", world_aabb.position.y, " anims=", anims)
	quit()


