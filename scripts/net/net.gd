extends Node
## 네트워크 시작 설정 (오토로드 "Net").
##
## 실행 인자 (Godot 실행 시 `--` 뒤에 붙인다):
##   --server              화면 없는 전용 서버. 플레이어 캐릭터 없음.
##   --connect=주소[:포트]  클라이언트로 접속.
##   --port=N              서버 포트 (기본 DEFAULT_PORT).
##   --bot=이름            개발용 자동 조작 (scripts/net/dev_bot.gd).
##   --interest-radius=M   (서버, 개발용) 관심 영역 반경을 바꾼다. 0 이하면 월드 기본값.
##   (인자 없음)            호스트: 서버 겸 플레이어 1. 에디터에서 F5로 혼자 개발할 때 쓴다.
##
## 예) 서버:     godot --headless --path . -- --server
##     클라이언트: godot --path . -- --connect=127.0.0.1

enum Mode { HOST, SERVER, CLIENT }

const DEFAULT_PORT: int = 24680
## 1단계 목표 인원(2~4명). 넘치면 접속을 거절한다.
const MAX_CLIENTS: int = 4

var mode: Mode = Mode.HOST
var address: String = "127.0.0.1"
var port: int = DEFAULT_PORT
var bot: String = ""
var interest_radius_override: float = 0.0


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--server":
			mode = Mode.SERVER
		elif arg.begins_with("--connect="):
			mode = Mode.CLIENT
			var target: String = arg.trim_prefix("--connect=")
			if target.contains(":"):
				address = target.get_slice(":", 0)
				port = target.get_slice(":", 1).to_int()
			else:
				address = target
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--bot="):
			bot = arg.trim_prefix("--bot=")
		elif arg.begins_with("--interest-radius="):
			interest_radius_override = arg.trim_prefix("--interest-radius=").to_float()


func is_dedicated() -> bool:
	return mode == Mode.SERVER


## 지금 설정대로 ENet 피어를 만든다. 실패하면 오류 코드를 돌려준다.
func start() -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error
	if mode == Mode.CLIENT:
		err = peer.create_client(address, port)
	else:
		err = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("[net] 시작 실패 (%s, 포트 %d): %s" % [Mode.keys()[mode], port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	log_line("시작: %s %s:%d" % [Mode.keys()[mode], address if mode == Mode.CLIENT else "*", port])
	return OK


func log_line(text: String) -> void:
	var who: String = "server" if mode == Mode.SERVER else ("host" if mode == Mode.HOST else "client%d" % multiplayer.get_unique_id())
	print("[%s] %s" % [who, text])
