class_name InteractController
extends Node
## 내 캐릭터의 Space(fish 액션) 한 키를 상황에 따라 나눈다.
## 모닥불 가까이면 굽기(올리기/꺼내기), 아니면 낚시. 화면 아래 상황 안내도 여기서 정한다.
## 플레이어 노드의 자식으로 둔다. 형제로 FishingController가 있어야 한다.

signal message(text: String)
signal context_changed(text: String)

const DENY_TEXT: Dictionary = {
	"too_far": "모닥불에 더 가까이 가야 해요.",
	"full": "모닥불 자리가 다 찼어요.",
	"no_fish": "구울 물고기가 없어요.",
	"nothing_ready": "아직 익은 게 없어요.",
	"no_food": "먹을 게 없어요.",
	"raw_only": "날것은 먹기 힘들어요. 모닥불에 구워 보세요.",
}

var _cooking: CookingAuthority
var _breath: BreathAuthority
var _inventory: InventoryAuthority
var _player: CharacterBody3D
var _fishing: FishingController
var _near_fire: Campfire
var _last_context: String = ""
var _raw_count: int = 0
var _food_name: String = ""


func _ready() -> void:
	_player = get_parent()
	_fishing = _player.get_node("FishingController")
	_cooking = get_tree().get_first_node_in_group(&"cooking_authority")
	_inventory = get_tree().get_first_node_in_group(&"inventory_authority")
	if _cooking:
		_cooking.client_event.connect(_on_cooking_event)
	_breath = get_tree().get_first_node_in_group(&"breath_authority")
	if _breath:
		_breath.client_event.connect(_on_breath_event)
	if _inventory:
		_inventory.local_changed.connect(func(items: Array) -> void:
			_raw_count = items.filter(InventoryAuthority.is_raw_fish).size()
			_food_name = ""
			for it: Dictionary in items:
				if String(it.get("id", "")).begins_with("cooked:"):
					_food_name = _inventory.item_name(it["id"])
					break
			if _food_name == "":
				for it: Dictionary in items:
					if it.get("id", "") == "burnt":
						_food_name = _inventory.item_name("burnt")
						break
			_last_context = "")


func _is_mine() -> bool:
	return _player.has_method(&"is_local") and _player.is_local()


func _unhandled_input(e: InputEvent) -> void:
	if not _is_mine():
		return
	if e.is_action_pressed(&"fish"):
		press()
	elif e.is_action_pressed(&"eat"):
		eat()


## E 한 번. 가방의 먹을 것을 하나 먹는다 (서버가 고른다).
func eat() -> void:
	if _breath:
		_breath.rpc_request_eat.rpc_id(1)


## Space 한 번. 봇도 이걸 부른다.
func press() -> void:
	if _near_fire != null and _cooking != null and _fishing.phase == FishingController.Phase.IDLE:
		if _near_fire.has_ready_slot():
			_cooking.rpc_request_take.rpc_id(1, _near_fire.name)
		else:
			_cooking.rpc_request_put.rpc_id(1, _near_fire.name)
		return
	_fishing.press()


func _physics_process(_delta: float) -> void:
	if not _is_mine():
		return
	_near_fire = _nearest_fire()
	var ctx: String = ""
	if _fishing.phase != FishingController.Phase.IDLE:
		ctx = "찌가 쑥 들어가면 Space!"
	elif _near_fire:
		if _near_fire.has_ready_slot():
			ctx = "Space: 꺼내기"
		elif _raw_count > 0:
			ctx = "Space: 물고기 올리기 (%d마리)" % _raw_count
		else:
			ctx = "구울 물고기가 없어요"
	else:
		ctx = "Space: 낚시"
	if _food_name != "":
		ctx += "\nE: %s 먹기" % _food_name
	if ctx != _last_context:
		_last_context = ctx
		context_changed.emit(ctx)


## 모닥불을 보고 손을 뻗는다. 내 화면에서만 (남에게는 서버 회전과 애니메이션 신호가 간다).
func _gesture() -> void:
	if _near_fire:
		_player.face_toward(_near_fire.global_position)
	_player.play_action(&"Interact")


func _nearest_fire() -> Campfire:
	if _cooking == null:
		return null
	var best: Campfire = null
	var best_d: float = _cooking.interact_distance
	var p: Vector3 = _player.global_position
	for n: Node in get_tree().get_nodes_in_group(&"campfire"):
		var f: Node3D = n
		var d: float = Vector2(f.global_position.x - p.x, f.global_position.z - p.z).length()
		if d <= best_d:
			best_d = d
			best = n
	return best


func _on_breath_event(kind: StringName, data: Dictionary) -> void:
	if not _is_mine() or int(data.get("player", 0)) != _player.peer_id():
		return
	match kind:
		&"ate":
			_player.play_action(&"Interact")
			var n: String = _inventory.item_name(data["item"])
			message.emit("%s%s 먹었어요. 숨 +%d" % [n, FishingController._object_particle(n), int(data["gain"])])
		&"denied":
			message.emit(DENY_TEXT.get(data.get("reason", ""), ""))


func _on_cooking_event(kind: StringName, data: Dictionary) -> void:
	if not _is_mine():
		return
	var me: int = _player.peer_id()
	match kind:
		&"denied":
			if int(data["player"]) == me:
				message.emit(DENY_TEXT.get(data.get("reason", ""), ""))
		&"slot":
			if data.get("silent", false):
				return
			var state: String = data["state"]
			if data.has("taken_by"):
				if int(data["taken_by"]) == me:
					_gesture()
					var got: String = data["got"]
					var n: String = _inventory.item_name(got)
					message.emit("앗, 탔어요…" if got == "burnt" else "%s%s 꺼냈어요." % [n, FishingController._object_particle(n)])
			elif int(data["player"]) == me:
				match state:
					"cooking":
						_gesture()
						var n: String = _inventory.item_name(data["item"])
						message.emit("%s%s 모닥불에 올렸어요." % [n, FishingController._object_particle(n)])
					"done":
						message.emit("다 익었어요! 꺼내세요.")
					"burnt":
						message.emit("타고 있어요!")
