# Wellborn 로컬 패치

애드온을 업데이트하면 이 패치가 덮어써진다. 업데이트 후 다시 적용할 것.

## 1. 앰비언트 이중 적용 끔 (2026-11-07)

- 파일: `mtoon_common.gdshaderinc` 2번째 줄
- 원래: `//render_mode specular_disabled,ambient_light_disabled;` (주석)
- 변경: `render_mode ambient_light_disabled;`
- 이유: 셰이더의 light()가 직접광을 MToon 방식으로 다 계산한 뒤, Godot가 하늘 앰비언트를 ALBEDO에 100% 한 번 더 더한다.
  밝은 하늘 아래서 피부가 (1.0, 1.0, 1.0)로 포화돼 하얗게 날아갔다. Unity MToon은 간접광을 `_IndirectLightIntensity`(기본 0.1)만큼만 쓴다.
- 결과: 피부 픽셀 (1.00, 1.00, 1.00) → (0.79, 0.68, 0.65).
- 부작용: 간접광 10%도 빠진다. 아주 어두운 장면(밤, 실내)에서 캐릭터가 어두워 보이면 그때 간접광 항을 셰이더에 직접 넣는다.

## 2. 옷 색 변형용 색상환 회전 (2026-11-07)

- 파일: `mtoon_common.gdshaderinc`
- 추가: `uniform float _WellbornHueShift`(기본 0)와 `wellborn_hue_shift()` 함수. `lit *= _Color;` 바로 뒤에서 lit·shade 색을 YIQ 색공간에서 회전한다.
- 이유: 모델을 여러 개 만들지 않고 플레이어마다 옷 색을 다르게 보이게 하려고. 기본값 0이면 원래 셰이더와 결과가 같다.
- 쓰는 곳: `scripts/player.gd`의 `_apply_color()`가 이름에 `CLOTH`가 들어간 재질에만 값을 준다. 피부·얼굴·머리카락은 그대로.
