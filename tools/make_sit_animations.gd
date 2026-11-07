extends SceneTree
## Quaternius UAL의 의자 앉기(Sitting_Enter/Idle/Exit)를 땅바닥 앉기(Sit_Ground_Enter / Sit_Ground / Sit_Ground_Exit)로
## 바꿔 res://assets/quaternius/ual/ual_animations.res 에 추가한다.
##
## 실행 (에디터 닫고):
##   Godot_console.exe --headless --path . --script res://tools/make_sit_animations.gd
##
## 바꾸는 것: 엉덩이를 의자 높이에서 땅까지 내리고(앞뒤 위치는 선 자세 자리로), 무릎을 거의 펴서 다리를 앞으로 뻗는다.
## 들어가기·나오기는 엉덩이가 내려간 정도(w)에 비례해서 같은 변형을 건다. 앉은 자세에는 작은 숨쉬기를 넣는다.

const STAND_Y: float = 0.9569
const STAND_Z: float = -0.0944
const CHAIR_Y: float = 0.5907
const CHAIR_Z: float = -0.3616
## 땅에 앉았을 때 엉덩이 높이(m). 허벅지 두께만큼.
const GROUND_Y: float = 0.13
## 무릎을 펴는 정도. 1이면 완전히 곧게, 0이면 의자 앉기 그대로.
const KNEE_STRAIGHTEN: float = 0.72
const LOWER_LEGS: Array = ["LeftLowerLeg", "RightLowerLeg"]
## 허벅지를 들어 올리는 각도(도). 무릎이 살짝 올라와 발이 땅에 닿는다.
const THIGH_LIFT_DEG: float = 12.0
const UPPER_LEGS: Array = ["LeftUpperLeg", "RightUpperLeg"]
## 숨쉬기: 뼈 → 흔들림 각도(도). 주기 BREATH_PERIOD.
const BREATH: Dictionary = {"Spine": 0.8, "Chest": 1.3, "UpperChest": 0.8, "Head": 0.6}
const BREATH_PERIOD: float = 3.4
const BREATH_KEYS: int = 12


func _track(a: Animation, bone: String, type: int) -> int:
	for t in a.get_track_count():
		if a.track_get_type(t) == type and String(a.track_get_path(t)).get_slice(":", 1) == bone:
			return t
	return -1


## 시각 t에서 엉덩이가 얼마나 내려갔나 (0 선 자세 … 1 의자 높이).
func _weight(a: Animation, hips: int, t: float) -> float:
	var y: float = a.position_track_interpolate(hips, t).y
	return clampf((STAND_Y - y) / (STAND_Y - CHAIR_Y), 0.0, 1.0)


func ground(src: Animation, skel: Skeleton3D) -> Animation:
	var a: Animation = src.duplicate(true)
	var hips: int = _track(a, "Hips", Animation.TYPE_POSITION_3D)
	# 무릎: w에 비례해 rest(곧게) 쪽으로
	for bone: String in LOWER_LEGS:
		var t: int = _track(a, bone, Animation.TYPE_ROTATION_3D)
		var rest: Quaternion = skel.get_bone_rest(skel.find_bone(bone)).basis.get_rotation_quaternion()
		for k in a.track_get_key_count(t):
			var w: float = _weight(src, hips, a.track_get_key_time(t, k))
			var q: Quaternion = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, q.slerp(rest, w * KNEE_STRAIGHTEN))
	# 허벅지: w에 비례해 살짝 들어 올림
	for bone: String in UPPER_LEGS:
		var t: int = _track(a, bone, Animation.TYPE_ROTATION_3D)
		for k in a.track_get_key_count(t):
			var w: float = _weight(src, hips, a.track_get_key_time(t, k))
			var q: Quaternion = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, q * Quaternion(Vector3.RIGHT, deg_to_rad(THIGH_LIFT_DEG) * w))
	# 엉덩이: w에 비례해 땅으로, 앞뒤는 선 자리로
	for k in a.track_get_key_count(hips):
		var p: Vector3 = a.track_get_key_value(hips, k)
		var w: float = clampf((STAND_Y - p.y) / (STAND_Y - CHAIR_Y), 0.0, 1.0)
		p.y -= w * (CHAIR_Y - GROUND_Y)
		p.z += w * (STAND_Z - CHAIR_Z)
		a.track_set_key_value(hips, k, p)
	return a


func add_breathing(a: Animation) -> void:
	a.length = BREATH_PERIOD
	for bone: String in BREATH.keys():
		var t: int = _track(a, bone, Animation.TYPE_ROTATION_3D)
		if t < 0:
			continue
		var base: Quaternion = a.track_get_key_value(t, 0)
		while a.track_get_key_count(t) > 0:
			a.track_remove_key(t, 0)
		var amp: float = deg_to_rad(float(BREATH[bone]))
		for i in BREATH_KEYS:
			var ph: float = float(i) / float(BREATH_KEYS)
			var q: Quaternion = base * Quaternion(Vector3.RIGHT, amp * sin(ph * TAU))
			a.rotation_track_insert_key(t, ph * BREATH_PERIOD, q)


func _init() -> void:
	var inst: Node = (load("res://assets/quaternius/ual/UAL1_Standard.glb") as PackedScene).instantiate()
	var skel: Skeleton3D = inst.find_child("GeneralSkeleton", true, false)
	var lib: AnimationLibrary = load("res://assets/quaternius/ual/ual_animations.res")
	var made: Dictionary = {
		"Sit_Ground": ground(lib.get_animation("Sitting_Idle"), skel),
		"Sit_Ground_Enter": ground(lib.get_animation("Sitting_Enter"), skel),
		"Sit_Ground_Exit": ground(lib.get_animation("Sitting_Exit"), skel),
	}
	add_breathing(made["Sit_Ground"])
	for n: String in made.keys():
		var a: Animation = made[n]
		a.resource_name = n
		if lib.has_animation(n):
			lib.remove_animation(n)
		lib.add_animation(n, a)
	print("save err=", ResourceSaver.save(lib, "res://assets/quaternius/ual/ual_animations.res"), " count=", lib.get_animation_list().size())
	inst.free()
	quit()
