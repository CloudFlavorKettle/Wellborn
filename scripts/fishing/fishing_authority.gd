class_name FishingAuthority
extends Node
## 서버 권한 낚시 판정.
## 클라이언트는 "던지기", "챔질"을 요청만 하고, 던질 수 있는지·언제 입질하는지·성공했는지·무슨 물고기인지는 전부 여기서 정한다.
## 지금은 같은 프로세스 안의 노드지만, 네트워크가 붙으면 이 노드는 서버에서만 돈다.
## event 시그널이 나중에 RPC로 바뀐다.

## kind: &"cast_ok" {target}, &"cast_denied" {reason}, &"nibble" {}, &"bite" {window_ms},
##       &"result" {outcome: "caught"|"early"|"late", fish_id, name, size_cm}
signal event(player_id: int, kind: StringName, data: Dictionary)

enum State { WAITING, BITE }

const WATER_GROUP: StringName = &"fishing_water"

@export var fish_data_path: String = "res://data/fish.json"
@export var fish_table: String = "lake"
## 수면 높이. 찌가 이 높이에 뜬다.
@export var water_surface_y: float = -0.15
## 플레이어에서 찌까지 허용 거리(수평).
@export var max_cast_distance: float = 7.0
## 첫 가짜 입질/진짜 입질까지 기다리는 시간(초). 기다림이 이 게임의 핵심이다.
@export var first_wait_s: Vector2 = Vector2(2.5, 6.0)
## 가짜 입질 사이 간격(초).
@export var nibble_gap_s: Vector2 = Vector2(0.9, 2.4)
## 진짜 입질 전에 오는 가짜 입질 횟수 범위.
@export var nibble_count: Vector2i = Vector2i(0, 3)
## 네트워크 지연 보정. 판정 창이 끝난 뒤 이만큼 늦게 도착한 챔질도 인정한다.
@export var latency_allowance_ms: int = 150
## 0이면 무작위. 테스트에서 고정할 때 쓴다.
@export var rng_seed: int = 0

var _players: Dictionary = {}   # player_id -> Node3D
var _sessions: Dictionary = {}  # player_id -> Dictionary
var _fish: Array = []
var _total_weight: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 서버 시계(ms). 물리 프레임마다 흐른다.
var _clock_ms: float = 0.0


func _ready() -> void:
	add_to_group(&"fishing_authority")
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_load_fish()


func _load_fish() -> void:
	var text: String = FileAccess.get_file_as_string(fish_data_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has(fish_table):
		push_error("FishingAuthority: 물고기 데이터를 읽지 못했다: %s [%s]" % [fish_data_path, fish_table])
		return
	_fish = parsed[fish_table]
	_total_weight = 0
	for f: Dictionary in _fish:
		_total_weight += int(f["weight"])


func register_player(player_id: int, body: Node3D) -> void:
	_players[player_id] = body


func unregister_player(player_id: int) -> void:
	_players.erase(player_id)
	_sessions.erase(player_id)


func is_fishing(player_id: int) -> bool:
	return _sessions.has(player_id)


## 클라이언트 요청: 이 지점으로 찌를 던지고 싶다.
func request_cast(player_id: int, target: Vector3) -> void:
	var body: Node3D = _players.get(player_id)
	if body == null:
		return
	if _sessions.has(player_id):
		event.emit(player_id, &"cast_denied", {"reason": "busy"})
		return
	var flat: Vector2 = Vector2(target.x - body.global_position.x, target.z - body.global_position.z)
	if flat.length() > max_cast_distance:
		event.emit(player_id, &"cast_denied", {"reason": "too_far"})
		return
	var surface: Vector3 = Vector3(target.x, water_surface_y, target.z)
	if not _is_water(surface):
		event.emit(player_id, &"cast_denied", {"reason": "not_water"})
		return
	if _fish.is_empty():
		event.emit(player_id, &"cast_denied", {"reason": "no_fish"})
		return

	_sessions[player_id] = {
		"state": State.WAITING,
		"target": surface,
		"fish": _pick_fish(),
		"nibbles_left": _rng.randi_range(nibble_count.x, nibble_count.y),
		"next_ms": _clock_ms + _rng.randf_range(first_wait_s.x, first_wait_s.y) * 1000.0,
		"bite_end_ms": 0.0,
	}
	event.emit(player_id, &"cast_ok", {"target": surface})


## 클라이언트 요청: 지금 챔질한다.
func request_hook(player_id: int) -> void:
	var s: Dictionary = _sessions.get(player_id, {})
	if s.is_empty():
		return
	if s["state"] == State.WAITING:
		_finish(player_id, "early")
	elif _clock_ms <= float(s["bite_end_ms"]) + latency_allowance_ms:
		_finish(player_id, "caught")
	else:
		_finish(player_id, "late")


func _physics_process(delta: float) -> void:
	_clock_ms += delta * 1000.0
	for player_id: int in _sessions.keys():
		var s: Dictionary = _sessions[player_id]
		if s["state"] == State.WAITING and _clock_ms >= float(s["next_ms"]):
			if int(s["nibbles_left"]) > 0:
				s["nibbles_left"] = int(s["nibbles_left"]) - 1
				s["next_ms"] = _clock_ms + _rng.randf_range(nibble_gap_s.x, nibble_gap_s.y) * 1000.0
				event.emit(player_id, &"nibble", {})
			else:
				var window: int = int(s["fish"]["bite_window_ms"])
				s["state"] = State.BITE
				s["bite_end_ms"] = _clock_ms + window
				event.emit(player_id, &"bite", {"window_ms": window})
		elif s["state"] == State.BITE and _clock_ms > float(s["bite_end_ms"]) + latency_allowance_ms:
			_finish(player_id, "late")


func _finish(player_id: int, outcome: String) -> void:
	var s: Dictionary = _sessions[player_id]
	_sessions.erase(player_id)
	var data: Dictionary = {"outcome": outcome}
	if outcome == "caught":
		var f: Dictionary = s["fish"]
		data["fish_id"] = f["id"]
		data["name"] = f["name"]
		data["size_cm"] = _rng.randi_range(int(f["size_cm"][0]), int(f["size_cm"][1]))
	event.emit(player_id, &"result", data)


func _pick_fish() -> Dictionary:
	var roll: int = _rng.randi_range(1, _total_weight)
	for f: Dictionary in _fish:
		roll -= int(f["weight"])
		if roll <= 0:
			return f
	return _fish[0]


func _is_water(point: Vector3) -> bool:
	var world: World3D = get_viewport().find_world_3d()
	var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	q.position = point + Vector3(0.0, -0.05, 0.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for hit: Dictionary in world.direct_space_state.intersect_point(q, 8):
		var c: Object = hit.get("collider")
		if c is Node and (c as Node).is_in_group(WATER_GROUP):
			return true
	return false
