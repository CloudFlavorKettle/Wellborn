<div align="center">

# Wellborn · 물나기

**A cozy fantasy life game — play alone or with a few friends. Built in the open, one small piece at a time.**

*혼자서도, 친구 몇 명과 함께여도 좋은 생활 판타지 게임. 누구나 서버를 열고 세계를 보탤 수 있다.*

[![License: MIT](https://img.shields.io/badge/code-MIT-blue.svg)](LICENSE)
[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf.svg?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Renderer: Compatibility](https://img.shields.io/badge/renderer-gl__compatibility-6b7280.svg)](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
[![Stage 1: The Waterside](https://img.shields.io/badge/stage%201-in%20progress-f59e0b.svg)](#roadmap)

[English](#english) · [한국어](#한국어)

![A hand-made VRoid character walking in the Stage 1 test scene](docs/media/stage1_walk.gif)

</div>

---

## English

> *The world is made by the developer. Its future is made by the players, together.*
> *Anyone can run a server. Anyone can add to the world.*

Wellborn is a solo-developed, open-source fantasy life game in the spirit of the old-school online worlds: slow, social, and built around everyday life rather than combat. It works on your own, and it is better with a few friends (2–8) in the same world. It starts as something very small — **two people fishing by a lake and grilling their catch over a campfire** — and only grows when each step has proven to be fun on its own. The server is built so the world can grow larger later, but small and cozy comes first.

### The world

In the beginning there was the First Wave. She shaped life out of water, but life could not breathe beneath the surface and scattered. Out of pity she used herself to shape *something vast* — what it was, no one knows. That act caused the **Great Divergence**: the seed of countless worlds, and the first breath.

The lore is not told through dialogue. It **is** the game's rules:

| In the story | In the game |
|---|---|
| **The Wellborn** — the first lives, returned. Shaped from water, they cannot die for good. | Players. As long as you have Breath, you come back. |
| **The Well** — where the Wellborn rise. Warm, excitable, and knows almost nothing important. | Character creation and the tutorial are a conversation with the Well. |
| **Breath** — life itself. | Your core resource. It refills slowly alone and faster by a campfire or with friends. Another player can breathe life back into you. |
| **The world is her body.** | Gathering wears her down, respawning resources are her healing, and items that rot back into earth are the economy's sink. |
| **Water returns; earth stays behind.** | When you fall, earthly items stay where you fell. Friends can carry them back. Your gear, skills, and XP are never lost. |
| **The Great Divergence** | Why there are many servers. The official server is the first world; community servers are worlds that diverged from it. |

There are no classes. What you do is who you become.

### Principles

- **Runs on a 2011 PC.** 60 fps on an i5-2500 + GTX 560 class machine. Low spec is not a hobby — it is what "anyone" means in practice.
- **Good looks come from art direction, not polygons.** Color, light, fog, silhouette, and motion over texture resolution.
- **Server-authoritative from day one.** The client is open source, so the client is never trusted.
- **Content is data.** Regions, NPCs, items, and recipes will live in JSON content packs. Mods declare intent ("a level 30 sword, 3 iron"); the engine computes the numbers and rejects anything that breaks the economy.
- **Every stage is a finished game.** The next stage starts only after the current one is confirmed to be fun.

### Roadmap

| Stage | Goal | Status |
|---|---|---|
| **0** | Engine, tools, repository, design doc | ✅ Done |
| **1 · The Waterside** | Two players fishing and grilling by a lake. Waking at the Well, fishing, campfire cooking, sharing food, a 2–4 player dedicated server. No death, no pressure. | 🚧 In progress — character, movement, fishing, campfire cooking, and a 2–4 player dedicated server are in |
| **2 · Breath** | The full Breath system, death and returning at the Well, leaving items behind, gathering and crafting, water-shaping, a few NPCs. First public build. | Planned |
| **3 · The World** | Real CORE/CONTENT split with JSON content packs, server owner settings, the first community content, combat. | Planned |
| **4+** | Life-shaping, generational story, identity across worlds. Growing to a larger world is an option, not a promise. | Later |

The full design document (Korean) lives in [CLAUDE.md](CLAUDE.md).

### Running it

1. Install **[Git LFS](https://git-lfs.com)**. Models, textures, and animations are stored in LFS; without it you will get broken placeholder files.
2. Clone the repository:
   ```sh
   git lfs install
   git clone https://github.com/CloudFlavorKettle/Wellborn.git
   ```
3. Open `project.godot` in **[Godot 4.7](https://godotengine.org/download)** and press **F5**.

**Controls:** `WASD` or arrow keys to move (relative to the camera), hold the right mouse button and drag to orbit the camera, mouse wheel to zoom, `Space` by the water to fish or at the campfire to grill and take food.

#### Playing together

Pressing F5 runs a *host*: a server and player 1 in one window. To run a dedicated server and connect clients:

```sh
# dedicated server (no window), default port 24680
godot --headless --path . -- --server
# each player
godot --path . -- --connect=SERVER_ADDRESS
```

Up to 4 players. The server decides movement and every fishing result; clients only send input.

### Tech

| | |
|---|---|
| Engine | Godot 4.7, `gl_compatibility` renderer (no Forward+ / Mobile) |
| Language | GDScript with static typing |
| Characters | Made in VRoid Studio, imported with [godot-vrm](https://github.com/V-Sekai/godot-vrm) (MToon shading, spring bones) |
| Animation | [Quaternius Universal Animation Library](https://quaternius.itch.io/universal-animation-library) via humanoid retargeting |
| Budgets | 16 ms per frame · 1.5 GB client memory · 500 MB install |

### Project layout

```
assets/        Art and animation (CC0, CC-BY, or made for this project only)
  characters/  Player characters (.vrm for the game, .vroid source files)
addons/        Godot plugins (godot-vrm, MToon shader — with local patches noted inside)
scenes/        Game scenes
scripts/       Game code
tools/         Editor and asset-processing scripts
docs/media/    Screenshots and GIFs
```

### Contributing

The project is at a very early stage and the architecture is still moving, so code contributions are not open yet. Issues with ideas, bug reports, and feedback are very welcome. Community content packs will become possible in Stage 3.

### License

- **Code:** [MIT](LICENSE).
- **Assets:** each asset keeps its own license. Every source, author, and license is listed in [CREDITS.md](CREDITS.md). Only CC0, CC-BY, and original work are allowed in this repository.
- **Bundled add-ons:** follow the license inside each folder under `addons/`.

---

## 한국어

> *게임의 세계는 개발자가 만들지만, 그 세계의 미래는 플레이어들이 함께 만든다.*
> *누구나 서버를 열 수 있고, 누구나 콘텐츠를 추가할 수 있다.*

물나기(Wellborn)는 옛날 온라인 게임 감성의 1인 개발 오픈소스 생활 판타지 게임입니다. 전투보다 일상과 협력이 중심인, 느리고 사람 냄새 나는 게임을 지향합니다. 혼자서도 할 수 있고, 친구 몇 명(2~8명)이 같은 세계에 들어오면 더 좋습니다. 시작은 아주 작습니다. **둘이서 호숫가에서 낚시하고 모닥불에 구워 먹는 힐링 게임**에서 출발해, 각 단계가 그 자체로 재미있다는 게 확인될 때만 넓혀 갑니다. 서버는 나중에 더 큰 세계로 키울 수 있게 만들어 두었지만, 작고 아늑한 게 먼저입니다.

### 세계관

최초의 파도가 있었습니다. 그녀는 물로 생명을 빚었지만, 물속에서 생명은 숨을 쉬지 못해 흩어졌습니다. 그녀는 그들을 가엽게 여겨 스스로를 이용해 *거대한 무언가*를 빚었습니다. 그것이 무엇인지는 아무도 모릅니다. 그로 인해 **대분화(大分化)**가 일어났고, 무한한 세계의 씨앗이 생겼으며, 생명은 숨을 쉴 수 있게 되었습니다.

설정은 대사로 설명하지 않습니다. 설정이 곧 **게임의 규칙**입니다.

| 이야기 속에서 | 게임 안에서 |
|---|---|
| **물나기** — 흩어졌던 최초의 생명들이 돌아온 것. 물로 빚어져 죽지 않는다. | 플레이어. 숨만 있으면 다시 일어난다. |
| **우물** — 물나기가 빚어지는 곳. 다정하고 들떠 있지만 중요한 건 하나도 모른다. | 캐릭터 생성과 튜토리얼은 우물과의 대화로 진행된다. |
| **숨** — 생명 그 자체. | 핵심 자원. 혼자면 천천히, 모닥불 곁이나 함께 있으면 빨리 찬다. 다른 플레이어가 숨을 불어넣어 일으켜 줄 수 있다. |
| **세계는 그녀의 몸이다.** | 채집은 그녀를 깎는 것, 자원 리젠은 그녀의 회복, 물건이 삭아 흙으로 돌아가는 것은 경제의 싱크다. |
| **물은 돌아가지만 흙은 못 따라간다.** | 쓰러지면 흙 물건(채집물·재료)은 그 자리에 남는다. 친구가 주워다 줄 수 있다. 장비, 스킬, 경험치는 잃지 않는다. |
| **대분화** | 서버가 여럿인 이유. 공식 서버가 최초의 세계이고, 유저 서버는 거기서 분화한 세계들이다. |

직업은 없습니다. 무엇을 하든 그게 곧 당신이 됩니다.

### 원칙

- **2011년 PC에서 돌아간다.** i5-2500 + GTX 560 급에서 60fps. 저사양은 취미가 아니라 "누구나"를 기술로 지키는 방법입니다.
- **좋은 그래픽은 폴리곤이 아니라 아트 디렉션에서 나온다.** 색, 빛, 안개, 실루엣, 움직임.
- **처음부터 권한 서버.** 클라이언트 코드가 전부 공개되니, 클라이언트는 아무것도 믿지 않습니다.
- **콘텐츠는 데이터다.** 지역, NPC, 아이템, 레시피는 JSON 콘텐츠 팩으로 추가합니다. 모드는 "레벨 30 검, 재료 철 3개"처럼 의도만 선언하고, 수치는 엔진이 계산하며 경제를 깨는 것은 거부합니다.
- **매 단계가 완성된 게임이어야 한다.** 지금 단계가 재미있다는 확인이 있어야 다음 단계로 갑니다.

### 로드맵

| 단계 | 목표 | 상태 |
|---|---|---|
| **0** | 엔진, 도구, 저장소, 설계 문서 | ✅ 완료 |
| **1 「물가」** | 둘이서 낚시하고 모닥불에 구워 먹는 게임. 우물에서 깨어나기, 낚시, 모닥불 요리, 음식 나눠 주기, 2~4명 전용 서버. 죽음도 긴장도 없음. | 🚧 진행 중 — 캐릭터, 이동, 낚시, 모닥불 굽기, 2~4명 전용 서버 완료 |
| **2 「숨」** | 숨 시스템 전체, 죽음과 우물 부활, 물건 두고 오기, 채집·제작, 물로 빚기, NPC 몇 명. 첫 공개 빌드. | 예정 |
| **3 「세계」** | CORE/CONTENT 분리와 JSON 콘텐츠 팩, 서버 주인 설정, 첫 유저 콘텐츠, 전투. | 예정 |
| **4 이후** | 생명 빚기, 세대 스토리, 서버 간 정체성 이동. 더 큰 세계로 키우는 건 약속이 아닌 선택지. | 나중에 |

전체 설계 문서는 [CLAUDE.md](CLAUDE.md)에 있습니다.

### 실행하기

1. **[Git LFS](https://git-lfs.com)**를 설치합니다. 모델, 텍스처, 애니메이션이 LFS에 있어서 없으면 깨진 파일로 받아집니다.
2. 저장소를 받습니다.
   ```sh
   git lfs install
   git clone https://github.com/CloudFlavorKettle/Wellborn.git
   ```
3. **[Godot 4.7](https://godotengine.org/download)**로 `project.godot`를 열고 **F5**로 실행합니다.

**조작:** `WASD` 또는 방향키로 이동(카메라가 보는 방향 기준), 마우스 오른쪽 버튼을 누른 채 드래그로 시점 회전, 휠로 거리 조절, 물가에서 `Space`로 낚시, 모닥불 옆에서 `Space`로 올리기·꺼내기.

#### 같이 하기

F5로 실행하면 *호스트*가 됩니다. 한 창에서 서버와 플레이어 1이 같이 돕니다. 전용 서버를 띄우고 접속하려면:

```sh
# 전용 서버 (화면 없음), 기본 포트 24680
godot --headless --path . -- --server
# 각 플레이어
godot --path . -- --connect=서버주소
```

최대 4명입니다. 이동과 낚시 결과는 전부 서버가 정하고, 클라이언트는 입력만 보냅니다.

### 기술

| | |
|---|---|
| 엔진 | Godot 4.7, `gl_compatibility` 렌더러 (Forward+ / Mobile 사용 안 함) |
| 언어 | GDScript, 정적 타입 |
| 캐릭터 | VRoid Studio로 제작, [godot-vrm](https://github.com/V-Sekai/godot-vrm)으로 임포트 (MToon 셰이딩, 스프링본) |
| 애니메이션 | [Quaternius Universal Animation Library](https://quaternius.itch.io/universal-animation-library), 휴머노이드 리타겟 |
| 예산 | 프레임 16ms · 클라이언트 메모리 1.5GB · 설치 용량 500MB |

### 폴더 구조

```
assets/        아트와 애니메이션 (CC0, CC-BY, 자작만)
  characters/  플레이어 캐릭터 (게임용 .vrm, 원본 .vroid)
addons/        Godot 플러그인 (godot-vrm, MToon 셰이더 — 로컬 패치는 폴더 안에 기록)
scenes/        게임 씬
scripts/       게임 코드
tools/         에디터·에셋 처리 스크립트
docs/media/    스크린샷과 GIF
```

### 참여하기

아직 아주 초기이고 구조가 계속 바뀌고 있어서, 코드 기여는 아직 받지 않습니다. 아이디어, 버그 제보, 피드백은 이슈로 언제든 환영합니다. 유저 콘텐츠 팩은 3단계부터 가능해집니다.

### 라이선스

- **코드:** [MIT](LICENSE).
- **에셋:** 파일마다 각자의 라이선스를 따릅니다. 출처, 작가, 라이선스는 [CREDITS.md](CREDITS.md)에 모두 적혀 있습니다. 이 저장소에는 CC0, CC-BY, 자작 에셋만 들어갑니다.
- **포함된 애드온:** `addons/` 안의 각 폴더에 있는 라이선스를 따릅니다.
