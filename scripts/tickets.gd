class_name Tickets
extends Node3D
## The orders as real notes in the hut: little sheets of paper pegged to a string strung across the
## room just in front of you (where the tickets always were on the screen), each with the potion's
## name scrawled on it, swinging a little, scorching brown as the customer loses patience. Drawn sharp
## on the smoke layer (Shop.SMOKE_LAYER) so the scrawl reads. Shop.update_tickets() places them.

var _notes: Array[Node3D] = []
var _papers: Array[StandardMaterial3D] = []
var _labels: Array[Label3D] = []
var _string: MeshInstance3D
var _font: FontVariation


func _ready() -> void:
	_font = FontVariation.new()
	_font.base_font = load("res://fonts/Caveat.ttf")
	_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	for i in 3:
		var note := Node3D.new()
		add_child(note)
		var paper := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 0.6)
		q.center_offset = Vector3(0, -0.32, 0)
		paper.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color("e8dab4")
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		paper.material_override = m
		paper.layers = 4
		note.add_child(paper)
		var peg := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.07, 0.14, 0.03)
		peg.mesh = pb
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.albedo_color = Color("6b3e22")
		peg.material_override = pm
		peg.position = Vector3(0, -0.02, 0.01)
		peg.layers = 4
		note.add_child(peg)
		var label := Label3D.new()
		label.font = _font
		label.font_size = 78
		label.pixel_size = 0.0024
		label.modulate = Color("2a1a3a")
		label.outline_size = 0
		label.width = 380
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.position = Vector3(0, -0.33, 0.01)
		label.shaded = false
		label.double_sided = false
		label.layers = 4
		note.add_child(label)
		_notes.append(note)
		_papers.append(m)
		_labels.append(label)
	_string = MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.008
	sm.bottom_radius = 0.008
	sm.height = 1.0
	sm.radial_segments = 4
	_string.mesh = sm
	var stm := StandardMaterial3D.new()
	stm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stm.albedo_color = Color("c8a878")
	_string.material_override = stm
	_string.layers = 4
	add_child(_string)


## Places the notes: `spots` are where each sits in the world (top middle, where it's pegged) and how
## wide; `orders` what's on them (name, patience 0 to 1, chosen); `facing` the camera's basis
func show_orders(spots: Array, orders: Array, facing: Basis, light: Color, t: float) -> void:
	_string.visible = not orders.is_empty()
	for i in 3:
		var note := _notes[i]
		note.visible = i < orders.size()
		if not note.visible:
			continue
		var o: Dictionary = orders[i]
		var at: Vector3 = spots[i][0]
		var wide: float = spots[i][1]
		var swing := sin(t * 1.6 + i * 1.9) * 0.05
		if o.frac < 0.25:
			swing += sin(t * 30.0) * 0.05
		var grow := 1.08 if o.selected else 1.0
		note.global_transform = Transform3D(facing * Basis(Vector3.BACK, swing).scaled(Vector3.ONE * wide * grow), at)
		_labels[i].text = String(o.name)
		var paper := Color("f4e8c8") if o.selected else Color("e8dab4")
		paper = paper.lerp(Color(0.45, 0.26, 0.1), (1.0 - o.frac) * 0.55)
		_papers[i].albedo_color = Color(paper.r * light.r, paper.g * light.g, paper.b * light.b)
	if not orders.is_empty():
		var a: Vector3 = spots[0][0] - facing.x * spots[0][1] * 0.7
		var b: Vector3 = spots[orders.size() - 1][0] + facing.x * spots[0][1] * 0.7
		var mid: Vector3 = (a + b) * 0.5 + facing.y * spots[0][1] * 0.04
		_string.global_transform = Transform3D(Basis(facing.x, facing.y, facing.z) * Basis(Vector3.BACK, PI * 0.5).scaled(Vector3(1, a.distance_to(b), 1)), mid)
