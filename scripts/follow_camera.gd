extends Camera3D
## 대상 뒤 위에서 부드럽게 따라가는 카메라. 마우스 휠로 거리 조절.
## set_focus()로 관심 지점(예: 낚시 찌)을 주면, 대상과 그 지점이 함께 보이도록 살짝 옆·위로 비켜서 본다.

@export var target: Node3D
@export var offset: Vector3 = Vector3(0.0, 1.6, 3.0)
@export var look_height: float = 1.0
@export var smoothing: float = 8.0
@export var zoom_min: float = 0.5
@export var zoom_max: float = 3.0
@export var zoom_step: float = 0.1
## 관심 지점이 있을 때 카메라가 추가로 비켜서는 양 (대상 기준, 월드 축).
@export var focus_offset: Vector3 = Vector3(1.1, 0.9, 0.6)
## 시선이 대상(0)과 관심 지점(1) 사이 어디를 볼지.
@export_range(0.0, 1.0) var focus_look_blend: float = 0.55

var _zoom: float = 1.0
var _focus: Vector3 = Vector3.ZERO
var _has_focus: bool = false
var _focus_w: float = 0.0


func _ready() -> void:
	if target != null:
		global_position = target.global_position + offset * _zoom


func set_focus(point: Vector3) -> void:
	_focus = point
	_has_focus = true


func clear_focus() -> void:
	_has_focus = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(zoom_min, _zoom - zoom_step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(zoom_max, _zoom + zoom_step)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_focus_w = move_toward(_focus_w, 1.0 if _has_focus else 0.0, delta * 1.5)
	var w: float = smoothstep(0.0, 1.0, _focus_w)
	var desired: Vector3 = target.global_position + offset * _zoom + focus_offset * w
	var weight: float = 1.0 - exp(-smoothing * delta)
	global_position = global_position.lerp(desired, weight)
	var head: Vector3 = target.global_position + Vector3(0.0, look_height, 0.0)
	look_at(head.lerp(_focus, focus_look_blend * w), Vector3.UP)
