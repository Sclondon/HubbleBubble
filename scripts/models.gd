class_name Models
## The Blender models in models/ (built by art/make_models.py), dressed in the game's own look:
## pieces named *_glass get see-through glass, *_glow shine by themselves.

static var _glass: ShaderMaterial
static var _glow: ShaderMaterial


## An instance of models/<name>.glb, every mesh wearing the vertex-lit look
static func make(name: String, material: Material = null) -> Node3D:
	var scene: PackedScene = load("res://models/%s.glb" % name)
	var node: Node3D = scene.instantiate()
	dress(node, material if material != null else Shape.plain())
	return node


static func dress(node: Node, material: Material) -> void:
	if _glass == null:
		_glass = ShaderMaterial.new()
		_glass.shader = preload("res://shaders/glass.gdshader")
		_glow = Shape.mat(1.0)
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if n.ends_with("_glass"):
			mi.material_override = _glass
		elif n.ends_with("_glow"):
			mi.material_override = _glow
		else:
			mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
