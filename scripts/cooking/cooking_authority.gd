class_name CookingAuthority
extends Node
## 서버 권한 모닥불 굽기 판정.
## 모닥불의 자리(slot)마다 무엇이 올라가 있고 얼마나 익었는지는 서버만 안다.
## 클라이언트는 "올릴래요", "꺼낼래요"만 요청(RPC)하고, 서버가 보낸 자리 상태로 연출한다.
##
## 자리 상태: "empty" → "cooking" → "done" → "burnt"

## 서버 쪽 신호. kind: &"slot" {fire, slot, state, item, player}, &"denied" {player, reason}
signal event(kind: StringName, data: Dictionary)
## 클라이언트 쪽 신호. 연출과 메시지는 이것만 듣는다.
signal client_event(kind: StringName, data: Dictionary)

const FIRE_GROUP: StringName = &"campfire"

@export var data_path: String = "res://data/cooking.json"

var slots_per_fire: int = 3
var cook_time_ms: float = 12000.0
var burn_time_ms: float = 10000.0
var interact_distance: float = 2.2

var inventory: InventoryAuthority
var _players: Dictionary = {}   # player_id -> Node3D
var _fires: Dictionary = {}     # fire_id -> {node: Node3D, slots: Array[Dictionary]}
var _clock_ms: float = 0.0


func _ready() -> void:
	add_to_group(&"cooking_authority")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if typeof(parsed) == TYPE_DICTIONARY:
		var d: Dictionary = parsed
		slots_per_fire = int(d.get("slots_per_fire", slots_per_fire))
		cook_time_ms = float(d.get("cook_time_s", 12.0)) * 1000.0
		burn_time_ms = float(d.get("burn_time_s", 10.0)) * 1000.0
		interact_distance = float(d.get("interact_distance_m", interact_distance))
	else:
		push_error("CookingAuthority: 데이터를 읽지 못했다: %s" % data_path)
	event.connect(_relay)


# ---------- 서버: 등록 ----------

func register_fires() -> void:
	for n: Node in get_tree().get_nodes_in_group(FIRE_GROUP):
		var id: String = n.name
		var slots: Array = []
		for i in slots_per_fire:
			slots.append(_empty_slot())
		_fires[id] = {"node": n, "slots": slots}


func register_player(player_id: int, body: Node3D) -> void:
	_players[player_id] = body
	# 늦게 들어온 사람에게 지금 모닥불 상태를 전부 보낸다.
	if multiplayer.has_multiplayer_peer():
		rpc_full_state.rpc_id(player_id, _snapshot())


func unregister_player(player_id: int) -> void:
	_players.erase(player_id)


func _empty_slot() -> Dictionary:
	return {"state": "empty", "item": "", "player": 0, "start_ms": 0.0}


func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for id: String in _fires:
		var arr: Array = []
		for s: Dictionary in _fires[id]["slots"]:
			arr.append({"state": s["state"], "item": s["item"], "player": s["player"]})
		out[id] = arr
	return out


# ---------- 네트워크 ----------

@rpc("any_peer", "call_local", "reliable")
func rpc_request_put(fire_id: String) -> void:
	if multiplayer.is_server():
		request_put(_sender(), fire_id)


@rpc("any_peer", "call_local", "reliable")
func rpc_request_take(fire_id: String) -> void:
	if multiplayer.is_server():
		request_take(_sender(), fire_id)


@rpc("authority", "call_local", "reliable")
func rpc_client_event(kind: StringName, data: Dictionary) -> void:
	client_event.emit(kind, data)


@rpc("authority", "call_local", "reliable")
func rpc_full_state(snapshot: Dictionary) -> void:
	for fire_id: String in snapshot:
		var arr: Array = snapshot[fire_id]
		for i in arr.size():
			var s: Dictionary = arr[i]
			client_event.emit(&"slot", {"fire": fire_id, "slot": i, "state": s["state"], "item": s["item"], "player": s["player"], "silent": true})


func _sender() -> int:
	var id: int = multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


func _relay(kind: StringName, data: Dictionary) -> void:
	if not multiplayer.has_multiplayer_peer():
		client_event.emit(kind, data)
		return
	if kind == &"denied":
		rpc_client_event.rpc_id(int(data["player"]), kind, data)
	else:
		# 모닥불은 몇 개 안 되고 고정돼 있어서 모두에게 보낸다. 규모가 커지면 관심 영역으로 거른다.
		rpc_client_event.rpc(kind, data)


# ---------- 판정 ----------

func _fire_in_reach(player_id: int, fire_id: String) -> Dictionary:
	var body: Node3D = _players.get(player_id)
	var fire: Dictionary = _fires.get(fire_id, {})
	if body == null or fire.is_empty():
		return {}
	var a: Vector3 = body.global_position
	var b: Vector3 = (fire["node"] as Node3D).global_position
	if Vector2(a.x - b.x, a.z - b.z).length() > interact_distance:
		event.emit(&"denied", {"player": player_id, "reason": "too_far"})
		return {}
	return fire


## 클라이언트 요청: 날 물고기 하나를 이 모닥불에 올린다.
func request_put(player_id: int, fire_id: String) -> void:
	var fire: Dictionary = _fire_in_reach(player_id, fire_id)
	if fire.is_empty():
		return
	var slot_idx: int = -1
	for i in fire["slots"].size():
		if fire["slots"][i]["state"] == "empty":
			slot_idx = i
			break
	if slot_idx < 0:
		event.emit(&"denied", {"player": player_id, "reason": "full"})
		return
	var item: String = inventory.take_first(player_id, InventoryAuthority.is_raw_fish)
	if item == "":
		event.emit(&"denied", {"player": player_id, "reason": "no_fish"})
		return
	fire["slots"][slot_idx] = {"state": "cooking", "item": item, "player": player_id, "start_ms": _clock_ms}
	_emit_slot(fire_id, slot_idx)


## 클라이언트 요청: 익은(또는 탄) 것을 하나 꺼낸다. 내 것 먼저, 없으면 아무거나.
func request_take(player_id: int, fire_id: String) -> void:
	var fire: Dictionary = _fire_in_reach(player_id, fire_id)
	if fire.is_empty():
		return
	var pick: int = -1
	for own_first in [true, false]:
		for i in fire["slots"].size():
			var s: Dictionary = fire["slots"][i]
			if s["state"] in ["done", "burnt"] and (not own_first or int(s["player"]) == player_id):
				pick = i
				break
		if pick >= 0:
			break
	if pick < 0:
		event.emit(&"denied", {"player": player_id, "reason": "nothing_ready"})
		return
	var s: Dictionary = fire["slots"][pick]
	var got: String = "burnt" if s["state"] == "burnt" else "cooked:" + String(s["item"])
	inventory.add(player_id, got)
	fire["slots"][pick] = _empty_slot()
	_emit_slot(fire_id, pick, {"taken_by": player_id, "got": got})


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_clock_ms += delta * 1000.0
	for fire_id: String in _fires:
		var slots: Array = _fires[fire_id]["slots"]
		for i in slots.size():
			var s: Dictionary = slots[i]
			var elapsed: float = _clock_ms - float(s["start_ms"])
			if s["state"] == "cooking" and elapsed >= cook_time_ms:
				s["state"] = "done"
				_emit_slot(fire_id, i)
			elif s["state"] == "done" and elapsed >= cook_time_ms + burn_time_ms:
				s["state"] = "burnt"
				_emit_slot(fire_id, i)


func _emit_slot(fire_id: String, slot_idx: int, extra: Dictionary = {}) -> void:
	var s: Dictionary = _fires[fire_id]["slots"][slot_idx]
	var data: Dictionary = {"fire": fire_id, "slot": slot_idx, "state": s["state"], "item": s["item"], "player": s["player"]}
	data.merge(extra)
	event.emit(&"slot", data)


## 클라이언트가 "지금 꺼낼 게 있나"를 판단할 때 쓰는 복제 상태. 서버에선 진짜 상태.
func has_ready_slot_hint(fire_node: Node) -> bool:
	return fire_node.has_method(&"has_ready_slot") and fire_node.has_ready_slot()
