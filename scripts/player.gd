extends CharacterBody3D
## 플레이어. 이동은 서버가 확정한다 (server-authoritative).
## 노드 이름 = 접속 ID(peer id). 서버가 만들고 MultiplayerSpawner가 클라이언트에 복제한다.
##
## 역할별 동작:
## - 서버(전용/호스트): 받은 입력으로 움직이고, 결과를 server_pos 등에 써서 내보낸다.
## - 내 캐릭터(클라이언트): 입력을 서버로 보내면서 똑같이 미리 움직여 본다(예측). 서버 위치와 어긋나면 천천히 맞춘다.
## - 남의 캐릭터(클라이언트): 서버 위치를 부드럽게 따라간다.

const SPEED: float = 1.5
const ACCELERATION: float = 24.0
const TURN_SPEED: float = 12.0

## _Soft 변형은 tools/soften_animations.gd 로 생성. 원본을 쓰려면 "Idle", "Walk".
const ANIM_IDLE: StringName = &"Idle_Soft"
const ANIM_WALK: StringName = &"Walk_Soft"
## Walk 애니메이션이 1배속일 때의 실제 전진 속도(m/s). 이동 속도에 맞춰 재생 속도를 비례시켜 발 미끄러짐을 줄인다.
const WALK_ANIM_SPEED: float = 0.85

## 예측 보정: 서버 위치와 이만큼 넘게 어긋나면 바로 맞춘다(m).
const SNAP_DISTANCE: float = 1.5
## 움직이는 중에는 이만큼까지의 차이는 지연 탓으로 보고 건드리지 않는다(m).
const MOVING_TOLERANCE: float = 0.5

## KayKit처럼 손 슬롯에 무기·방패 메시가 붙어 오는 모델용. 켜면 몸 파츠(Body/Head/Arm/Leg)만 남긴다.
@export var strip_equipment: bool = false
const BODY_PART_SUFFIXES: PackedStringArray = ["_Body", "_Head", "_ArmLeft", "_ArmRight", "_LegLeft", "_LegRight"]

## 몸 파츠 중에서도 추가로 숨길 것 (투구, 망토 등). 모델마다 인스펙터에서 조정.
@export var hidden_parts: PackedStringArray = []

## 옷 색 변형 팔레트 (색상환 회전량, 바퀴 단위). 0번은 원래 색. 서버가 비어 있는 가장 작은 번호를 준다.
## 셰이더(YIQ 회전)는 값이 커질수록 빨강→보라→파랑→청록→초록→노랑→주황으로 돈다.
## 원래 드레스가 빨강이라: 0=빨강, 0.35=파랑, 0.60=초록, 0.16=보라, 0.90=주황, 0.47=청록.
const CLOTH_HUES: Array[float] = [0.0, 0.35, 0.60, 0.16, 0.90, 0.47]

# ---- 서버 → 클라이언트 동기화 (Sync 노드가 복제) ----
## 머리 위 이름. 서버가 다듬어서 확정한다.
var display_name: String = "":
	set(value):
		display_name = value
		if is_node_ready():
			_apply_name()
## 옷 색 번호 (CLOTH_HUES 인덱스).
var color_variant: int = 0:
	set(value):
		color_variant = value
		if is_node_ready():
			_apply_color()
var server_pos: Vector3 = Vector3.ZERO
var server_rot_y: float = 0.0
var net_speed: float = 0.0

## 서버가 거는 이동 잠금 (낚시 중 등). 서버에서만 의미가 있다.
var server_locked: bool = false
## 화면 쪽 이동 잠금. 낚시 연출 중에는 입력을 안 받고 애니메이션도 행동 쪽이 정한다.
var input_locked: bool = false:
	set(value):
		input_locked = value
		if not value:
			_action_anim = &""
## 개발용 자동 조작이 넣는 입력. null이면 키보드를 읽는다.
var input_override: Variant = null

var _remote_input: Vector2 = Vector2.ZERO
## 클라이언트가 마지막으로 서버에 보낸 입력과 그 뒤 지난 시간. 바뀔 때와 일정 간격으로만 보낸다.
var _sent_input: Vector2 = Vector2(INF, INF)
var _since_sent: float = 0.0
## 입력이 그대로여도 이 간격(초)마다 한 번은 다시 보낸다. 패킷이 빠져도 서버가 곧 따라잡게.
const INPUT_RESEND_INTERVAL: float = 0.2
var _action_anim: StringName = &""

## 애니메이션은 모델과 분리된 공용 라이브러리(Quaternius UAL, 휴머노이드 리타겟)를 쓴다.
## 모델 쪽 스켈레톤이 %GeneralSkeleton 이름으로 임포트돼 있어야 한다.
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _model: Node3D = $Model
@onready var _name_tag: Label3D = $NameTag


func peer_id() -> int:
	return name.to_int()


func is_local() -> bool:
	return multiplayer.has_multiplayer_peer() and peer_id() == multiplayer.get_unique_id()


func _ready() -> void:
	if strip_equipment:
		_strip_equipment()
	if Net.is_dedicated():
		# 전용 서버는 보는 사람이 없다. 모델·애니메이션·스프링본 계산을 끄고 위치와 충돌만 판정한다.
		_model.visible = false
		_model.process_mode = Node.PROCESS_MODE_DISABLED
		_anim.active = false
		_name_tag.visible = false
		return
	_anim.play(ANIM_IDLE)
	_apply_name()
	_apply_color()
	if not multiplayer.is_server():
		# 스폰 시점의 서버 위치로 시작한다.
		global_position = server_pos
		rotation.y = server_rot_y


func _apply_name() -> void:
	_name_tag.text = display_name
	_name_tag.visible = display_name != ""


## 이름에 CLOTH가 들어간 재질만 색상환을 돌린다. 재질은 모델끼리 공유되므로 이 캐릭터용으로 복제해서 쓴다.
func _apply_color() -> void:
	var hue: float = CLOTH_HUES[posmod(color_variant, CLOTH_HUES.size())]
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.get_surface_override_material(i)
			if mat == null:
				var base: Material = mi.mesh.surface_get_material(i)
				if not (base is ShaderMaterial and String(base.resource_name).contains("CLOTH")):
					continue
				mat = base.duplicate()
				if mat.next_pass:
					mat.next_pass = mat.next_pass.duplicate()
				mi.set_surface_override_material(i, mat)
			var m: Material = mat
			while m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter(&"_WellbornHueShift", hue)
				m = m.next_pass


func _strip_equipment() -> void:
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		var is_body: bool = false
		for suffix in BODY_PART_SUFFIXES:
			if mesh_node.name.ends_with(suffix) or mesh_node.name.contains(suffix + "_"):
				is_body = true
				break
		mesh_node.visible = is_body and not hidden_parts.has(mesh_node.name)


## 클라이언트 → 서버: 이번 프레임 이동 입력.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(dir: Vector2) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id():
		return  # 남의 캐릭터를 조종하려는 요청은 버린다.
	_remote_input = dir.limit_length(1.0)


func _physics_process(delta: float) -> void:
	var local_input: Vector2 = _read_local_input() if is_local() else Vector2.ZERO
	if multiplayer.is_server():
		var dir: Vector2 = local_input if is_local() else _remote_input
		if server_locked:
			dir = Vector2.ZERO
		_simulate(dir, delta)
		server_pos = global_position
		server_rot_y = rotation.y
		net_speed = Vector2(velocity.x, velocity.z).length()
	elif is_local():
		_since_sent += delta
		if local_input != _sent_input or _since_sent >= INPUT_RESEND_INTERVAL:
			submit_input.rpc_id(1, local_input)
			_sent_input = local_input
			_since_sent = 0.0
		_simulate(local_input, delta)
		_reconcile(local_input, delta)
	else:
		_follow_server(delta)
	_update_animation()


## 키 입력을 카메라가 보는 방향 기준의 월드 방향으로 바꾼다. 서버는 이 월드 방향만 받는다.
func _read_local_input() -> Vector2:
	if input_locked:
		return Vector2.ZERO
	if input_override != null:
		return input_override  # 봇은 월드 방향을 직접 준다.
	var raw: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if raw == Vector2.ZERO:
		return raw
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or not cam.has_method(&"camera_yaw"):
		return raw
	# 카메라 yaw가 0이면 카메라는 +Z에서 -Z를 본다. "앞"(raw.y=-1)이 -Z가 되도록 돌린다.
	return raw.rotated(-cam.camera_yaw())


func _simulate(input_dir: Vector2, delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)
	var target_velocity: Vector3 = direction * SPEED
	velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta)
	if direction.length_squared() > 0.0:
		var target_angle: float = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)
	move_and_slide()


## 내 캐릭터: 예측한 위치를 서버 위치 쪽으로 보정한다.
func _reconcile(input_dir: Vector2, delta: float) -> void:
	var error: Vector3 = server_pos - global_position
	error.y = 0.0
	var dist: float = error.length()
	if dist > SNAP_DISTANCE:
		global_position = Vector3(server_pos.x, global_position.y, server_pos.z)
	elif input_dir == Vector2.ZERO or dist > MOVING_TOLERANCE:
		global_position += error * (1.0 - exp(-6.0 * delta))


## 남의 캐릭터: 서버 위치·방향을 부드럽게 따라간다.
func _follow_server(delta: float) -> void:
	var k: float = 1.0 - exp(-14.0 * delta)
	global_position = global_position.lerp(server_pos, k)
	rotation.y = lerp_angle(rotation.y, server_rot_y, k)


## 행동 애니메이션을 한 번 재생하고, 끝나면 대기로 돌아간다. 이동 잠금 중에만 의미가 있다.
func play_action(anim_name: StringName) -> void:
	if not _anim.has_animation(anim_name):
		return
	_action_anim = anim_name
	_anim.speed_scale = 1.0
	_anim.play(anim_name, 0.15)
	_anim.queue(ANIM_IDLE)


func _update_animation() -> void:
	if not _anim.active:
		return
	if input_locked:
		_anim.speed_scale = 1.0
		if _action_anim != &"" and _anim.current_animation != _action_anim:
			_action_anim = &""
		if _action_anim == &"" and _anim.current_animation != ANIM_IDLE:
			_anim.play(ANIM_IDLE, 0.25)
		return
	var horizontal_speed: float = net_speed if not (multiplayer.is_server() or is_local()) else Vector2(velocity.x, velocity.z).length()
	var wanted: StringName = ANIM_WALK if horizontal_speed > 0.1 else ANIM_IDLE
	if _anim.current_animation != wanted:
		_anim.play(wanted, 0.2)
	_anim.speed_scale = clampf(horizontal_speed / WALK_ANIM_SPEED, 0.8, 2.2) if wanted == ANIM_WALK else 1.0
