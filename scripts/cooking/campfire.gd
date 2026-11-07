class_name Campfire
extends Node3D
## 모닥불 (연출 + 간단한 충돌). 판정은 CookingAuthority가 한다.
## 그룹 "campfire"에 속하고, 노드 이름이 모닥불 ID다. 서버와 클라이언트 양쪽 씬에 있다.
## 클라이언트는 CookingAuthority.client_event로 자리 상태를 받아 생선 색과 연기를 바꾼다.

## 꼬치 세 개가 땅에 꽂히는 자리 (불 중심 기준 각도, 도). 플레이어가 오는 쪽(+Z)에 모아 둔다.
const SKEWER_ANGLES: Array[float] = [-40.0, 0.0, 40.0]
const SKEWER_FOOT_RADIUS: float = 0.62
const SKEWER_LENGTH: float = 0.95
const SKEWER_LEAN_DEG: float = 52.0

## 자리별 상태. CookingAuthority 설정과 같은 개수여야 한다 (register 때 맞춘다).
var slot_states: Array[String] = ["empty", "empty", "empty"]

var _skewers: Array[Node3D] = []       # 꼬치 자리(pivot). 막대와 생선이 이 아래에 붙는다. 비어 있으면 숨긴다.
var _fish: Array = [null, null, null]  # FishModel 또는 null
## 익는 정도 연출용 시계. 서버 시간과 정확히 같을 필요는 없다 (색만 바뀐다).
var _slot_t0: Array[float] = [0.0, 0.0, 0.0]
var _slot_cook_ms: Array[float] = [12000.0, 12000.0, 12000.0]
var _slot_burn_ms: Array[float] = [10000.0, 10000.0, 10000.0]
var _light: OmniLight3D
var _smoke: CPUParticles3D
var _burnt_smoke: CPUParticles3D
var _sizzles: Array[CPUParticles3D] = []
var _t: float = 0.0


func _ready() -> void:
	add_to_group(&"campfire")
	_build_collision()
	if Net.is_dedicated():
		set_process(false)
		return
	_build_logs()
	_build_fire()
	_build_skewers()
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
	_slot_cook_ms[i] = float(data.get("cook_ms", 12000.0))
	_slot_burn_ms[i] = float(data.get("burn_ms", 10000.0))
	# 서버가 알려 준 경과 시간만큼 앞당겨서, 늦게 봐도 색이 맞게.
	_slot_t0[i] = Time.get_ticks_msec() - float(data.get("elapsed_ms", 0.0))
	_apply_slot(i, String(data.get("item", "")), int(data.get("size_cm", 20)))


func _apply_slot(i: int, item: String, size_cm: int = 20) -> void:
	if i >= _skewers.size():
		return
	var state: String = slot_states[i]
	if state == "empty":
		if _fish[i] != null:
			(_fish[i] as Node).queue_free()
			_fish[i] = null
		_skewers[i].visible = false
	elif _fish[i] == null:
		# 꼬치는 꽂을 때 생긴다. 땅에서 쑥 올라오는 짧은 연출.
		var pivot: Node3D = _skewers[i]
		pivot.visible = true
		pivot.scale = Vector3(1.0, 0.05, 1.0)
		var tw: Tween = pivot.create_tween()
		tw.tween_property(pivot, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# 잡은 크기대로. 멀리서도 보이게 1.3배, 너무 작거나 크지 않게.
		var length: float = clampf(size_cm / 100.0 * 1.3, 0.18, 0.62)
		var fish: FishModel = FishModel.create(item, length)
		# 꼬치를 따라 비스듬히, 머리가 위로 가게 꽂힌다.
		fish.position = Vector3(0.0, SKEWER_LENGTH * 0.62, 0.0)
		fish.rotation = Vector3(0.0, 0.0, PI / 2.0)
		_skewers[i].add_child(fish)
		_fish[i] = fish
	_burnt_smoke.emitting = slot_states.has("burnt")
	for k in _sizzles.size():
		_sizzles[k].emitting = slot_states[k] == "cooking" or slot_states[k] == "done"


func _doneness(i: int) -> float:
	var elapsed: float = Time.get_ticks_msec() - _slot_t0[i]
	match slot_states[i]:
		"cooking":
			return clampf(elapsed / _slot_cook_ms[i], 0.0, 0.98)
		"done":
			return 1.0 + clampf((elapsed - _slot_cook_ms[i]) / _slot_burn_ms[i], 0.0, 0.85)
		"burnt":
			return 2.0
	return 0.0


func _process(delta: float) -> void:
	_t += delta
	# 불빛 흔들림
	_light.light_energy = 0.4 + sin(_t * 9.0) * 0.05 + sin(_t * 23.0) * 0.03
	# 꼬치 위 생선: 색만 서서히 변한다. 꽂힌 채로 움직이면 징그러워서 흔들지 않는다.
	for i in _skewers.size():
		var fish: FishModel = _fish[i]
		if fish != null:
			fish.doneness = _doneness(i)


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
	# 겉불: 주황, 세로로 긴 불꽃 잎
	var fire: CPUParticles3D = CPUParticles3D.new()
	fire.amount = 22
	fire.lifetime = 0.6
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.12
	fire.direction = Vector3.UP
	fire.spread = 8.0
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 0.55
	fire.gravity = Vector3(0.0, 0.5, 0.0)
	fire.scale_amount_min = 0.7
	fire.scale_amount_max = 1.0
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.7))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.05))
	fire.scale_amount_curve = curve
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.62, 0.15, 0.6))
	grad.set_color(1, Color(0.75, 0.12, 0.02, 0.0))
	grad.add_point(0.5, Color(0.98, 0.35, 0.06, 0.45))
	fire.color_ramp = grad
	fire.mesh = _billboard_quad(0.2, true, 1.9)
	fire.position = Vector3(0.0, 0.16, 0.0)
	add_child(fire)

	# 심지: 밝은 노랑, 작고 낮게
	var core: CPUParticles3D = CPUParticles3D.new()
	core.amount = 12
	core.lifetime = 0.4
	core.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	core.emission_sphere_radius = 0.07
	core.direction = Vector3.UP
	core.spread = 6.0
	core.initial_velocity_min = 0.25
	core.initial_velocity_max = 0.45
	core.gravity = Vector3(0.0, 0.4, 0.0)
	core.scale_amount_min = 0.6
	core.scale_amount_max = 0.9
	core.scale_amount_curve = curve
	var cg: Gradient = Gradient.new()
	cg.set_color(0, Color(1.0, 0.95, 0.7, 0.75))
	cg.set_color(1, Color(1.0, 0.7, 0.2, 0.0))
	core.color_ramp = cg
	core.mesh = _billboard_quad(0.14, true, 1.6)
	core.position = Vector3(0.0, 0.14, 0.0)
	add_child(core)

	# 불티: 드문드문 튀어 오르는 작은 점
	var ember: CPUParticles3D = CPUParticles3D.new()
	ember.amount = 10
	ember.lifetime = 1.6
	ember.explosiveness = 0.0
	ember.randomness = 0.8
	ember.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ember.emission_sphere_radius = 0.12
	ember.direction = Vector3.UP
	ember.spread = 25.0
	ember.initial_velocity_min = 0.6
	ember.initial_velocity_max = 1.2
	ember.gravity = Vector3(0.3, -0.4, 0.0)
	ember.damping_min = 0.6
	ember.damping_max = 1.2
	ember.scale_amount_min = 0.12
	ember.scale_amount_max = 0.22
	var eg: Gradient = Gradient.new()
	eg.set_color(0, Color(1.0, 0.8, 0.4, 1.0))
	eg.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	ember.color_ramp = eg
	ember.mesh = _billboard_quad(0.1, true)
	ember.position = Vector3(0.0, 0.25, 0.0)
	add_child(ember)


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
	_light.light_energy = 0.4
	_light.omni_range = 2.8
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 0.5, 0.0)
	add_child(_light)


func _build_skewers() -> void:
	var wood: StandardMaterial3D = _flat(Color(0.52, 0.40, 0.26))
	for i in SKEWER_ANGLES.size():
		var a: float = deg_to_rad(SKEWER_ANGLES[i])
		# 발치는 불 바깥, 끝은 불 쪽으로 기울어 불 위에 걸린다.
		var foot: Vector3 = Vector3(sin(a) * SKEWER_FOOT_RADIUS, 0.0, cos(a) * SKEWER_FOOT_RADIUS)
		var pivot: Node3D = Node3D.new()
		pivot.position = foot
		# 꼬치의 +Y가 막대 방향. 불 중심(원점) 쪽으로 눕힌다.
		pivot.look_at_from_position(foot, Vector3.ZERO, Vector3.UP)
		# look_at 뒤 -Z가 불 쪽. X축으로 음의 각만큼 돌리면 +Y(막대)가 -Z(불) 쪽으로 눕는다.
		pivot.rotate_object_local(Vector3.RIGHT, -deg_to_rad(90.0 - SKEWER_LEAN_DEG))
		add_child(pivot)
		var stick: MeshInstance3D = MeshInstance3D.new()
		var c: CylinderMesh = CylinderMesh.new()
		c.top_radius = 0.008
		c.bottom_radius = 0.013
		c.height = SKEWER_LENGTH
		c.radial_segments = 5
		c.rings = 1
		c.material = wood
		stick.mesh = c
		stick.position = Vector3(0.0, SKEWER_LENGTH * 0.5, 0.0)
		pivot.add_child(stick)
		pivot.visible = false  # 꽂을 때만 보인다
		_skewers.append(pivot)
		# 생선 자리에서 튀는 기름방울
		var sz: CPUParticles3D = CPUParticles3D.new()
		sz.amount = 6
		sz.lifetime = 0.45
		sz.emitting = false
		sz.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		sz.emission_sphere_radius = 0.06
		sz.direction = Vector3.UP
		sz.spread = 40.0
		sz.initial_velocity_min = 0.25
		sz.initial_velocity_max = 0.6
		sz.gravity = Vector3(0.0, -1.5, 0.0)
		sz.scale_amount_min = 0.12
		sz.scale_amount_max = 0.22
		var sg: Gradient = Gradient.new()
		sg.set_color(0, Color(1.0, 0.92, 0.65, 1.0))
		sg.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
		sz.color_ramp = sg
		sz.mesh = _billboard_quad(0.1, true)
		sz.position = Vector3(0.0, SKEWER_LENGTH * 0.62, 0.0)
		pivot.add_child(sz)
		_sizzles.append(sz)


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


func _billboard_quad(size: float, additive: bool, tall: float = 1.0) -> QuadMesh:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size * tall)
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
