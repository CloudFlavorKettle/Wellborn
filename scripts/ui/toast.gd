extends Label
## 화면 아래쪽에 잠깐 떴다 사라지는 한 줄 메시지.

@export var hold_s: float = 2.2

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0


func show_message(text: String) -> void:
	self.text = text
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(hold_s)
	_tween.tween_property(self, "modulate:a", 0.0, 0.6)
