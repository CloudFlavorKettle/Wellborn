extends Node
## 개발용 자동 조작. `--bot=이름`으로 실행했을 때만 내 캐릭터에 붙는다. 실제 게임에는 쓰이지 않는다.
## 사람 없이 여러 클라이언트를 띄워 네트워크를 검증하려고 만들었다. 진행 상황은 표준 출력으로 남긴다.
##
## routine:
##   fish_once  물가로 걸어가 한 번 낚시하고, 입질에 챔질한 뒤 종료
##   fish       계속 낚시
##   idle       가만히 서서 주변 플레이어 수만 보고

var routine: String = "fish_once"
## `--shot=폴더`를 주면 3초마다 화면을 저장한다 (최대 8장). 화면 있는 실행에서만 의미가 있다.
var _shot_dir: String = ""
var _shot_t: float = 0.0
var _shot_n: int = 0

var _player: CharacterBody3D
var _ctl: FishingController
var _state: String = "walk"
var _report_t: float = 0.0
var _catches: int = 0


func _ready() -> void:
	_player = get_parent()
	_ctl = _player.get_node("FishingController")
	var auth: FishingAuthority = get_tree().get_first_node_in_group(&"fishing_authority")
	auth.client_event.connect(_on_event)
	Net.log_line("bot 시작: %s" % routine)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_dir = arg.trim_prefix("--shot=")
	if routine == "idle":
		_state = "idle"


func _process(delta: float) -> void:
	if _shot_dir == "" or _shot_n >= 8:
		return
	_shot_t += delta
	if _shot_t >= 3.0:
		_shot_t = 0.0
		_shot_n += 1
		var path: String = "%s/%s_%02d.png" % [_shot_dir, _player.name, _shot_n]
		get_viewport().get_texture().get_image().save_png(path)
		Net.log_line("bot 스크린샷: %s" % path)


func _physics_process(delta: float) -> void:
	_report_t += delta
	if _report_t >= 2.0:
		_report_t = 0.0
		var others: Array = []
		for n: Node in _player.get_parent().get_children():
			if n != _player:
				others.append("%s@(%.1f,%.1f)" % [n.name, (n as Node3D).global_position.x, (n as Node3D).global_position.z])
		Net.log_line("bot 보고: 내 위치 (%.2f, %.2f), 보이는 다른 플레이어 %s" % [_player.global_position.x, _player.global_position.z, others])
	match _state:
		"walk":
			_player.input_override = Vector2(0.0, -1.0)
			if _player.global_position.z <= -5.2 or (_player.get_real_velocity().length() < 0.05 and _player.global_position.z < -4.5):
				_player.input_override = Vector2.ZERO
				_state = "cast"
		"cast":
			if _player.get_real_velocity().length() < 0.05:
				_ctl.press()
				_state = "waiting"
		_:
			pass


func _on_event(pid: int, kind: StringName, data: Dictionary) -> void:
	if pid != _player.peer_id():
		Net.log_line("bot: 다른 플레이어 %d의 낚시 %s %s" % [pid, kind, data])
		return
	Net.log_line("bot 이벤트: %s %s" % [kind, data])
	match kind:
		&"bite":
			await get_tree().create_timer(0.12).timeout
			_ctl.press()
		&"cast_denied":
			_state = "walk"
		&"result":
			if data.get("outcome") == "caught":
				_catches += 1
			if routine == "fish_once":
				await get_tree().create_timer(2.5).timeout
				Net.log_line("bot 종료 (잡은 수 %d)" % _catches)
				get_tree().quit()
			else:
				await get_tree().create_timer(2.5).timeout
				_state = "cast"
