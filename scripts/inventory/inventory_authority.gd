class_name InventoryAuthority
extends Node
## 서버 권한 가방. 누가 무엇을 몇 개 가졌는지는 서버만 안다.
## 클라이언트는 자기 가방 내용만 받아서 보여 준다 (RPC로 통째로 보냄. 1단계는 물건이 몇 개 안 된다).
##
## 물건 하나 = Dictionary {"id": String, "size_cm": int}. 크기는 낚은 물고기의 것이 익힌 뒤에도 따라간다.
## id 규칙 (1단계):
##   "<fish_id>"         날 물고기 (data/fish.json의 id)
##   "cooked:<fish_id>"  구운 물고기
##   "burnt"             탄 생선

## 서버 쪽: 가방이 바뀌었다.
signal changed(player_id: int, items: Array)
## 클라이언트 쪽: 내 가방 내용.
signal local_changed(items: Array)

@export var fish_data_path: String = "res://data/fish.json"

var _bags: Dictionary = {}       # player_id -> Array[String]
var _fish_names: Dictionary = {}  # fish_id -> 이름


func _ready() -> void:
	add_to_group(&"inventory_authority")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(fish_data_path))
	if typeof(parsed) == TYPE_DICTIONARY:
		for table: Variant in (parsed as Dictionary).values():
			if typeof(table) != TYPE_ARRAY:
				continue  # "_comment" 같은 문자열 항목은 건너뛴다.
			for f: Dictionary in table:
				_fish_names[f["id"]] = f["name"]


# ---------- 서버 ----------

func register_player(player_id: int) -> void:
	_bags[player_id] = []
	_push(player_id)


func unregister_player(player_id: int) -> void:
	_bags.erase(player_id)


func add(player_id: int, item: Dictionary) -> void:
	if not _bags.has(player_id):
		return
	_bags[player_id].append(item)
	_push(player_id)


## 조건에 맞는 첫 물건을 꺼낸다. 없으면 빈 Dictionary.
func take_first(player_id: int, predicate: Callable) -> Dictionary:
	var bag: Array = _bags.get(player_id, [])
	for i in bag.size():
		if predicate.call(bag[i]):
			var item: Dictionary = bag[i]
			bag.remove_at(i)
			_push(player_id)
			return item
	return {}


func items_of(player_id: int) -> Array:
	return _bags.get(player_id, []).duplicate()


func _push(player_id: int) -> void:
	var items: Array = _bags[player_id]
	changed.emit(player_id, items)
	if multiplayer.has_multiplayer_peer():
		rpc_bag.rpc_id(player_id, items)
	else:
		local_changed.emit(items)


# ---------- 클라이언트 ----------

@rpc("authority", "call_local", "reliable")
func rpc_bag(items: Array) -> void:
	local_changed.emit(items)


# ---------- 이름 ----------

static func is_raw_fish(item: Dictionary) -> bool:
	var id: String = item.get("id", "")
	return not id.begins_with("cooked:") and id != "burnt"


func item_name(item: String) -> String:
	if item == "burnt":
		return "탄 생선"
	if item.begins_with("cooked:"):
		return "구운 " + String(_fish_names.get(item.trim_prefix("cooked:"), "생선"))
	return String(_fish_names.get(item, item))


## 가방 내용을 "이름 ×개수" 줄들로.
func describe(items: Array) -> String:
	var counts: Dictionary = {}
	var order: Array = []
	for item: Dictionary in items:
		var id: String = item.get("id", "")
		if not counts.has(id):
			order.append(id)
		counts[id] = int(counts.get(id, 0)) + 1
	var lines: PackedStringArray = []
	for id: String in order:
		lines.append("%s ×%d" % [item_name(id), counts[id]])
	return "\n".join(lines)
