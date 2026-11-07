extends Node3D
## 월드(메인 씬). 접속을 받고, 플레이어를 만들고, 관심 영역을 관리한다.
## 플레이어 생성·삭제와 관심 영역 판단은 서버만 한다. 클라이언트는 복제된 결과를 받는다.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const DEV_BOT: Script = preload("res://scripts/net/dev_bot.gd")

## 이 거리(m) 안의 플레이어만 서로에게 보낸다. 지금 맵은 작아서 사실상 전원이 보인다.
@export var interest_radius: float = 30.0
## 관심 영역을 다시 계산하는 주기(초).
@export var interest_interval: float = 0.25
## 처음 나타나는 자리. 접속 순서대로 옆으로 조금씩 벌린다.
@export var spawn_origin: Vector3 = Vector3(0.0, 0.0, -3.0)

@onready var _players: Node3D = $Players
@onready var _spawner: MultiplayerSpawner = $PlayerSpawner
@onready var _camera: Camera3D = $Camera3D
@onready var _authority: FishingAuthority = $Server/FishingAuthority
@onready var _toast: Label = get_node_or_null("UI/Toast")
@onready var _hint: Label = get_node_or_null("UI/Hint")

var _interest_timer: float = 0.0
var _spawn_count: int = 0


func _ready() -> void:
	_spawner.spawned.connect(_on_player_node_added)
	if Net.start() != OK:
		_show("서버를 시작하거나 접속하지 못했어요.")
		return
	if multiplayer.is_server():
		if Net.interest_radius_override > 0.0:
			interest_radius = Net.interest_radius_override
			Net.log_line("관심 영역 반경 %.1fm (개발용 인자)" % interest_radius)
		multiplayer.peer_connected.connect(_add_player)
		multiplayer.peer_disconnected.connect(_remove_player)
		_authority.viewers_of = _viewers_of
		if not Net.is_dedicated():
			_add_player(1)
	else:
		multiplayer.connected_to_server.connect(func() -> void: Net.log_line("서버 접속됨"))
		multiplayer.connection_failed.connect(func() -> void:
			Net.log_line("접속 실패")
			_show("서버에 접속하지 못했어요."))
		multiplayer.server_disconnected.connect(func() -> void:
			Net.log_line("서버 연결 끊김")
			_show("서버와 연결이 끊겼어요."))
	if Net.is_dedicated():
		_camera.current = false
		if _hint:
			_hint.visible = false


# ---------- 서버: 플레이어 생성/삭제 ----------

func _add_player(peer: int) -> void:
	var p: CharacterBody3D = PLAYER_SCENE.instantiate()
	p.name = str(peer)
	var offset: float = float(_spawn_count % 4) * 1.2 - 1.8
	_spawn_count += 1
	p.position = spawn_origin + Vector3(offset, 0.0, 0.0)
	p.server_pos = p.position
	# 자기 자신에게는 항상 보인다. 다른 사람에게는 관심 영역 계산이 정한다.
	var sync: MultiplayerSynchronizer = p.get_node("Sync")
	sync.set_visibility_for(peer, true)
	_players.add_child(p, true)
	_authority.register_player(peer, p)
	Net.log_line("플레이어 입장: %d (현재 %d명)" % [peer, _players.get_child_count()])
	_on_player_node_added(p)
	_update_interest()


func _remove_player(peer: int) -> void:
	_authority.unregister_player(peer)
	var p: Node = _players.get_node_or_null(str(peer))
	if p:
		p.queue_free()
	Net.log_line("플레이어 퇴장: %d" % peer)


# ---------- 관심 영역 ----------

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_interest_timer += delta
	if _interest_timer >= interest_interval:
		_interest_timer = 0.0
		_update_interest()


func _update_interest() -> void:
	var list: Array[Node] = _players.get_children()
	for target: Node in list:
		var sync: MultiplayerSynchronizer = target.get_node("Sync")
		for viewer: Node in list:
			if viewer == target:
				continue
			var viewer_peer: int = viewer.name.to_int()
			if viewer_peer == 1:
				continue  # 서버 자신은 복제를 받지 않는다 (호스트도 같은 노드를 직접 본다).
			var see: bool = (viewer as Node3D).global_position.distance_to((target as Node3D).global_position) <= interest_radius
			if sync.get_visibility_for(viewer_peer) != see:
				sync.set_visibility_for(viewer_peer, see)


## 이 플레이어를 볼 수 있는 접속 ID들 (낚시 이벤트 전달용).
func _viewers_of(peer: int) -> Array:
	var target: Node3D = _players.get_node_or_null(str(peer))
	var out: Array = []
	if target == null:
		return out
	for viewer: Node in _players.get_children():
		var v: Node3D = viewer
		if v == target or v.global_position.distance_to(target.global_position) <= interest_radius:
			out.append(v.name.to_int())
	return out


# ---------- 화면 쪽 ----------

## 플레이어 노드가 이 화면에 생겼을 때 (서버가 직접 만들었든, 복제로 받았든).
func _on_player_node_added(node: Node) -> void:
	var p: CharacterBody3D = node
	if not p.is_local():
		return
	_camera.target = p
	_camera.global_position = p.global_position + _camera.offset
	var ctl: FishingController = p.get_node("FishingController")
	if _toast:
		ctl.message.connect(_toast.show_message)
	if Net.bot != "":
		var bot: Node = DEV_BOT.new()
		bot.name = "DevBot"
		bot.set(&"routine", Net.bot)
		p.add_child(bot)
	Net.log_line("내 캐릭터: %s" % p.name)


func _show(text: String) -> void:
	if _toast:
		_toast.show_message(text)
