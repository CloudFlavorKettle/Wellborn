class_name FishingRod
extends Node3D
## 낚시 연출 전용 (판정 없음). 낚싯대, 찌, 낚싯줄, 물결, 낚아 올린 물고기.
## 플레이어(CharacterBody3D)의 자식으로 둔다. 플레이어의 앞은 -Z다.

const ROD_LENGTH: float = 1.5
const RIPPLE_SHADER: Shader = preload("res://shaders/ripple.gdshader")

## 손 높이쯤, 오른쪽 앞.
@export var grip_offset: Vector3 = Vector3(0.22, 0.95, -0.18)
## 낚싯대가 앞으로 기울어진 정도(도). 클수록 수평에 가깝다.
@export var rod_tilt_deg: float = 58.0
## 찌 크기 배율. 멀리서도 읽히도록 실제보다 크게 과장한다.
@export var bobber_scale: float = 2.2

var _pivot: Node3D
var _bobber: Node3D
var _line_mesh: ImmediateMesh
var _line: MeshInstance3D
var _fish: MeshInstance3D

var _bobber_out: bool = false
var _float_base: Vector3 = Vector3.ZERO
var _floating: bool = false
var _dip: float = 0.0
var _dip_target: float = 0.0
var _shake: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	if Net.is_dedicated():
		set_process(false)  # 전용 서버엔 연출이 필요 없다.
		return
	_build_rod()
	_build_bobber()
	_build_line()
	_build_fish()
	show_gear(false)


# ---------- 공개 API (FishingController가 부른다) ----------

func show_gear(on: bool) -> void:
	_pivot.visible = on
	if not on:
		_bobber.visible = false
		_line.visible = false
		_bobber_out = false
		_floating = false


func tip_position() -> Vector3:
	return _pivot.to_global(Vector3(0.0, ROD_LENGTH, 0.0))


## 찌를 포물선으로 던진다. 착수하면 끝난다.
func cast_to(target: Vector3) -> void:
	show_gear(true)
	_bobber.visible = true
	_line.visible = true
	_bobber_out = true
	_floating = false
	_dip = 0.0
	_dip_target = 0.0
	_shake = 0.0
	var from: Vector3 = tip_position()
	var tw: Tween = create_tween()
	tw.tween_method(func(k: float) -> void:
		var p: Vector3 = from.lerp(target, k)
		p.y += sin(k * PI) * 1.4
		_bobber.global_position = p, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_float_base = target
	_floating = true
	spawn_ripple(target, 0.9, 1.1)


## 가짜 입질: 찌가 톡 하고 살짝 잠긴다.
func nibble() -> void:
	_dip_target = 0.035
	spawn_ripple(_float_base, 0.45, 0.7)
	await get_tree().create_timer(0.16).timeout
	_dip_target = 0.0


## 진짜 입질: 찌가 쑥 잠기고 떨린다.
func bite() -> void:
	_dip_target = 0.14
	_shake = 1.0
	spawn_ripple(_float_base, 1.2, 0.9)
	await get_tree().create_timer(0.25).timeout
	if _floating:
		spawn_ripple(_float_base, 0.8, 0.7)


## 결과 연출. 잡았으면 물고기가 딸려 올라온다.
func reel(caught: bool, size_cm: int = 20) -> void:
	_floating = false
	_shake = 0.0
	var from: Vector3 = _bobber.global_position
	if caught:
		var s: float = clampf(size_cm / 20.0, 0.6, 3.0)
		_fish.scale = Vector3.ONE * s
		_fish.visible = true
		spawn_ripple(from, 1.4, 1.0)
	var tw: Tween = create_tween()
	var dur: float = 0.7 if caught else 0.45
	tw.tween_method(func(k: float) -> void:
		var to: Vector3 = tip_position() + Vector3(0.0, -0.35, 0.0)
		var p: Vector3 = from.lerp(to, k)
		p.y += sin(k * PI) * (0.9 if caught else 0.3)
		_bobber.global_position = p, 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	if caught:
		await get_tree().create_timer(0.9).timeout
	_fish.visible = false
	show_gear(false)


func spawn_ripple(at: Vector3, size: float, duration: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = RIPPLE_SHADER
	quad.material = mat
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)
	mi.global_position = at + Vector3(0.0, 0.02, 0.0)
	mi.scale = Vector3.ONE * 0.1
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"fade", v), 1.0, 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)


# ---------- 매 프레임 ----------

func _process(delta: float) -> void:
	_t += delta
	if _floating:
		_dip = lerpf(_dip, _dip_target, 1.0 - exp(-18.0 * delta))
		_shake = maxf(0.0, _shake - delta * 0.6)
		var bob: float = sin(_t * 2.1) * 0.012 + sin(_t * 3.7) * 0.005
		var jitter: Vector3 = Vector3(sin(_t * 41.0), 0.0, cos(_t * 37.0)) * 0.012 * _shake
		_bobber.global_position = _float_base + Vector3(0.0, bob - _dip, 0.0) + jitter
	if _bobber_out:
		_draw_line()
	if _fish.visible:
		_fish.global_position = _bobber.global_position + Vector3(0.0, -0.12 * _fish.scale.x, 0.0)
		_fish.rotation.z = sin(_t * 18.0) * 0.5


func _draw_line() -> void:
	var a: Vector3 = tip_position()
	var b: Vector3 = _bobber.global_position
	var sag: float = 0.08 + a.distance_to(b) * 0.04
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 13:
		var k: float = i / 12.0
		var p: Vector3 = a.lerp(b, k)
		p.y -= sin(k * PI) * sag
		_line_mesh.surface_add_vertex(_line.to_local(p))
	_line_mesh.surface_end()


# ---------- 생성 ----------

func _build_rod() -> void:
	_pivot = Node3D.new()
	_pivot.name = "RodPivot"
	add_child(_pivot)
	_pivot.position = grip_offset
	_pivot.rotation_degrees = Vector3(-rod_tilt_deg, 0.0, 0.0)
	var rod: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.006
	cyl.bottom_radius = 0.016
	cyl.height = ROD_LENGTH
	cyl.radial_segments = 6
	cyl.rings = 1
	cyl.material = _flat_material(Color(0.45, 0.30, 0.18))
	rod.mesh = cyl
	rod.position = Vector3(0.0, ROD_LENGTH * 0.5, 0.0)
	_pivot.add_child(rod)
	var grip: MeshInstance3D = MeshInstance3D.new()
	var g: CylinderMesh = CylinderMesh.new()
	g.top_radius = 0.02
	g.bottom_radius = 0.022
	g.height = 0.25
	g.radial_segments = 8
	g.rings = 1
	g.material = _flat_material(Color(0.25, 0.18, 0.12))
	grip.mesh = g
	grip.position = Vector3(0.0, 0.12, 0.0)
	_pivot.add_child(grip)


func _build_bobber() -> void:
	_bobber = Node3D.new()
	_bobber.name = "Bobber"
	_bobber.top_level = true
	add_child(_bobber)
	_bobber.scale = Vector3.ONE * bobber_scale
	var top: MeshInstance3D = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.035
	sph.height = 0.07
	sph.radial_segments = 10
	sph.rings = 5
	sph.material = _flat_material(Color(0.92, 0.22, 0.18))
	top.mesh = sph
	top.position = Vector3(0.0, 0.025, 0.0)
	_bobber.add_child(top)
	var bottom: MeshInstance3D = MeshInstance3D.new()
	var s2: SphereMesh = SphereMesh.new()
	s2.radius = 0.033
	s2.height = 0.06
	s2.radial_segments = 10
	s2.rings = 5
	s2.material = _flat_material(Color(0.95, 0.95, 0.92))
	bottom.mesh = s2
	bottom.position = Vector3(0.0, -0.01, 0.0)
	_bobber.add_child(bottom)


func _build_line() -> void:
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.name = "Line"
	_line.mesh = _line_mesh
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.92, 0.92, 0.88, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line.material_override = m
	add_child(_line)
	_line.global_transform = Transform3D.IDENTITY


func _build_fish() -> void:
	_fish = MeshInstance3D.new()
	_fish.name = "CaughtFish"
	_fish.top_level = true
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.035
	cap.height = 0.2
	cap.radial_segments = 8
	cap.rings = 2
	var m: StandardMaterial3D = _flat_material(Color(0.62, 0.66, 0.62))
	m.metallic = 0.4
	m.roughness = 0.35
	cap.material = m
	_fish.mesh = cap
	_fish.visible = false
	add_child(_fish)


func _flat_material(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m
