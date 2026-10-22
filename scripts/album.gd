class_name Album
extends Node
## Pictures for the book: each item's model photographed once when the game starts, in a little
## studio of its own, then toned sepia like an old engraving. `pics` fills in over the first frames.

const SUBJECTS := ["ing_eye", "ing_shroom", "ing_wing", "ing_leg", "ing_spider", "ing_petal", "ing_pepper", "ing_scale",
		"bellows", "stick", "wand", "potion", "cauldron"]
const SIZE := 192

var pics := {}
var _studio: SubViewport
var _camera: Camera3D
var _queue: Array = []
var _subject: Node3D
var _wait := 0


func _ready() -> void:
	# Nothing to photograph without a screen (headless runs)
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_studio = SubViewport.new()
	_studio.size = Vector2i(SIZE, SIZE)
	_studio.own_world_3d = true
	_studio.transparent_bg = true
	_studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_studio)
	_camera = Camera3D.new()
	_camera.fov = 28.0
	_studio.add_child(_camera)
	_queue = SUBJECTS.duplicate()


func _process(_dt: float) -> void:
	if _subject == null:
		if _queue.is_empty():
			if _studio != null:
				_studio.queue_free()
				_studio = null
			set_process(false)
			return
		_pose(_queue[0])
		_wait = 2
		return
	_wait -= 1
	if _wait > 0:
		return
	var name: String = _queue.pop_front()
	var img := _studio.get_texture().get_image()
	if img != null and not img.is_empty():
		pics[name] = ImageTexture.create_from_image(_sepia(img))
	_subject.queue_free()
	_subject = null


## Puts a model in the studio, turned a little, and frames the camera on it
func _pose(name: String) -> void:
	_subject = Models.make(name)
	_subject.rotation.y = 0.5
	if name == "stick":
		_subject.rotation = Vector3(0.9, 0.4, 0.6)
	_studio.add_child(_subject)
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in _subject.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var centre := box.get_center()
	var reach := box.size.length() * 0.5
	var dist := reach / tan(deg_to_rad(_camera.fov * 0.5)) * 1.05
	_camera.position = centre + Vector3(0, 0.45, 1.0).normalized() * dist
	_camera.look_at(centre)


## Browns it like an old print: the light and dark kept, the colour gone to sepia, with a little grain
static func _sepia(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var ink := Color("3a2414")
	var paper := Color("f2dfb0")
	var src := img.duplicate() as Image
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a < 0.05:
				continue
			# An inked outline where it meets the paper
			var edge := false
			for d: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				var q := Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or src.get_pixel(q.x, q.y).a < 0.3:
					edge = true
			var lum := clampf(c.r * 0.35 + c.g * 0.5 + c.b * 0.15, 0.0, 1.0)
			lum = clampf(pow(lum, 1.25) * 1.25 - 0.05, 0.0, 1.0)
			if edge:
				lum *= 0.25
			var grain := (fposmod(sin(float(x * 12 + y * 78)) * 43758.5, 1.0) - 0.5) * 0.08
			var out := ink.lerp(paper, clampf(lum + grain, 0.0, 1.0))
			out.a = c.a
			img.set_pixel(x, y, out)
	return img
