extends Camera3D
## 자유 회전 3인칭 카메라.
## - 마우스 오른쪽 버튼을 누른 채 움직이면 대상 주위를 돈다 (좌우·위아래).
## - 휠로 거리 조절.
## - 대상을 부드럽게 따라간다. 자동으로 뒤로 돌아가지 않는다.
## - set_focus()로 관심 지점(예: 낚시 찌)을 주면 시선이 그쪽으로 조금 기운다.
## 이동 방향은 player.gd가 이 카메라의 yaw를 읽어 정한다 (camera_yaw()).

@export var target: Node3D
## 바라보는 높이 (대상 발 기준).
@export var look_height: float = 1.0
## 기본 거리와 휠 한 칸당 변화.
@export var distance: float = 3.4
@export var distance_min: float = 1.2
@export var distance_max: float = 9.0
@export var zoom_step: float = 0.4
## 마우스 1픽셀당 회전 각(도).
@export var sensitivity: float = 0.22
## 위아래 각 범위(도). 음수가 아래에서 올려다보는 쪽.
@export var pitch_min: float = -15.0
@export var pitch_max: float = 70.0
## 시작 각도(도). pitch는 위에서 내려다보는 정도.
@export var start_yaw: float = 0.0
@export var start_pitch: float = 18.0
## 대상을 따라가는 부드러움. 클수록 빨리 붙는다.
@export var smoothing: float = 10.0
## 시선이 대상(0)과 관심 지점(1) 사이 어디를 볼지.
@export_range(0.0, 1.0) var focus_look_blend: float = 0.45

var _yaw: float = 0.0
var _pitch: float = 0.0
var _dragging: bool = false
var _anchor: Vector3 = Vector3.ZERO
var _focus: Vector3 = Vector3.ZERO
var _has_focus: bool = false
var _focus_w: float = 0.0


func _ready() -> void:
	_yaw = deg_to_rad(start_yaw)
	_pitch = deg_to_rad(start_pitch)
	snap_to_target()


## 대상 위치로 즉시 붙는다. 캐릭터가 막 생겼을 때 쓴다.
func snap_to_target() -> void:
	if target == null:
		return
	_anchor = target.global_position + Vector3(0.0, look_height, 0.0)
	_apply()


## 카메라가 보는 수평 방향(라디안). 이동 입력을 월드 방향으로 바꿀 때 쓴다.
func camera_yaw() -> float:
	return _yaw


func set_focus(point: Vector3) -> void:
	_focus = point
	_has_focus = true


func clear_focus() -> void:
	_has_focus = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_set_dragging(mb.pressed)
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					distance = maxf(distance_min, distance - zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					distance = minf(distance_max, distance + zoom_step)
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		_yaw = wrapf(_yaw - mm.relative.x * deg_to_rad(sensitivity), -PI, PI)
		_pitch = clampf(_pitch + mm.relative.y * deg_to_rad(sensitivity), deg_to_rad(pitch_min), deg_to_rad(pitch_max))


func _set_dragging(on: bool) -> void:
	if _dragging == on:
		return
	_dragging = on
	# 드래그 중엔 커서를 숨기고 창 안에 가둔다. 놓으면 원래 자리로.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	# 창에서 포커스가 빠지면 드래그 상태를 풀어 커서가 갇힌 채로 남지 않게.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _dragging:
		_set_dragging(false)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var head: Vector3 = target.global_position + Vector3(0.0, look_height, 0.0)
	_anchor = _anchor.lerp(head, 1.0 - exp(-smoothing * delta))
	_focus_w = move_toward(_focus_w, 1.0 if _has_focus else 0.0, delta * 1.5)
	_apply()


func _apply() -> void:
	var dir: Vector3 = Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch))
	global_position = _anchor + dir * distance
	var w: float = smoothstep(0.0, 1.0, _focus_w)
	look_at(_anchor.lerp(_focus, focus_look_blend * w), Vector3.UP)
