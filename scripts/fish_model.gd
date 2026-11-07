class_name FishModel
extends Node3D
## 로우폴리 물고기. 몸통·꼬리·등지느러미·눈을 기본 도형으로 조합한다 (자체 제작, 에셋 없음).
## 머리가 +X, 꼬리가 -X. 길이 1m 기준으로 만들고 scale로 크기를 맞춘다.
## 색은 data/fish.json의 "color"를 쓴다. tint로 익은 정도(날것→구운→탄)를 덧입힌다.

const COOKED: Color = Color(0.72, 0.46, 0.20)
const BURNT: Color = Color(0.12, 0.09, 0.07)

static var _colors: Dictionary = {}

var _body_mat: StandardMaterial3D
var _fin_mat: StandardMaterial3D
var _base: Color = Color(0.7, 0.74, 0.72)
## 0 = 날것, 1 = 구운, 2 = 탄. 소수로 중간 단계.
var doneness: float = 0.0:
	set(value):
		doneness = value
		_apply_tint()


static func color_for(fish_id: String) -> Color:
	if _colors.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/fish.json"))
		if typeof(parsed) == TYPE_DICTIONARY:
			for table: Variant in (parsed as Dictionary).values():
				if typeof(table) != TYPE_ARRAY:
					continue
				for f: Dictionary in table:
					_colors[f["id"]] = Color.html(String(f.get("color", "#b0b8b4")))
	return _colors.get(fish_id, Color(0.7, 0.74, 0.72))


## fish_id로 색을 정하고, length_m 길이로 만든다.
static func create(fish_id: String, length_m: float) -> FishModel:
	var m: FishModel = FishModel.new()
	m._base = color_for(fish_id)
	m.scale = Vector3.ONE * length_m
	return m


func _ready() -> void:
	_body_mat = StandardMaterial3D.new()
	_body_mat.roughness = 0.6
	_fin_mat = StandardMaterial3D.new()
	_fin_mat.roughness = 0.7
	_apply_tint()

	# 몸통: 앞뒤로 길쭉한 구
	var body: MeshInstance3D = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 8
	sph.rings = 4
	sph.material = _body_mat
	body.mesh = sph
	body.scale = Vector3(1.0, 0.48, 0.3)
	add_child(body)

	# 꼬리: 납작한 삼각 프리즘, 뒤쪽으로 벌어짐
	var tail: MeshInstance3D = MeshInstance3D.new()
	var tp: PrismMesh = PrismMesh.new()
	tp.size = Vector3(0.42, 0.34, 0.04)
	tp.material = _fin_mat
	tail.mesh = tp
	tail.rotation = Vector3(0.0, 0.0, PI / 2.0)
	tail.position = Vector3(-0.58, 0.0, 0.0)
	add_child(tail)

	# 등지느러미
	var fin: MeshInstance3D = MeshInstance3D.new()
	var fp: PrismMesh = PrismMesh.new()
	fp.size = Vector3(0.3, 0.14, 0.03)
	fp.material = _fin_mat
	fin.mesh = fp
	fin.position = Vector3(0.0, 0.27, 0.0)
	add_child(fin)

	# 눈
	var eye_mat: StandardMaterial3D = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.08, 0.08, 0.1)
	for side in [-1.0, 1.0]:
		var eye: MeshInstance3D = MeshInstance3D.new()
		var es: SphereMesh = SphereMesh.new()
		es.radius = 0.045
		es.height = 0.09
		es.radial_segments = 6
		es.rings = 3
		es.material = eye_mat
		eye.mesh = es
		eye.position = Vector3(0.3, 0.08, 0.14 * side)
		add_child(eye)


func _apply_tint() -> void:
	if _body_mat == null:
		return
	var c: Color
	if doneness <= 1.0:
		c = _base.lerp(COOKED, clampf(doneness, 0.0, 1.0))
	else:
		c = COOKED.lerp(BURNT, clampf(doneness - 1.0, 0.0, 1.0))
	_body_mat.albedo_color = c
	_fin_mat.albedo_color = c.darkened(0.25)
