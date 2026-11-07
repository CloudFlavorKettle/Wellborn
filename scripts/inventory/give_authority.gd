class_name GiveAuthority
extends Node
## 서버 권한 건네기. 가까이 있는 다른 플레이어에게 가방 물건 하나를 준다.
## 거리·가방 확인은 서버만 한다. 주는 순서: 구운 것 → 날것 → 탄 것 (상대가 바로 먹거나 구울 수 있는 것 먼저).

## 서버 쪽. kind: &"gave" {player, to, item}, &"received" {player, from, item}, &"denied" {player, reason}
signal event(kind: StringName, data: Dictionary)
## 클라이언트 쪽 (해당 플레이어에게만).
signal client_event(kind: StringName, data: Dictionary)

@export var give_distance: float = 2.5

var inventory: InventoryAuthority
var _players: Dictionary = {}  # player_id -> Node3D


func _ready() -> void:
	add_to_group(&"give_authority")
	event.connect(_relay)


func register_player(player_id: int, body: Node3D) -> void:
	_players[player_id] = body


func unregister_player(player_id: int) -> void:
	_players.erase(player_id)


static func _give_priority(item: Dictionary) -> int:
	var id: String = item.get("id", "")
	if id.begins_with("cooked:"):
		return 0
	if id == "burnt":
		return 2
	return 1


func request_give(player_id: int, target_id: int) -> void:
	var giver: Node3D = _players.get(player_id)
	var taker: Node3D = _players.get(target_id)
	if giver == null or taker == null or player_id == target_id:
		return
	if giver.global_position.distance_to(taker.global_position) > give_distance:
		event.emit(&"denied", {"player": player_id, "reason": "too_far"})
		return
	var items: Array = inventory.items_of(player_id)
	if items.is_empty():
		event.emit(&"denied", {"player": player_id, "reason": "empty"})
		return
	var best: int = 99
	for it: Dictionary in items:
		best = mini(best, _give_priority(it))
	var item: Dictionary = inventory.take_first(player_id, func(it: Dictionary) -> bool: return _give_priority(it) == best)
	if item.is_empty():
		return
	inventory.add(target_id, item)
	if giver.has_method(&"face_toward"):
		giver.face_toward(taker.global_position)
	if taker.has_method(&"face_toward"):
		taker.face_toward(giver.global_position)
	var giver_name: String = String(giver.get(&"display_name"))
	var taker_name: String = String(taker.get(&"display_name"))
	event.emit(&"gave", {"player": player_id, "to": target_id, "to_name": taker_name, "item": item["id"]})
	event.emit(&"received", {"player": target_id, "from": player_id, "from_name": giver_name, "item": item["id"]})


# ---------- 네트워크 ----------

@rpc("any_peer", "call_local", "reliable")
func rpc_request_give(target_id: int) -> void:
	if multiplayer.is_server():
		var id: int = multiplayer.get_remote_sender_id()
		request_give(id if id != 0 else multiplayer.get_unique_id(), target_id)


@rpc("authority", "call_local", "reliable")
func rpc_client_event(kind: StringName, data: Dictionary) -> void:
	client_event.emit(kind, data)


func _relay(kind: StringName, data: Dictionary) -> void:
	if not multiplayer.has_multiplayer_peer():
		client_event.emit(kind, data)
		return
	rpc_client_event.rpc_id(int(data["player"]), kind, data)
