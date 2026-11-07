class_name Campfire
extends Node3D
## 모닥불 (연출 + 간단한 충돌). 판정은 CookingAuthority가 한다.
## 그룹 "campfire"에 속하고, 노드 이름이 모닥불 ID다. 서버와 클라이언트 양쪽 씬에 있다.
## 클라이언트는 CookingAuthority.client_event로 자리 상태를 받아 생선 색과 연기를 바꾼다.

const FISH_RAW: Color = Color(0.70, 0.74, 0.70)
const FISH_COOKED: Color = Color(0.78, 0.52, 0.24)
const FISH_BURNT: Color = Color(0.13, 0.09, 0.07)

## 자리별 상태. CookingAuthority 설정과 같은 개수여야 한다 (register 때 맞춘다).
var slot_states: Array[String] = ["empty", "empty", "empty"]

var _fish: Array[MeshInstance3D] = []
var _fish_mats: Array[StandardMaterial3D] = []
var _light: OmniLight3D
var _smoke: CPUParticles3D
var _burnt_smoke: CPUParticles3D
var _sizzle: CPUParticles3D
var _t: float = 0.0


func _ready() -> void:
	add_to_group(&"campfire")
	_build_collision()
	if Net.is_dedicated():
		set_process(false)
		return
	_build_logs()
	_build_fire()
	_build_grill()
	var auth: CookingAuthority = get_tree().get_first_node_in_group(&"cooking_authority")
	if auth:
		auth.client_event.connect(_on_event)


func has_ready_slot() -> bool:
	for s: String in slot_states:
		if s == "done" or s == "burnt":
			return true
	return false


func has_empty_slot() -> bool:
	return slot_states.has("empty")


func _on_event(kind: StringName, data: Dictionary) -> void:
	if kind != &"slot" or String(data["fire"]) != name:
		return
	var i: int = int(data["slot"])
	if i >= slot_states.size():
		return
	slot_states[i] = String(data["state"])
	_apply_slot(i)


func _apply_slot(i: int) -> void:
	if i >= _fish.size():
		return
	var state: String = slot_states[i]
	_fish[i].visible = state != "empty"
	match state:
		"cooking":
			_fish_mats[i].albedo_color = FISH_RAW
		"done":
			_fish_mats[i].albedo_color = FISH_COOKED
		"burnt":
			_fish_mats[i].albedo_color = FISH_BURNT
	_burnt_smoke.emitting = slot_states.has("burnt")
	_sizzle.emitting = slot_states.has("cooking") or slot_states.has("done")


func _process(delta: float) -> void:
	_t += delta
	# 불빛 흔들림
	_light.light_energy = 0.55 + sin(_t * 9.0) * 0.07 + sin(_t * 23.0) * 0.04
	# 익는 중인 생선은 지글지글 떨린다
	for i in _fish.size():
		if slot_states[i] == "cooking" or slot_states[i] == "done":
			_fish[i].position.y = 0.47 + sin(_t * 21.0 + i * 2.0) * 0.006
			_fish[i].rotation.z = sin(_t * 17.0 + i) * 0.05


# ---------- 생성 ----------

func _build_collision() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = 0.6
	shape.shape = cyl
	shape.position = Vector3(0.0, 0.3, 0.0)
	body.add_child(shape)
	add_child(body)


func _build_logs() -> void:
	var wood: StandardMaterial3D = _flat(Color(0.36, 0.24, 0.14))
	for i in 4:
		var log_mesh: MeshInstance3D = MeshInstance3D.new()
		var c: CylinderMesh = CylinderMesh.new()
		c.top_radius = 0.05
		c.bottom_radius = 0.06
		c.height = 0.7
		c.radial_segments = 6
		c.rings = 1
		c.material = wood
		log_mesh.mesh = c
		log_mesh.rotation = Vector3(deg_to_rad(80.0), i * TAU / 4.0 + 0.4, 0.0)
		log_mesh.position = Vector3(0.0, 0.12, 0.0)
		add_child(log_mesh)
	var stone: StandardMaterial3D = _flat(Color(0.45, 0.44, 0.42))
	for i in 8:
		var s: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.14
		sm.radial_segments = 8
		sm.rings = 4
		sm.material = stone
		s.mesh = sm
		var a: float = i * TAU / 8.0
		s.position = Vector3(cos(a) * 0.5, 0.05, sin(a) * 0.5)
		s.scale = Vector3(1.0, 0.8, 1.2)
		add_child(s)


func _build_fire() -> void:
	var fire: CPUParticles3D = CPUParticles3D.new()
	fire.amount = 36
	fire.lifetime = 0.8
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.14
	fire.direction = Vector3.UP
	fire.spread = 12.0
	fire.initial_velocity_min = 0.6
	fire.initial_velocity_max = 1.1
	fire.gravity = Vector3(0.0, 0.8, 0.0)
	fire.scale_amount_min = 0.5
	fire.scale_amount_max = 0.9
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.1))
	fire.scale_amount_curve = curve
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.35, 1.0))
	grad.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	grad.add_point(0.45, Color(1.0, 0.45, 0.1, 0.9))
	fire.color_ramp = grad
	fire.mesh = _billboard_quad(0.22, true)
	fire.position = Vector3(0.0, 0.18, 0.0)
	add_child(fire)

	_sizzle = CPUParticles3D.new()
	_sizzle.amount = 10
	_sizzle.lifetime = 0.5
	_sizzle.emitting = false
	_sizzle.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sizzle.emission_box_extents = Vector3(0.25, 0.02, 0.12)
	_sizzle.direction = Vector3.UP
	_sizzle.spread = 35.0
	_sizzle.initial_velocity_min = 0.3
	_sizzle.initial_velocity_max = 0.7
	_sizzle.gravity = Vector3(0.0, -1.5, 0.0)
	_sizzle.scale_amount_min = 0.15
	_sizzle.scale_amount_max = 0.3
	var sg: Gradient = Gradient.new()
	sg.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	sg.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
	_sizzle.color_ramp = sg
	_sizzle.mesh = _billboard_quad(0.1, true)
	_sizzle.position = Vector3(0.0, 0.48, 0.0)
	add_child(_sizzle)

	_smoke = CPUParticles3D.new()
	_smoke.amount = 8
	_smoke.lifetime = 2.6
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.1
	_smoke.direction = Vector3.UP
	_smoke.spread = 10.0
	_smoke.initial_velocity_min = 0.5
	_smoke.initial_velocity_max = 0.8
	_smoke.gravity = Vector3(0.15, 0.25, 0.0)
	_smoke.scale_amount_min = 0.5
	_smoke.scale_amount_max = 0.8
	var sc: Curve = Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(1.0, 1.6))
	_smoke.scale_amount_curve = sc
	var smog: Gradient = Gradient.new()
	smog.set_color(0, Color(0.55, 0.55, 0.55, 0.22))
	smog.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
	_smoke.color_ramp = smog
	_smoke.mesh = _billboard_quad(0.35, false)
	_smoke.position = Vector3(0.0, 0.7, 0.0)
	add_child(_smoke)

	# 탄 생선이 있을 때만 나오는 짙은 연기
	_burnt_smoke = _smoke.duplicate()
	_burnt_smoke.amount = 18
	_burnt_smoke.emitting = false
	_burnt_smoke.initial_velocity_min = 0.8
	_burnt_smoke.initial_velocity_max = 1.2
	var bg: Gradient = Gradient.new()
	bg.set_color(0, Color(0.2, 0.18, 0.17, 0.6))
	bg.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	_burnt_smoke.color_ramp = bg
	_burnt_smoke.position = Vector3(0.0, 0.55, 0.0)
	add_child(_burnt_smoke)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.65, 0.3)
	_light.light_energy = 0.55
	_light.omni_range = 3.2
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 0.5, 0.0)
	add_child(_light)


func _build_grill() -> void:
	var bar_mat: StandardMaterial3D = _flat(Color(0.2, 0.2, 0.22))
	bar_mat.metallic = 0.6
	bar_mat.roughness = 0.5
	for i in 2:
		var bar: MeshInstance3D = MeshInstance3D.new()
		var c: CylinderMesh = CylinderMesh.new()
		c.top_radius = 0.012
		c.bottom_radius = 0.012
		c.height = 0.75
		c.radial_segments = 5
		c.rings = 1
		c.material = bar_mat
		bar.mesh = c
		bar.rotation.z = PI / 2.0
		bar.position = Vector3(0.0, 0.42, -0.1 + i * 0.2)
		add_child(bar)
	for i in 3:
		var f: MeshInstance3D = MeshInstance3D.new()
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.055
		cap.height = 0.3
		cap.radial_segments = 8
		cap.rings = 2
		var m: StandardMaterial3D = _flat(FISH_RAW)
		cap.material = m
		f.mesh = cap
		f.rotation = Vector3(PI / 2.0, 0.0, 0.0)
		f.position = Vector3(-0.24 + i * 0.24, 0.47, 0.0)
		f.visible = false
		add_child(f)
		_fish.append(f)
		_fish_mats.append(m)


static var _soft_dot: GradientTexture2D


## 가운데가 밝고 가장자리로 투명해지는 원. 파티클이 네모로 보이지 않게.
static func _soft_dot_texture() -> GradientTexture2D:
	if _soft_dot == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.8))
		_soft_dot = GradientTexture2D.new()
		_soft_dot.gradient = g
		_soft_dot.fill = GradientTexture2D.FILL_RADIAL
		_soft_dot.fill_from = Vector2(0.5, 0.5)
		_soft_dot.fill_to = Vector2(0.5, 0.0)
		_soft_dot.width = 64
		_soft_dot.height = 64
	return _soft_dot


func _billboard_quad(size: float, additive: bool) -> QuadMesh:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _soft_dot_texture()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	q.material = m
	return q


func _flat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m
