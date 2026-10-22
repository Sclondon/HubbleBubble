class_name Models
## The Blender models in models/ (built by art/make_models.py), dressed in the game's own look.


## An instance of models/<name>.glb, every mesh wearing the vertex-lit look
static func make(name: String, material: Material = null) -> Node3D:
	var scene: PackedScene = load("res://models/%s.glb" % name)
	var node: Node3D = scene.instantiate()
	dress(node, material if material != null else Shape.plain())
	return node


static func dress(node: Node, material: Material) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
