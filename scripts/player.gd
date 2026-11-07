extends CharacterBody3D
## 1단계 임시 플레이어. 바닥 위를 WASD로 걷는다.
## 서버 권한 구조가 들어오면 이 이동 로직은 서버 쪽에서 돌게 된다.

const SPEED: float = 1.5
const ACCELERATION: float = 24.0
const TURN_SPEED: float = 12.0

## _Soft 변형은 tools/soften_animations.gd 로 생성. 원본을 쓰려면 "Idle", "Walk".
const ANIM_IDLE: StringName = &"Idle_Soft"
const ANIM_WALK: StringName = &"Walk_Soft"
## Walk 애니메이션이 1배속일 때의 실제 전진 속도(m/s). 이동 속도에 맞춰 재생 속도를 비례시켜 발 미끄러짐을 줄인다.
const WALK_ANIM_SPEED: float = 0.85

## KayKit처럼 손 슬롯에 무기·방패 메시가 붙어 오는 모델용. 켜면 몸 파츠(Body/Head/Arm/Leg)만 남긴다.
@export var strip_equipment: bool = false
const BODY_PART_SUFFIXES: PackedStringArray = ["_Body", "_Head", "_ArmLeft", "_ArmRight", "_LegLeft", "_LegRight"]

## 몸 파츠 중에서도 추가로 숨길 것 (투구, 망토 등). 모델마다 인스펙터에서 조정.
@export var hidden_parts: PackedStringArray = []

## 애니메이션은 모델과 분리된 공용 라이브러리(Quaternius UAL, 휴머노이드 리타겟)를 쓴다.
## 모델 쪽 스켈레톤이 %GeneralSkeleton 이름으로 임포트돼 있어야 한다.
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _model: Node3D = $Model

## 낚시 같은 행동 중에는 이동 입력을 받지 않는다. 애니메이션도 행동 쪽이 정한다.
var input_locked: bool = false:
	set(value):
		input_locked = value
		if not value:
			_action_anim = &""
var _action_anim: StringName = &""


func _ready() -> void:
	if strip_equipment:
		_strip_equipment()
	_anim.play(ANIM_IDLE)


func _strip_equipment() -> void:
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		var is_body: bool = false
		for suffix in BODY_PART_SUFFIXES:
			if mesh_node.name.ends_with(suffix) or mesh_node.name.contains(suffix + "_"):
				is_body = true
				break
		mesh_node.visible = is_body and not hidden_parts.has(mesh_node.name)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir: Vector2 = Vector2.ZERO
	if not input_locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)
	var target_velocity: Vector3 = direction * SPEED

	velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta)

	if direction.length_squared() > 0.0:
		var target_angle: float = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)

	move_and_slide()
	_update_animation()


## 행동 애니메이션을 한 번 재생하고, 끝나면 대기로 돌아간다. 이동 잠금 중에만 의미가 있다.
func play_action(anim_name: StringName) -> void:
	if not _anim.has_animation(anim_name):
		return
	_action_anim = anim_name
	_anim.speed_scale = 1.0
	_anim.play(anim_name, 0.15)
	_anim.queue(ANIM_IDLE)


func _update_animation() -> void:
	if input_locked:
		_anim.speed_scale = 1.0
		if _action_anim != &"" and _anim.current_animation != _action_anim:
			_action_anim = &""
		if _action_anim == &"" and _anim.current_animation != ANIM_IDLE:
			_anim.play(ANIM_IDLE, 0.25)
		return
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var wanted: StringName = ANIM_WALK if horizontal_speed > 0.1 else ANIM_IDLE
	if _anim.current_animation != wanted:
		_anim.play(wanted, 0.2)
	_anim.speed_scale = clampf(horizontal_speed / WALK_ANIM_SPEED, 0.8, 2.2) if wanted == ANIM_WALK else 1.0
