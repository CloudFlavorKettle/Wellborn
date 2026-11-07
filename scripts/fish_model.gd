class_name FishModel
extends Node3D
## 로우폴리 물고기 (자체 제작, 외부 에셋 없음). 기본 도형을 조합해 종별로 체형을 다르게 만든다.
## 머리가 +X, 꼬리가 -X, 등이 +Y. 길이 1m 기준으로 만들고 scale로 크기를 맞춘다.
## 색·체형은 data/fish.json의 "color"(등), "belly"(배), "shape"(slender|deep|catfish)를 쓴다.
## doneness(0 날것 → 1 구운 → 2 탄)로 전체 색이 변한다.

const COOKED: Color = Color(0.72, 0.46, 0.20)
const BURNT: Color = Color(0.12, 0.09, 0.07)

static var _specs: Dictionary = {}

var _back: Color = Color(0.7, 0.74, 0.72)
var _belly: Color = Color(0.9, 0.9, 0.86)
var _shape: String = "slender"
## 재질과 "날것일 때 색"을 짝지어 둔다. doneness가 바뀌면 전부 다시 칠한다.
var _mats: Array[Array] = []

var doneness: float = 0.0:
	set(value):
		doneness = value
		_apply_tint()


static func spec_for(fish_id: String) -> Dictionary:
	if _specs.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/fish.json"))
		if typeof(parsed) == TYPE_DICTIONARY:
			for table: Variant in (parsed as Dictionary).values():
				if typeof(table) != TYPE_ARRAY:
					continue
				for f: Dictionary in table:
					_specs[f["id"]] = f
	return _specs.get(fish_id, {})


static func color_for(fish_id: String) -> Color:
	return Color.html(String(spec_for(fish_id).get("color", "#b0b8b4")))


## fish_id로 색과 체형을 정하고, length_m 길이로 만든다.
static func create(fish_id: String, length_m: float) -> FishModel:
	var m: FishModel = FishModel.new()
	var spec: Dictionary = spec_for(fish_id)
	m._back = Color.html(String(spec.get("color", "#b0b8b4")))
	m._belly = Color.html(String(spec.get("belly", "#e6e4dc")))
	m._shape = String(spec.get("shape", "slender"))
	m.scale = Vector3.ONE * length_m
	return m


func _ready() -> void:
	# 체형별 치수 (길이 1 기준)
	var body_scale: Vector3
	var head_scale: Vector3 = Vector3.ZERO
	var dorsal_len: float = 0.3
	var dorsal_h: float = 0.16
	var tail_fork: float = 0.22   # 꼬리 두 갈래 벌어짐. 0이면 둥근 꼬리
	var barbels: bool = false
	match _shape:
		"deep":       # 붕어·잉어: 등이 높고 통통
			body_scale = Vector3(1.0, 0.60, 0.34)
			dorsal_len = 0.38
			dorsal_h = 0.14
			tail_fork = 0.14
		"catfish":    # 메기: 납작한 머리, 긴 몸, 수염, 둥근 꼬리
			body_scale = Vector3(1.0, 0.40, 0.34)
			head_scale = Vector3(0.42, 0.26, 0.46)
			dorsal_len = 0.14
			dorsal_h = 0.10
			tail_fork = 0.0
			barbels = true
		_:            # 피라미: 날씬
			body_scale = Vector3(1.0, 0.42, 0.24)
			dorsal_len = 0.24
			dorsal_h = 0.11
			tail_fork = 0.22

	var back_mat: StandardMaterial3D = _mat(_back, 0.55)
	var belly_mat: StandardMaterial3D = _mat(_belly, 0.65)
	var fin_mat: StandardMaterial3D = _mat(_back.darkened(0.22), 0.7)
	var dark_mat: StandardMaterial3D = _mat(_back.darkened(0.45), 0.8)

	# 몸통(등) + 배(조금 작고 아래로 내린 밝은 구)
	_part(_sphere(0.5, 8, 5), back_mat, Vector3.ZERO, Vector3.ZERO, body_scale)
	_part(_sphere(0.5, 8, 5), belly_mat, Vector3(0.02, -0.07 * body_scale.y / 0.5, 0.0), Vector3.ZERO, body_scale * Vector3(0.96, 0.78, 0.98))

	# 메기 머리: 납작하고 넓게
	if head_scale != Vector3.ZERO:
		_part(_sphere(0.5, 8, 5), back_mat, Vector3(0.36, -0.02, 0.0), Vector3.ZERO, head_scale)

	# 입: 앞쪽 아래의 작은 어두운 틈
	_part(_box(Vector3(0.06, 0.03, 0.14)), dark_mat, Vector3(0.49 + (0.1 if barbels else 0.0), -0.06, 0.0), Vector3.ZERO, Vector3.ONE)

	# 아가미선: 머리 뒤의 얇은 고리
	var gill: TorusMesh = TorusMesh.new()
	gill.inner_radius = 0.17
	gill.outer_radius = 0.19
	gill.rings = 10
	gill.ring_segments = 4
	_part(gill, dark_mat, Vector3(0.26, 0.0, 0.0), Vector3(0.0, 0.0, PI / 2.0), Vector3(1.0, body_scale.y / 0.5 * 0.9, body_scale.z / 0.5 * 0.95))

	# 눈: 흰자 + 눈동자, 양쪽
	var white_mat: StandardMaterial3D = _mat(Color(0.95, 0.95, 0.92), 0.4, false)
	var pupil_mat: StandardMaterial3D = _mat(Color(0.06, 0.06, 0.08), 0.3, false)
	for side in [-1.0, 1.0]:
		var ez: float = (0.5 * body_scale.z) * 0.92 * side
		_part(_sphere(0.055, 7, 4), white_mat, Vector3(0.33, 0.07, ez), Vector3.ZERO, Vector3.ONE)
		_part(_sphere(0.03, 6, 3), pupil_mat, Vector3(0.355, 0.075, ez + 0.03 * side), Vector3.ZERO, Vector3.ONE)

	# 등지느러미
	_part(_prism(dorsal_len, dorsal_h, 0.025), fin_mat, Vector3(-0.02, 0.5 * body_scale.y + dorsal_h * 0.35, 0.0), Vector3(0.0, 0.0, 0.0), Vector3.ONE)
	# 뒷지느러미(배 뒤쪽)
	_part(_prism(0.16, 0.1, 0.02), fin_mat, Vector3(-0.22, -0.5 * body_scale.y - 0.02, 0.0), Vector3(PI, 0.0, 0.0), Vector3.ONE)
	# 가슴지느러미: 양옆, 뒤로 젖힘
	for side in [-1.0, 1.0]:
		_part(_prism(0.13, 0.065, 0.02), fin_mat, Vector3(0.12, -0.1, 0.5 * body_scale.z * 0.9 * side), Vector3(deg_to_rad(75.0) * side, deg_to_rad(-35.0) * side, 0.0), Vector3.ONE)

	# 꼬리: 두 갈래(위·아래 잎) 또는 둥근 부채
	if tail_fork > 0.0:
		for sgn in [1.0, -1.0]:
			_part(_prism(0.26, 0.17, 0.025), fin_mat, Vector3(-0.58, sgn * tail_fork * 0.5, 0.0), Vector3(0.0, 0.0, PI / 2.0 + sgn * 0.5), Vector3.ONE)
	else:
		_part(_prism(0.34, 0.34, 0.03), fin_mat, Vector3(-0.6, 0.0, 0.0), Vector3(0.0, 0.0, PI / 2.0), Vector3.ONE)

	# 메기 수염
	if barbels:
		for side in [-1.0, 1.0]:
			var w: MeshInstance3D = _part(_cyl(0.008, 0.3), dark_mat, Vector3(0.55, -0.03, 0.12 * side), Vector3(0.0, 0.0, 0.0), Vector3.ONE)
			w.rotation = Vector3(deg_to_rad(-15.0) * side, deg_to_rad(-55.0 * side), deg_to_rad(-70.0))
	_apply_tint()


# ---------- 조립 도우미 ----------

func _part(mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	add_child(mi)
	return mi


func _mat(c: Color, roughness: float, tinted: bool = true) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	if tinted:
		_mats.append([m, c])
	return m


func _sphere(r: float, radial: int, rings: int) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = radial
	s.rings = rings
	return s


func _prism(w: float, h: float, d: float) -> PrismMesh:
	var p: PrismMesh = PrismMesh.new()
	p.size = Vector3(w, h, d)
	return p


func _box(size: Vector3) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	return b


func _cyl(r: float, h: float) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = r * 0.5
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 4
	c.rings = 1
	return c


func _apply_tint() -> void:
	for pair: Array in _mats:
		var m: StandardMaterial3D = pair[0]
		var raw: Color = pair[1]
		if doneness <= 1.0:
			m.albedo_color = raw.lerp(COOKED, clampf(doneness, 0.0, 1.0))
		else:
			m.albedo_color = COOKED.lerp(BURNT, clampf(doneness - 1.0, 0.0, 1.0))
