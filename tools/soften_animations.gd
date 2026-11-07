extends SceneTree
## Quaternius UAL 애니메이션에서 팔 스윙·다리 벌림을 줄인 변형(Idle_Soft, Walk_Soft)을 만들어
## res://assets/quaternius/ual/ual_animations.res 에 추가한다.
##
## 실행 (에디터 닫고):
##   Godot_console.exe --headless --path . --script res://tools/soften_animations.gd
##
## soften(anim, skel, arm_k, leg_k): k=1.0이면 원본 그대로, 0.0이면 완전히 고정.
##   팔 = 트랙 평균 자세 쪽으로 섞음(스윙 폭만 감소), 다리 = rest(곧게 선 자세) 쪽으로 섞음(보폭·벌림 감소).
const ARM_BONES: Array = ["LeftShoulder", "RightShoulder", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand"]
const LEG_BONES: Array = ["LeftUpperLeg", "RightUpperLeg"]
## 척추: rest(곧게 선 자세) 쪽으로 섞어 앞으로 숙인 상체를 세운다.
const SPINE_BONES: Array = ["Spine", "Chest", "UpperChest", "Neck"]

func soften(src: Animation, skel: Skeleton3D, arm_k: float, leg_k: float, spine_k: float = 1.0) -> Animation:
	var a: Animation = src.duplicate(true)
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D: continue
		var bone: String = String(a.track_get_path(t)).get_slice(":", 1)
		var k: float = -1.0
		if ARM_BONES.has(bone): k = arm_k
		elif LEG_BONES.has(bone): k = leg_k
		elif SPINE_BONES.has(bone): k = spine_k
		if k < 0.0: continue
		var bi: int = skel.find_bone(bone)
		var target: Quaternion
		if LEG_BONES.has(bone) or SPINE_BONES.has(bone):
			# 다리·척추는 rest(곧게 선 자세) 쪽으로 → 보폭·벌림·숙임 감소
			target = skel.get_bone_rest(bi).basis.get_rotation_quaternion()
		else:
			# 팔은 트랙 평균 자세 쪽으로 → 스윙 폭만 감소, 팔 위치는 유지
			target = a.track_get_key_value(t, 0)
			for key in range(1, a.track_get_key_count(t)):
				target = target.slerp(a.track_get_key_value(t, key), 1.0 / float(key + 1))
		for key in a.track_get_key_count(t):
			var q: Quaternion = a.track_get_key_value(t, key)
			a.track_set_key_value(t, key, target.slerp(q, k))
	return a

func _init() -> void:
	var inst: Node = (load("res://assets/quaternius/ual/UAL1_Standard.glb") as PackedScene).instantiate()
	var skel: Skeleton3D = inst.find_child("GeneralSkeleton", true, false)
	var lib: AnimationLibrary = load("res://assets/quaternius/ual/ual_animations.res")
	var walk_soft: Animation = soften(lib.get_animation("Walk"), skel, 0.45, 0.75, 0.35)
	var idle_soft: Animation = soften(lib.get_animation("Idle"), skel, 1.0, 0.5, 0.25)
	walk_soft.resource_name = "Walk_Soft"; idle_soft.resource_name = "Idle_Soft"
	if lib.has_animation("Walk_Soft"): lib.remove_animation("Walk_Soft")
	if lib.has_animation("Idle_Soft"): lib.remove_animation("Idle_Soft")
	lib.add_animation("Walk_Soft", walk_soft); lib.add_animation("Idle_Soft", idle_soft)
	print("save err=", ResourceSaver.save(lib, "res://assets/quaternius/ual/ual_animations.res"), " count=", lib.get_animation_list().size())
	inst.free()
	quit()
