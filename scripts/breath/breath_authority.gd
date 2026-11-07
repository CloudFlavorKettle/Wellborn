class_name BreathAuthority
extends Node
## 서버 권한 숨. 플레이어마다 숨(0~max)을 돌리고, 먹기 요청을 판정한다.
## 1단계: 숨이 0이어도 아무 일도 없다. 혼자면 천천히 줄고, 모닥불 곁·사람 곁이면 찬다. 먹으면 찬다.
## 값은 주인에게만 1초마다(또는 크게 바뀔 때) 보낸다.

## 서버 쪽. kind: &"ate" {player, item, gain, breath}, &"denied" {player, reason}
signal event(kind: StringName, data: Dictionary)
## 클라이언트 쪽. &"ate", &"denied", &"breath" {player, breath, max}
signal client_event(kind: StringName, data: Dictionary)

@export var data_path: String = "res://data/breath.json"

var max_breath: float = 100.0
var start_breath: float = 70.0
var drain_per_s: float = 2.0 / 60.0
var regen_fire_per_s: float = 6.0 / 60.0
var regen_others_per_s: float = 3.0 / 60.0
var fire_radius: float = 3.0
var others_radius: float = 4.0
var food_cooked_base: float = 20.0
var food_cooked_per_cm: float = 0.5
var food_burnt: float = 6.0

var inventory: InventoryAuthority
var _players: Dictionary = {}   # player_id -> Node3D
var _breath: Dictionary = {}    # player_id -> float
var _last_sent: Dictionary = {} # player_id -> int
var _send_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"breath_authority")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if typeof(parsed) == TYPE_DICTIONARY:
		var d: Dictionary = parsed
		max_breath = float(d.get("max", 100))
		start_breath = float(d.get("start", 70))
		drain_per_s = float(d.get("drain_per_min", 2.0)) / 60.0
		regen_fire_per_s = float(d.get("regen_near_fire_per_min", 6.0)) / 60.0
		regen_others_per_s = float(d.get("regen_near_others_per_min", 3.0)) / 60.0
		fire_radius = float(d.get("fire_radius_m", 3.0))
		others_radius = float(d.get("others_radius_m", 4.0))
		var food: Dictionary = d.get("food", {})
		food_cooked_base = float(food.get("cooked_base", 20))
		food_cooked_per_cm = float(food.get("cooked_per_cm", 0.5))
		food_burnt = float(food.get("burnt", 6))
	else:
		push_error("BreathAuthority: 데이터를 읽지 못했다: %s" % data_path)
	event.connect(_relay)


# ---------- 서버 ----------

func register_player(player_id: int, body: Node3D) -> void:
	_players[player_id] = body
	_breath[player_id] = start_breath
	_send(player_id, true)


func unregister_player(player_id: int) -> void:
	_players.erase(player_id)
	_breath.erase(player_id)
	_last_sent.erase(player_id)


func breath_of(player_id: int) -> float:
	return float(_breath.get(player_id, 0.0))


static func is_food(item: Dictionary) -> bool:
	var id: String = item.get("id", "")
	return id.begins_with("cooked:") or id == "burnt"


## 클라이언트 요청: 가방에서 먹을 것 하나를 먹는다 (구운 것 먼저, 없으면 탄 것).
func request_eat(player_id: int) -> void:
	if not _players.has(player_id):
		return
	var item: Dictionary = inventory.take_first(player_id, func(it: Dictionary) -> bool: return String(it.get("id", "")).begins_with("cooked:"))
	if item.is_empty():
		item = inventory.take_first(player_id, func(it: Dictionary) -> bool: return it.get("id", "") == "burnt")
	if item.is_empty():
		var has_raw: bool = not inventory.items_of(player_id).filter(InventoryAuthority.is_raw_fish).is_empty()
		event.emit(&"denied", {"player": player_id, "reason": "raw_only" if has_raw else "no_food"})
		return
	var gain: float = food_burnt if item["id"] == "burnt" else food_cooked_base + food_cooked_per_cm * float(item.get("size_cm", 20))
	var before: float = _breath[player_id]
	_breath[player_id] = minf(max_breath, before + gain)
	event.emit(&"ate", {"player": player_id, "item": item["id"], "gain": int(round(_breath[player_id] - before)), "breath": _breath[player_id], "max": max_breath})
	_send(player_id, true)


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var fires: Array = get_tree().get_nodes_in_group(&"campfire")
	for pid: int in _players.keys():
		var body: Node3D = _players[pid]
		var p: Vector3 = body.global_position
		var rate: float = -drain_per_s
		for f: Node in fires:
			if (f as Node3D).global_position.distance_to(p) <= fire_radius:
				rate += drain_per_s + regen_fire_per_s
				break
		for other: int in _players.keys():
			if other != pid and (_players[other] as Node3D).global_position.distance_to(p) <= others_radius:
				rate += regen_others_per_s
				break
		_breath[pid] = clampf(_breath[pid] + rate * delta, 0.0, max_breath)
	_send_timer += delta
	if _send_timer >= 1.0:
		_send_timer = 0.0
		for pid: int in _players.keys():
			_send(pid, false)


func _send(player_id: int, force: bool) -> void:
	var v: int = int(round(_breath[player_id]))
	if not force and _last_sent.get(player_id, -1) == v:
		return
	_last_sent[player_id] = v
	var data: Dictionary = {"player": player_id, "breath": v, "max": int(max_breath)}
	if multiplayer.has_multiplayer_peer():
		rpc_client_event.rpc_id(player_id, &"breath", data)
	else:
		client_event.emit(&"breath", data)


# ---------- 네트워크 ----------

@rpc("any_peer", "call_local", "reliable")
func rpc_request_eat() -> void:
	if multiplayer.is_server():
		var id: int = multiplayer.get_remote_sender_id()
		request_eat(id if id != 0 else multiplayer.get_unique_id())


@rpc("authority", "call_local", "reliable")
func rpc_client_event(kind: StringName, data: Dictionary) -> void:
	client_event.emit(kind, data)


func _relay(kind: StringName, data: Dictionary) -> void:
	if not multiplayer.has_multiplayer_peer():
		client_event.emit(kind, data)
		return
	rpc_client_event.rpc_id(int(data["player"]), kind, data)
