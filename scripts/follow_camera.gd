extends Camera3D
## 대상 뒤 위에서 부드럽게 따라가는 카메라. 마우스 휠로 거리 조절.

@export var target: Node3D
@export var offset: Vector3 = Vector3(0.0, 1.6, 3.0)
@export var look_height: float = 1.0
@export var smoothing: float = 8.0
@export var zoom_min: float = 0.5
@export var zoom_max: float = 3.0
@export var zoom_step: float = 0.1

var _zoom: float = 1.0


func _ready() -> void:
	if target != null:
		global_position = target.global_position + offset * _zoom


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
	var desired: Vector3 = target.global_position + offset * _zoom
	var weight: float = 1.0 - exp(-smoothing * delta)
	global_position = global_position.lerp(desired, weight)
	look_at(target.global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)
