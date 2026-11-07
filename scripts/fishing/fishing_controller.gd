class_name FishingController
extends Node
## 클라이언트 쪽 낚시. 모든 플레이어 노드에 붙는다.
## - 누구의 캐릭터든: 서버가 보낸 이벤트(client_event)로 그 사람의 낚싯대·찌·동작을 보여 준다.
## - 내 캐릭터일 때만: 입력을 서버에 요청(RPC)으로 보내고, 메시지와 카메라를 다룬다.
## 여기서는 아무것도 판정하지 않는다. 입질 시점·성공 여부·물고기는 서버가 정한다.
## 플레이어 노드의 자식으로 두고, 형제 노드로 FishingRod와 InteractController가 있어야 한다.

signal message(text: String)

## 앞으로 몇 m 지점에 던질지.
@export var cast_distance: float = 4.5

enum Phase { IDLE, CASTING, WAITING, REELING }

const DENY_TEXT: Dictionary = {
	"not_water": "물가에서 물 쪽을 보고 던져야 해요.",
	"too_far": "너무 멀어요.",
	"busy": "",
	"no_fish": "여긴 물고기가 없는 것 같아요.",
}

var phase: Phase = Phase.IDLE
var _authority: FishingAuthority
var _pending_bite: bool = false

@onready var _player: CharacterBody3D = get_parent()
@onready var _rod: FishingRod = get_parent().get_node("FishingRod")


func _ready() -> void:
	_authority = get_tree().get_first_node_in_group(&"fishing_authority")
	if _authority == null:
		push_warning("FishingController: FishingAuthority가 씬에 없다. 낚시 비활성.")
		return
	_authority.client_event.connect(_on_event)


func _is_mine() -> bool:
	return _player.has_method(&"is_local") and _player.is_local()


## 낚시 버튼 한 번. 키 입력은 InteractController가 받아서 상황에 따라 여기로 넘긴다.
func press() -> void:
	if _authority == null:
		return
	match phase:
		Phase.IDLE:
			var forward: Vector3 = -_player.global_basis.z
			forward.y = 0.0
			_authority.rpc_request_cast.rpc_id(1, _player.global_position + forward.normalized() * cast_distance)
		Phase.CASTING, Phase.WAITING:
			_authority.rpc_request_hook.rpc_id(1)
		_:
			pass


func _on_event(pid: int, kind: StringName, data: Dictionary) -> void:
	if pid != _player.peer_id():
		return
	match kind:
		&"cast_ok":
			phase = Phase.CASTING
			_pending_bite = false
			_player.input_locked = true
			_player.play_action(&"Interact")
			if _is_mine():
				_set_camera_focus(data["target"])
			await _rod.cast_to(data["target"])
			if phase == Phase.CASTING:
				phase = Phase.WAITING
				if _pending_bite:
					_rod.bite()
		&"cast_denied":
			var t: String = DENY_TEXT.get(data.get("reason", ""), "")
			if t != "" and _is_mine():
				message.emit(t)
		&"nibble":
			if phase == Phase.WAITING:
				_rod.nibble()
		&"bite":
			if phase == Phase.WAITING:
				_rod.bite()
			else:
				_pending_bite = true
		&"result":
			await _show_result(data)


func _show_result(data: Dictionary) -> void:
	phase = Phase.REELING
	var outcome: String = data.get("outcome", "")
	if _is_mine():
		match outcome:
			"caught":
				var fish_name: String = data["name"]
				message.emit("%s%s 낚았어요! (%dcm)" % [fish_name, _object_particle(fish_name), int(data["size_cm"])])
			"early":
				message.emit("너무 일렀어요…")
			"late":
				message.emit("놓쳤어요…")
	_player.play_action(&"Interact")
	await _rod.reel(outcome == "caught", int(data.get("size_cm", 20)), String(data.get("fish_id", "")))
	if _is_mine():
		_clear_camera_focus()
	_player.input_locked = false
	phase = Phase.IDLE


func _set_camera_focus(point: Vector3) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam and cam.has_method(&"set_focus"):
		cam.set_focus(point)


func _clear_camera_focus() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam and cam.has_method(&"clear_focus"):
		cam.clear_focus()


## 마지막 글자 받침에 따라 "을"/"를". 한글이 아니면 "을(를)".
static func _object_particle(word: String) -> String:
	if word.is_empty():
		return "을(를)"
	var code: int = word.unicode_at(word.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return "을(를)"
	return "을" if (code - 0xAC00) % 28 != 0 else "를"
