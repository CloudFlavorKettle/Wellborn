# Wellborn (물나기)

1인 개발 오픈소스 MMORPG. 옛날 온라인 게임 감성의 협력·생활 중심 게임.
처음은 "낚시하고 모닥불에 구워 먹는 힐링 게임"으로 시작해서, 단계적으로 MMO로 확장한다.

> 게임의 세계는 개발자가 만들지만, 그 세계의 미래는 플레이어들이 함께 만든다.
> 누구나 서버를 열 수 있고, 누구나 콘텐츠를 추가할 수 있다.

## 지금 상태

**1단계 「물가」 개발 중.** 3D 씬에서 캐릭터가 걷는 단계다. 아직 게임으로 플레이할 수 있는 상태는 아니다.

![1단계: VRoid 자작 캐릭터가 걷는 모습](docs/media/stage1_walk.gif)

- 완료: 3D 씬, WASD 이동, 추적 카메라, 자작 VRoid 캐릭터, 걷기·대기 애니메이션
- 다음: 호숫가 환경, 낚시, 모닥불, 전용 서버(2~4명)

전체 로드맵과 설계 원칙은 [CLAUDE.md](CLAUDE.md)에 있다.

## 기술

- 엔진: Godot 4.7, 렌더러 gl_compatibility, 언어 GDScript
- 목표 사양: 2011년 PC(i5-2500 + GTX 560 급)에서 60fps
- 서버는 처음부터 권한 서버(server-authoritative)

## 실행하기

1. [Git LFS](https://git-lfs.com)를 설치한다. 모델·텍스처·애니메이션이 LFS에 있어서, 없으면 파일이 깨진 채로 받아진다.
2. 저장소를 받는다.
   ```
   git lfs install
   git clone https://github.com/CloudFlavorKettle/Wellborn.git
   ```
3. [Godot 4.7](https://godotengine.org/download)로 `project.godot`를 열고 실행(F5)한다.

조작: WASD 또는 방향키로 이동, 마우스 휠로 카메라 거리 조절.

## 라이선스

- **코드**: [MIT](LICENSE)
- **에셋**: 파일마다 다르다. 출처와 라이선스는 [CREDITS.md](CREDITS.md)에 있다. CC0, CC-BY, 자작만 이 저장소에 들어간다.
- **포함된 애드온**: godot-vrm(MIT, V-Sekai). `addons/` 안의 각 LICENSE를 따른다.
