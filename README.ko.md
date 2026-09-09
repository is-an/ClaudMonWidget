# ClaudMonWidget

[English](README.md) · **한국어** · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md)

Claude Code 토큰 사용량을 보여주는 Windows 반투명 위젯. 항상 화면 위에 뜬다.

```
┌──────────────────────────────────┐
│  ● 54%                   2h 57m  │
│  ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░  │
│  6%                       6d 4h  │
│  ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
└──────────────────────────────────┘
```

설치할 런타임이 없다. Windows에 기본으로 들어 있는 PowerShell 5.1 + WPF만 쓴다.
`npm install`도, 별도 로그인도 없다 — Claude Code가 이미 저장해 둔 인증 토큰을
그대로 쓴다.

---

## 목차

- [설치](#설치)
- [실행](#실행)
- [자동 실행](#자동-실행)
  - [Windows 시작 시](#windows-시작-시)
  - [Claude Code 실행 시](#claude-code-실행-시)
- [조작](#조작)
- [스킨](#스킨)
- [연동 방식](#연동-방식)
- [설정](#설정)
- [문제 해결](#문제-해결)
- [테스트](#테스트)
- [빌드](#빌드)
- [스킨 직접 만들기](#스킨-직접-만들기)
- [알려진 제약](#알려진-제약)

---

## 설치

Windows 10/11 + Claude Code가 설치되어 로그인된 상태면 준비 끝이다.

```powershell
git clone https://github.com/is-an/ClaudMonWidget.git
cd ClaudMonWidget
```

또는 ZIP으로 받아 아무 폴더에나 풀어도 된다. 폴더 위치는 상관없지만, 위젯이
`config.json`과 `usage-cache.json`을 그 폴더에 쓰므로 쓰기 권한이 있어야 한다.
`C:\Program Files` 아래는 피할 것.

설치 스크립트도, 레지스트리 등록도 없다. 지울 때는 폴더를 삭제하면 된다
(자동 실행을 걸었다면 [아래](#자동-실행)의 해제부터).

## 실행

**`start-hidden.vbs`**를 더블클릭한다. 콘솔 창이 뜨지 않는다.

콘솔에서 직접 띄우려면:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1 -Skin detail
```

`-ExecutionPolicy Bypass`는 이 실행에만 적용된다. 시스템 정책을 바꾸지 않는다.

저장소에 `.exe`는 들어 있지 않다. 원하면 [`build.ps1`](#빌드)로 46KB짜리 런처를
만들 수 있지만 말 그대로 런처다 — 옆에 `widget.ps1`이 있어야 하고 혼자서는 아무
일도 못 한다. 단독으로 건네줄 바이너리가 아니고, 커밋해 봐야 SmartScreen 경고만
붙는다.

대신 **폴더 자체는 포터블**이다. 인스톨러도 레지스트리 등록도 없고,
`config.json`과 `usage-cache.json`을 스크립트 옆에 쓰므로 설정이 폴더를 따라간다.
USB를 포함해 어디로 복사해도 된다. 다만 사용량 숫자는 실행하는 PC의 Claude Code
계정에서 읽고, [자동 실행](#자동-실행) 항목은 절대 경로를 저장하므로 폴더를 옮긴
뒤에는 `install-hook.ps1`을 다시 실행해야 한다.

위젯은 **한 번에 하나만** 뜬다. 이미 떠 있는데 또 실행하면 두 번째는 조용히
종료된다. 화면에 위젯이 겹쳐 쌓이고 그중 오래된 것이 낡은 값을 보여주는 일을
막기 위해서다.

## 자동 실행

### Windows 시작 시

1. `Win+R` → `shell:startup` → 시작프로그램 폴더가 열린다.
2. `start-hidden.vbs`의 **바로가기**를 그 폴더에 넣는다.

해제하려면 그 바로가기를 지운다. 스크립트 기본 아이콘이 보기 싫으면 바로가기
속성의 아이콘 변경에서 이 폴더의 `icon.ico`를 지정하면 된다.

### Claude Code 실행 시

Claude Code 세션이 시작될 때 위젯이 같이 뜨게 한다. Claude를 쓸 때만 위젯이
필요하다면 이쪽이 낫다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1
```

`~/.claude/settings.json`의 `hooks.SessionStart`에 항목 하나를 추가한다.
기존 훅과 설정은 그대로 두고, 실행 전에 같은 폴더에 타임스탬프 백업을 남긴다.
여러 번 실행해도 항목이 중복되지 않는다.

해제:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1 -Uninstall
```

직접 넣고 싶다면 `~/.claude/settings.json`에 이렇게 추가하면 된다:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "wscript.exe \"C:\\경로\\ClaudMonWidget\\start-hidden.vbs\""
          }
        ]
      }
    ]
  }
}
```

세션마다 훅이 실행되지만 위젯이 단일 인스턴스라 두 번째부터는 즉시 종료된다.

**Claude Code가 끝나도 위젯은 남는다.** 위젯 우클릭 메뉴의 `Exit`로 닫는다.
Claude가 종료될 때 위젯도 같이 닫으려면 세션 종료 훅에서 프로세스를 죽여야
하는데, 다른 Claude 세션이 아직 떠 있을 때도 닫혀 버리므로 넣지 않았다.

## 조작

| 동작 | 결과 |
|---|---|
| 드래그 | 이동. 위치는 종료할 때 `config.json`에 저장 |
| 마우스 올리기 | 창 시작 시각, 청구 토큰, 캐시 읽기 토큰, 데이터 출처 툴팁 |
| 우클릭 | 메뉴 |

메뉴 항목:

- **Skin** — `simple1` / `simple2` / `border1` / `border2` / `detail`. 하나만 선택된다.
- **Opacity** — 55 / 75 / 92 / 100%. 하나만 선택된다.
- **Always on top** — 항상 위 토글.
- **Auto sync** — 5분마다 Anthropic에 물어보기 토글.
- **Sync now** — 지금 Anthropic에 물어본다.
- **Refresh now** — 로컬 파일만 다시 읽는다.
- **Exit** — 종료.

## 스킨

다섯 개. 뒤에 `1`이 붙은 것은 5시간 세션만, `2`는 7일까지 같이 보여준다.

| 이름 | 폭 | 내용 |
|---|---|---|
| `simple1` | 150 | 배경 없이 5시간 숫자만 |
| `simple2` | 250 | 배경 없이 5시간 + 7일, 2열 배열 |
| `border1` | 270 | 둥근 알약 + 5시간 막대 |
| `border2` | 270 | 둥근 알약 + 5시간·7일 막대 |
| `detail` | 300 | 사용자명 + 구독 배지, 5시간·7일 막대, 토큰·요청 수, 데이터 출처 |

기본값은 `border2`. 높이는 내용에 맞춰 자동으로 정해지므로 글꼴 크기를 키운
환경에서도 글자가 잘리지 않는다.

두 창 모두 다음 리셋까지 **남은 시간**으로 표시한다. 단위는 크기에 맞춰 바뀐다
— 5시간 창은 `3h 04m`, 7일 창은 `6d 5h`. `149h 05m`은 머릿속에 안 들어온다.

```
simple1              simple2
  ● 54%              ● 54%  │  6%
   2h 57m              2h 57m │  6d 4h

border1                          border2
┌──────────────────────┐  ┌──────────────────────┐
│ ● 54%        2h 57m  │  │ ● 54%        2h 57m  │
│ ▓▓▓▓▓▓▓░░░░░░░░░░░░  │  │ ▓▓▓▓▓▓▓░░░░░░░░░░░░  │
└──────────────────────┘  │ 6%              6d 4h│
                          │ ▓░░░░░░░░░░░░░░░░░░  │
                          └──────────────────────┘
```

`detail` 스킨:

```
ANIN                        [Pro]
─────────────────────────────────
● 5시간 세션              2h 57m
54%
▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░
6%                         6d 4h
▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
807.1k tok / 399 req / live 2m
```

두 창의 행이 같은 규칙을 따른다: 왼쪽에 사용률 %, 오른쪽에 남은 시간.

색상 단계: 초록(70% 미만) / 노랑(70% 이상) / 빨강(90% 이상) / 회색(값 없음).

---

## 연동 방식

숫자는 세 군데에서 온다. 신선한 순서대로 쓴다.

### 1. Anthropic에 직접 물어본다 (기본 5분마다)

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <액세스 토큰>
anthropic-beta: oauth-2025-04-20
```

Claude Code가 `/usage`를 그릴 때 호출하는 바로 그 엔드포인트다. 따라서 위젯의
%는 `/usage`가 보여주는 값과 같다.

토큰은 Claude Code가 이미 저장해 둔 것을 읽는다:

```
%USERPROFILE%\.claude\.credentials.json  →  claudeAiOauth.accessToken
```

위젯은 별도 로그인을 요구하지 않고, 토큰을 어디로도 보내지 않는다. 위 요청
헤더에만 쓴다. 토큰이 만료됐으면 호출을 건너뛴다 — 갱신은 Claude Code의 OAuth
흐름이 할 일이고, 위젯이 그것을 흉내 내지 않는다.

응답 형태:

```json
{
  "five_hour": { "utilization": 36.0, "resets_at": "2026-09-09T09:04:59+00:00" },
  "seven_day": { "utilization": 4.0,  "resets_at": "2026-09-15T09:59:59+00:00" },
  "limits": [ ... ],
  "spend": { ... }
}
```

응답은 위젯 폴더의 `usage-cache.json`에 그대로 저장한다.

**Claude Code의 파일에는 절대 쓰지 않는다.** `~/.claude.json`은 Claude Code가
통째로 다시 쓰는 파일이라, 외부에서 동시에 쓰면 상태가 깨질 수 있다. 위젯이
죽거나 실패해도 Claude Code 쪽은 영향을 받지 않는다.

### 2. `%USERPROFILE%\.claude.json` → `cachedUsageUtilization`

같은 숫자지만 Claude Code가 서버에서 받아올 때만 갱신되는 캐시다. 며칠 묵을 수
있다. 1번을 아직 못 받았거나 읽을 수 없을 때의 대비책이다.

실측에서 이 캐시가 44시간 묵은 채 5시간 70% / 7일 60%를 가리키고 있었는데, 같은
순간 1번으로 직접 물어본 실제 값은 28% / 3%였다. 라이브 호출을 넣은 이유다.

### 3. `%USERPROFILE%\.claude\projects\**\*.jsonl` → assistant 줄

```json
"usage": { "input_tokens": 2, "cache_creation_input_tokens": 25110,
           "cache_read_input_tokens": 29894, "output_tokens": 599 }
```

요청별 토큰 수와 타임스탬프. 네트워크와 무관하게 5초마다 다시 읽는다. 항상
최신이지만 서버 집계가 아니라 우리 자체 집계다.

세션 창 안에 드는 줄만 더한다. 창 시작 = `five_hour.resets_at` − 5시간.

캐시 읽기 토큰은 청구 토큰의 20배를 넘기기 때문에 따로 센다. 화면의 `tok`은
청구 토큰(input + output + 캐시 쓰기)이고, 캐시 읽기는 툴팁에만 나온다.

### 사용자명과 구독 등급

`~/.claude.json`의 `oauthAccount` 블록에서 읽는다 — 네트워크 호출 없음.

| 필드 | 쓰임 |
|---|---|
| `displayName` | 사용자명 |
| `emailAddress` | 사용자명 툴팁 |
| `organizationType` | 구독 배지 |

`organizationType` 매핑: `claude_pro`→`Pro`, `claude_max`→`Max`,
`claude_max_5x`→`Max 5x`, `claude_max_20x`→`Max 20x`, `claude_team`→`Team`,
`claude_enterprise`→`Enterprise`.

위젯이 도는 동안 바뀌지 않으므로 창을 만들 때 한 번만 읽는다.

### 지금 무엇을 보고 있는지

`detail` 스킨 맨 아랫줄에 출처와 나이가 그대로 나온다.

| 표시 | 뜻 |
|---|---|
| `live now` | 방금 Anthropic에서 받아옴 |
| `live 12m` | 12분 전에 받아온 값 |
| `claude-code 2d` | 라이브 실패. Claude Code 캐시를 쓰는 중이고 이틀 묵음 |
| `token expired` | 토큰 만료. Claude Code를 한 번 실행하면 갱신된다 |
| `http 429` | 호출이 너무 잦음. 다음 주기에 저절로 풀린다 |
| `http 401` | 인증 거부. Claude Code에 다시 로그인 |
| `sync failed` | 네트워크 오류 등 |

위젯을 껐다 켜도 캐시가 `syncSeconds`(기본 300초)보다 젊으면 다시 물어보지
않는다. Claude Code 훅으로 자주 재시작될 때 엔드포인트를 두드려 `http 429`를
부르는 일을 막는다. `Sync now`는 이 제한을 무시한다.

`resets_at`이 이미 지났으면 그 %는 지난 창의 것이므로 **표시하지 않는다.** 대신
자체 집계 토큰 수를 보여준다. 오래된 숫자를 현재 값인 척 보여주지 않는 것이 이
위젯의 기본 원칙이다.

이 상태는 잠깐이어야 한다. 폴링이 창이 넘어간 것을 감지하면 다음 정기 동기화를
기다리지 않고 그 자리에서 Anthropic에 새 창을 물어본다. 공백이 `syncSeconds`가
아니라 몇 초로 줄어든다.

비용($)은 표시하지 않는다. 비용이 기록되는 `cost-state` 줄은 세션이 끝날 때쯤
쓰이므로 진행 중인 세션 파일에는 없다.

---

## 설정

`config.json`은 위젯이 처음 종료될 때 만들어진다. 대부분은 우클릭 메뉴로
바뀌므로 직접 열 일은 드물다.

| 키 | 기본 | 뜻 |
|---|---|---|
| `skin` | `border2` | 시작 스킨. 없는 이름이면 기본값으로 되돌린다 |
| `opacity` | `0.92` | 창 전체 불투명도 |
| `left` / `top` | `-1` | 위치. `-1`이면 우하단에 자동 배치 |
| `pollSeconds` | `5` | 로컬 파일 다시 읽는 주기 |
| `syncSeconds` | `300` | Anthropic에 물어보는 주기 |
| `autoSync` | `true` | 자동 동기화. 끄면 `Sync now`로만 갱신 |
| `windowHours` | `5` | 세션 창 길이 |
| `warnPct` / `dangerPct` | `70` / `90` | 노랑 / 빨강으로 넘어가는 지점 |

`usage-cache.json`은 마지막 동기화 응답이다. 지워도 된다 — 다음 동기화에 다시
만들어진다.

## 문제 해결

**위젯이 안 보인다**
`config.json`의 `left` / `top`이 지금 없는 모니터를 가리킬 수 있다. 그 파일을
지우고 다시 실행하면 우하단에 다시 배치된다.

**남은 시간이 Claude 앱/웹과 다르다**
위젯과 앱은 같은 `resets_at`을 쓰므로 값이 갈릴 이유가 없다. 갈린다면 위젯이
낡았을 가능성이 높다 — 최신 버전인지 확인한다. 초 단위를 버리기 때문에 앱과
1분까지 차이날 수 있고, 그 이상 차이나면 버그다.

**숫자가 멈춰 있다**
오래 떠 있던 인스턴스일 수 있다. `Exit`로 닫고 다시 실행한다. 남은 시간은 매
5초 다시 계산하므로, 정상이라면 1분마다 1분씩 줄어든다.

**아랫줄이 `claude-code`에서 안 바뀐다**
라이브 호출이 실패하는 중이다. `Sync now`를 눌러 사유를 확인한다.
`token expired`면 Claude Code를 한 번 실행해 토큰을 갱신시킨다.

**`%`가 안 나오고 토큰 수만 나온다**
세션 창이 만료된 값밖에 없다는 뜻이다. `Sync now`를 누르거나 Claude Code에서
`/usage`를 한 번 친다.

**스크립트 실행이 차단된다**
`start-hidden.vbs`와 위 명령들은 `-ExecutionPolicy Bypass`를 이 실행에만
적용한다. 그래도 막히면 조직 정책일 수 있다.

## 테스트

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test-usage.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File test-menu.ps1
```

`test-usage.ps1`은 TEMP에 가짜 `.claude` 트리를 만들고 기준 시각까지 고정해서
집계·계정 파싱·소스 우선순위·폴백을 검증한다. 네트워크를 타지 않고 실제 로그
내용에도 기대지 않으므로 언제 돌려도 결과가 같다.

`test-menu.ps1`은 우클릭 메뉴가 실제로 라디오처럼 동작하는지 확인한다. WPF
`MenuItem`에는 라디오 모드가 없어서, 그냥 두면 불투명도가 여러 개 동시에
선택된다.

## 빌드

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
```

`System.Drawing`으로 `icon.ico`를 그리고, `.ico`를 직접 조립하고, Windows에 기본
포함된 .NET Framework의 C# 컴파일러로 `ClaudMonWidget.exe`를 컴파일한다. 내려받는
것은 없다.

`icon.ico`는 커밋되어 있다. exe는 커밋하지 않고 gitignore에 넣었다 — 자기 폴더의
`widget.ps1`을 띄우는 것이 전부라 혼자 돌아다닐 물건이 아니고, `start-hidden.vbs`가
컴파일 없이 같은 일을 한다. 아이콘 붙은 더블클릭 파일이 필요하면 직접 만들면 된다.

## 스킨 직접 만들기

`skins\<이름>.xaml` 파일 하나를 추가하면 끝이다. `widget.ps1`은 건드릴 필요가
없다.

호스트는 아래 이름을 `FindName`으로 찾아서 **있는 것만** 채운다. 원하는 것만
넣으면 된다.

| `x:Name` | 종류 | 채워지는 값 |
|---|---|---|
| `Dot` | Shape | 상태 색 |
| `TxtMain` | TextBlock | 5시간 사용률 %. 값이 없으면 자체 집계 토큰 수 |
| `TxtReset` | TextBlock | 5시간 리셋까지 남은 시간 (`3h 04m`), 모르면 `--` |
| `TxtWeek` | TextBlock | 7일 사용률 % |
| `TxtWeekReset` | TextBlock | 7일 리셋까지 남은 시간 (`6d 5h`), 모르면 `--` |
| `TxtSub` | TextBlock | `563.0k tok / 249 req / live now` |
| `TxtUser` | TextBlock | 사용자명 (툴팁에 이메일) |
| `TxtPlan` | TextBlock | 구독 등급 |
| `BarTrack` / `BarFill` | Border | 5시간 진행 막대 |
| `WeekTrack` / `WeekFill` | Border | 7일 진행 막대 |
| `Root` | 아무 컨테이너 | 우클릭 메뉴가 붙는 곳 |

`Window`에는 `WindowStyle="None"`, `AllowsTransparency="True"`,
`Background="Transparent"`가 필요하다. 높이는 `SizeToContent="Height"`로 두면
글꼴 크기가 달라져도 잘리지 않는다.

우클릭 메뉴 목록에 새 스킨을 넣으려면 `widget.ps1` 위쪽의 `$Skins` 배열과
`-Skin` 파라미터의 `ValidateSet`에 이름을 추가한다.

```powershell
$Skins = @('simple1','simple2','border1','border2','detail')
```

`config.json`이 없는 스킨 이름을 가리키면 기본 스킨으로 되돌아간다. 스킨을
지우거나 이름을 바꿔도 위젯이 시작 자체를 거부하지는 않는다.

## 알려진 제약

- 자체 토큰 집계는 Anthropic의 과금·한도 계산과 일치한다는 보장이 없다. 화면의
  `%`는 서버 값이고, `tok`은 우리 집계다.
- `/api/oauth/usage`는 공개 문서화된 API가 아니다. Claude Code가 쓰는 것을
  그대로 쓴다. 응답 형태가 바뀌면 동기화가 `unrecognized response`를 남기고
  **직전 캐시를 그대로 둔다** — 화면이 비지 않는다.
- 마우스 통과(click-through)는 없다. 켜면 우클릭 메뉴에 닿을 수 없어져서 전역
  단축키 등록이 딸려 온다.
- Claude Code 업데이트로 JSONL 필드명이 바뀌면 집계가 0이 될 수 있다. 그럴 때
  위젯은 죽지 않고 `--`를 표시한다.
- Windows 전용이다. WPF에 묶여 있다.

## PowerShell 5.1에서 밟은 지뢰

고칠 때 다시 밟지 않도록 적어 둔다. 전부 오류 없이 조용히 틀린 값을 내놓는
종류다.

- **`~/.claude.json`을 `ConvertFrom-Json`으로 파싱하면 안 된다.** 프로젝트 맵이
  절대경로를 키로 쓰는데 파서가 키를 대소문자 구분 없이 다뤄서, `c:\...`와
  `C:\...`가 중복 키로 충돌해 파싱 전체가 예외를 던진다. 필요한 값만 정규식으로
  뽑는다.
- **`.ps1`에 한글을 넣지 않는다.** BOM 없는 스크립트를 ANSI로 읽어서 글자가
  깨진다. 한글은 XAML에만 두고, XAML은 UTF-8로 명시해서 읽는다. 같은 이유로
  `Get-Content | Set-Content`로 이 파일들을 왕복시키면 안 된다.
- **`GetNewClosure()`한 스크립트블록은 복제된 스코프에서 돈다.** 만든 쪽이
  나중에 대입한 `$script:` 변수도, 감싸는 함수 안에 정의된 함수도 보이지 않는다.
  공유 상태는 해시테이블 하나에 담아 참조로 넘기고, 핸들러가 부를 함수는 스크립트
  최상위에 둔다. 이걸 놓쳤을 때 `SourceInitialized` 핸들러가 중간에 예외로
  끊겨서, 그 뒤에 있던 폴링 타이머가 시작되지 않았다. 위젯은 멀쩡히 떠 있는데
  첫 프레임에서 멈췄다 — 죽은 위젯은 눈에 띄지만 멈춘 위젯은 안 띈다. 그래서
  지금은 폴링 타이머를 **가장 먼저, 무조건** 시작한다.
- **`[int]` 캐스트는 버림이 아니라 반올림이다.** `[int]3.58`은 `4`다. 남은 시간을
  `[int]$span.TotalHours`로 계산하는 바람에 3시간 34분이 `4h 34m`으로 나왔다.
  분은 그대로 맞아서 그럴듯해 보였고, 없는 한 시간의 여유가 있는 것처럼 읽혔다.
  시간을 자를 때는 `[math]::Floor`를 쓴다. 예산을 보여주는 숫자는 올림 쪽으로
  틀리면 안 된다.
- **`return $배열`은 파이프라인에서 낱개로 풀린다.** 호출한 쪽은 `byte[]` 대신
  박싱된 원소가 든 `object[]`를 받는다. `.Length`는 그대로 맞아서 아이콘
  디렉터리는 멀쩡해 보이는데, `BinaryWriter.Write`가 다른 오버로드를 골라 항목당
  1바이트만 쓴다 — 헤더는 완벽하고 이미지는 없는 108바이트짜리 `.ico`가 나온다.
  `, $배열`로 반환한다.
- **이벤트에 연결한 스크립트블록은 `(sender, args)`를 위치 인자로 받는다.**
  여기에 형식 있는 매개변수를 두면 `DispatcherTimer` 같은 sender를 캐스트하려다
  핸들러 안에서 예외가 나고, 그 예외는 아무 데도 드러나지 않는다. auto sync와
  `Sync now`가 이렇게 죽었는데 위젯은 멀쩡해 보였다 — 캐시가 갱신을 멈추고,
  5시간 창이 넘어가고, 재시작할 때까지 %가 회색이 됐다. 재시작은 직접 호출
  경로라 정상으로 보였다. 핸들러는 매개변수를 받지 않게 하고, 실제 인자는 감싸는
  스크립트블록이 넘긴다. `test-menu.ps1`이 양쪽을 고정한다.
- **`StrictMode 2.0`에서 파이프라인 결과에 `.Count`를 쓰면 안 된다.** 결과가
  하나뿐이면 스칼라가 나와 `.Count`가 없다고 예외가 난다. 인자 계산 중에 터지면
  그 검사가 통째로 건너뛰어지므로, 테스트가 조용히 통과한 척한다. `@(...)`로
  감싼다.
