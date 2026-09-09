# ClaudMonWidget 기획서

Claude Code 토큰 사용량을 항상 화면 위에 떠 있는 반투명 위젯으로 보여주는 Windows 데스크톱 도구.

## 1. 문제

Claude Code를 쓰는 동안 지금까지 토큰을 얼마나 썼는지, 5시간 세션 한도에서 얼마나 남았는지 알려면 `/usage`를 직접 쳐야 한다. 작업 흐름이 끊기고, 한도에 걸리기 직전을 놓친다. 항상 보이는 곳에 숫자가 떠 있으면 이 두 문제가 같이 사라진다.

## 2. 목표 / 비목표

**목표**
- 현재 5시간 세션 창의 토큰 사용량과 남은 시간을 항상 표시
- 클릭을 방해하지 않는 반투명 오버레이 (마우스 통과 옵션)
- 위젯 자체가 무거우면 안 됨 — idle CPU 0%에 가깝게

**비목표 (1차 범위 밖)**
- 사용량 히스토리 그래프, 통계 대시보드
- 여러 머신 합산, 팀 단위 집계
- Claude Code 외 다른 도구(API 직접 호출 등) 사용량 추적

## 3. 데이터 소스

Anthropic API를 호출하지 않는다. Claude Code가 이미 로컬에 모든 기록을 남긴다.

```
%USERPROFILE%\.claude\projects\<프로젝트-슬러그>\<session-id>.jsonl
```

각 JSONL 파일은 한 줄에 JSON 하나. 두 종류의 줄을 쓴다.

**(a) assistant 메시지 줄** — 요청 단위 사용량과 타임스탬프가 들어 있다.

```json
"usage":{"input_tokens":2,"cache_creation_input_tokens":25110,
         "cache_read_input_tokens":29894,"output_tokens":599,
         "output_tokens_details":{"thinking_tokens":32}}
```

**(b) `cost-state` 줄** — 세션 전체 누적 집계. 파일 끝에 갱신된다.

```json
{"type":"cost-state","sessionId":"...","totalCostUSD":0.1289516,
 "startTime":1788830139849,
 "modelUsage":{"claude-sonnet-5":{"inputTokens":96,"outputTokens":694,
   "cacheReadInputTokens":84898,"cacheCreationInputTokens":...,"costUSD":...}}}
```

**(c) 라이브 — `GET https://api.anthropic.com/api/oauth/usage`** — Claude Code가 `/usage`를 그릴 때 호출하는 엔드포인트. 토큰은 `~/.claude/.credentials.json`의 `claudeAiOauth.accessToken`을 그대로 쓴다(별도 로그인 없음). 헤더는 `Authorization: Bearer <token>`와 `anthropic-beta: oauth-2025-04-20`. 응답은 아래 (d)의 `utilization` 객체와 같은 모양이라 파서 하나로 둘 다 읽는다.

응답은 위젯 폴더의 `usage-cache.json`에 그대로 저장한다. **Claude Code의 파일에는 쓰지 않는다** — 그쪽은 Claude Code가 통째로 다시 쓰는 파일이라 동시 쓰기가 상태를 깨뜨릴 수 있다. 파싱 못 하는 응답이 오면 직전 캐시를 그대로 둔다.

**(d) `~/.claude.json` → `cachedUsageUtilization`** — 같은 숫자지만 Claude Code가 받아올 때만 갱신되는 캐시. (c)를 못 쓸 때의 대비책.

```json
"cachedUsageUtilization": {
  "fetchedAtMs": 1788764898307,
  "utilization": {
    "five_hour": { "utilization": 70, "resets_at": "2026-09-07T09:20:00Z" },
    "seven_day": { "utilization": 60, "resets_at": "2026-09-08T10:00:00Z" }
  }
}
```

이것 덕분에 플랜별 한도를 사용자에게 물어볼 필요가 없다. 다만 (d)는 이름 그대로 **캐시**라서 Claude Code가 새로 받아올 때만 갱신된다. 실측에서 44시간 묵은 값이 70% / 60%를 가리키고 있었는데, 같은 순간 (c)로 직접 물어본 실제 값은 28% / 3%였다. 라이브 호출을 넣은 이유가 이것이다.

| 표시 항목 | 출처 | 성질 |
|---|---|---|
| 5시간 / 7일 사용률 %, 리셋 시각 | (c) 라이브 호출, 5분마다 | 정확하고 최신 |
| 같은 값, 라이브가 없을 때 | (d) `.claude.json` 캐시 | 정확하지만 며칠 묵을 수 있음 |
| 창 내 토큰 수, 요청 수 | (b) JSONL assistant 줄 | 항상 최신, 우리 자체 집계 |
| 사용자명, 구독 등급 | `.claude.json` → `oauthAccount` | 로컬, 호출 없음 |

지금 어느 출처를 보고 있는지는 `detail` 스킨 아랫줄에 그대로 적는다(`live now`, `claude-code 2d`, 또는 실패 사유). 숫자만 보여주고 출처를 숨기면, 오래된 값과 최신 값을 구분할 방법이 사용자에게 없다.

구독 등급은 `oauthAccount.organizationType`에서 온다: `claude_pro`, `claude_max`, `claude_max_5x`, `claude_max_20x`, `claude_team`, `claude_enterprise`.

`resets_at`이 이미 지났으면 그 캐시는 지난 창의 것이므로 **%를 표시하지 않는다**. 대신 자체 집계 토큰 수를 보여주고, `fetchedAtMs` 기준 캐시 나이를 같이 적는다. 오래된 숫자를 현재 값인 척 보여주지 않는 것이 이 위젯의 기본 원칙이다.

창 시작 시각은 `five_hour.resets_at - 5h`. 캐시가 만료됐으면 `현재 - 5h`로 되돌린다.

**비용은 표시하지 않는다.** `cost-state` 줄은 세션이 끝나거나 주기적으로 flush될 때만 쓰이므로, 진행 중인 세션 파일에는 없다. 라이브 위젯이 못 믿을 값을 보여주느니 빼는 편이 낫다. 모델 가격표를 위젯에 박아 넣는 선택지는 처음부터 없다.

폴링은 5초 간격. mtime이 창 시작보다 이른 파일은 열지 않는다 (그런 파일에는 창 안의 줄이 있을 수 없다). 줄 파싱은 `ConvertFrom-Json` 대신 정규식 — 실측 전체 스캔 267ms.

> `~/.claude.json`을 `ConvertFrom-Json`으로 파싱하면 안 된다. 이 파일에는 절대경로를 키로 쓰는 프로젝트 맵이 들어 있는데, PowerShell 5.1의 JSON 파서는 키를 대소문자 구분 없이 다루기 때문에 `c:\...`와 `C:\...`가 중복 키로 충돌해 파싱 전체가 예외를 던진다. 필요한 값만 정규식으로 뽑는다.

## 4. 화면

스킨 3종. 전부 반투명이고, `skins\<이름>.xaml` 파일 하나가 스킨 하나다. 우클릭 메뉴에서 바꾸면 창을 다시 만든다.

| 스킨 | 크기 | 보여주는 것 |
|---|---|---|
뒤에 `1`이 붙은 것은 5시간 세션만, `2`는 7일까지 같이 보여준다. 기본값 `border2`.

| 스킨 | 폭 | 보여주는 것 |
|---|---|---|
| `simple1` | 150 | 배경 없이 5시간 숫자만. 그림자로 가독성 확보 |
| `simple2` | 250 | 배경 없이 2열. 왼쪽 5시간, 오른쪽 7일. 두 열 모두 % 위, 남은 시간 아래 |
| `border1` | 270 | 둥근 알약 + 5시간 막대 + 리셋 카운트다운 |
| `border2` | 270 | 위에 7일 막대 추가 |
| `detail` | 300 | 사용자명 + 구독 배지, 5시간·7일 두 막대, 토큰·요청 수, 데이터 출처 |

높이는 `SizeToContent="Height"`로 내용이 정한다. 고정 높이는 글꼴 배율이 다른 환경에서 아랫줄을 잘라먹는다 — 실제로 `detail`에서 한 번 잘렸다. 그래서 첫 실행 시 우하단 배치도 `ContentRendered`까지 미룬다. 그때가 되어야 실제 높이를 알 수 있다.

공통 요소:
- 좌상단 점: 초록(여유) / 노랑(70% 초과) / 빨강(90% 초과) / 회색(값 없음)
- 큰 숫자: 5시간 사용률 %. 캐시가 만료됐으면 대신 자체 집계 토큰 수
- 리셋까지 남은 시간, 모르면 `--`. 단위는 크기에 맞춰 바뀐다 — 5시간 창은 `3h 04m`, 7일 창은 `6d 5h`. `149h 05m`은 머릿속에 안 들어온다

스킨은 호스트와 **이름으로만** 맞물린다. `widget.ps1`은 `Dot`, `TxtMain`, `TxtSub`, `TxtReset`, `TxtWeek`, `TxtUser`, `TxtPlan`, `BarTrack`, `BarFill`, `WeekTrack`, `WeekFill`을 `FindName`으로 찾고, 없으면 그냥 건너뛴다. 5시간 전용 스킨은 `TxtWeek`·`WeekFill`을 안 넣기만 하면 되고, 호스트에는 조건 분기가 하나도 없다. 스킨 다섯 개가 XAML 다섯 파일과 `$Skins` 배열 한 줄로 끝나는 이유다.

`config.json`이 없는 스킨 이름을 가리키면 기본 스킨으로 되돌아간다. 스킨 이름을 바꿔도 예전 설정 파일 때문에 위젯이 시작을 거부하지 않는다.

인터랙션:
- 드래그로 이동, 위치는 `config.json`에 저장
- 우클릭 메뉴: 스킨 전환, 불투명도(55/75/92/100%), 항상 위, 자동 동기화, `Sync now`, `Refresh now`, 종료
- 툴팁: 창 시작 시각, 청구 토큰, 캐시 읽기 토큰, 데이터 출처

스킨과 불투명도는 각각 하나만 선택되어야 한다. WPF `MenuItem`에는 라디오 모드가 없고 `IsCheckable`은 토글일 뿐이라, 그대로 두면 불투명도 네 개가 동시에 체크된다. 클릭 시 형제들의 체크를 지우는 것이 라디오를 만드는 유일한 방법이고, `test-menu.ps1`이 이것을 검증한다.

마우스 통과(click-through)는 넣지 않았다. 켜는 순간 우클릭 메뉴에 닿을 수 없어 전역 단축키 등록이 딸려 오는데, 요청에 없던 기능치고 비용이 크다.

## 5. 기술 스택

Windows에 이미 있는 것으로 끝낸다.

**선택: PowerShell 5.1 + WPF (XAML)**

- Windows에 기본 탑재. 설치할 런타임이 없다.
- WPF의 `AllowsTransparency="True"` + `WindowStyle="None"`으로 진짜 알파 반투명이 나온다. 둥근 모서리, 그림자, 그라디언트 전부 XAML 한 파일로 해결.
- `Topmost="True"`로 항상 위, `WS_EX_TRANSPARENT` 스타일 한 줄로 마우스 통과.
- 파일 두 개로 끝난다: `widget.xaml`(모양) + `widget.ps1`(폴링·집계·바인딩).

**검토했지만 안 쓰는 것**

| 후보 | 이유 |
|---|---|
| Electron | 반투명 창은 쉽지만 위젯 하나에 200MB 런타임과 100MB+ 메모리. 과함. |
| Tauri | 결과물은 가볍지만 Rust 툴체인이 이 머신에 없다. 빌드 환경부터 깔아야 함. |
| Node + 시스템 트레이 | Node 24는 있으나 창을 띄우려면 결국 Electron류가 필요. |
| Python/tkinter | 이 머신에 Python이 없다. tkinter 반투명은 `-alpha`뿐이라 모서리 처리가 지저분하다. |

실행은 바탕화면 바로가기 하나(`powershell -WindowStyle Hidden -File widget.ps1`), 자동 시작은 시작프로그램 폴더에 그 바로가기를 넣는 것으로 끝낸다. 서비스 등록이나 설치 프로그램은 만들지 않는다.

## 6. 구조

```
ClaudMonWidget/
  usage.ps1         # 읽기와 집계, 라이브 동기화. UI 없음
  widget.ps1        # 진입점: 창 생성, 타이머 둘, 메뉴, 설정 저장
  skins/
    simple1.xaml    border1.xaml
    simple2.xaml    border2.xaml
    detail.xaml
  test-usage.ps1    # 집계·계정·소스 우선순위 검증
  test-menu.ps1     # 메뉴 라디오 동작 검증
  start-hidden.vbs  # 콘솔 창 깜빡임 없이 실행
  install-hook.ps1  # Claude Code SessionStart 훅 설치/해제
  config.json       # 첫 종료 시 생성 (gitignore)
  usage-cache.json  # 마지막 라이브 응답 (gitignore)
```

위젯은 명명된 뮤텍스로 단일 인스턴스를 강제한다. Claude Code 훅이 세션마다 뜨기 때문에, 없으면 하루치 작업이 위젯 더미를 남기고 그중 맨 위가 낡은 값을 보여줄 수 있다. `test-menu.ps1`이 dot-source할 때는 잠금을 잡지 않는다 — 안 그러면 위젯이 떠 있을 때 테스트가 아무것도 안 하고 통과한 척한다.

`usage.ps1`의 함수는 넷이다. `Read-Windows`(텍스트 → 사용률, 라이브 응답과 `.claude.json` 양쪽에 같이 쓰임), `Get-ClaudeAccount`, `Sync-ClaudeUsage`(유일하게 네트워크를 탄다), `Get-ClaudeUsage`.

`Get-ClaudeUsage`는 `-ClaudeDir`, `-ConfigPath`, `-CachePath`, `-Now`를 전부 인자로 받는다. 그래서 `test-usage.ps1`이 TEMP에 가짜 `.claude` 트리를 만들어 놓고 시각까지 고정한 채, 네트워크 없이 검증할 수 있다.

`Sync-ClaudeUsage`는 절대 throw하지 않고 상태 문자열을 돌려준다(`ok`, `token expired`, `unrecognized response`, `sync failed: ...`). 동기화 실패가 위젯을 멈추면 안 되고, 로컬 소스만으로도 화면은 계속 돌아야 한다.

**타이머는 둘이다.** 로컬 파일 다시 읽기는 5초, Anthropic 호출은 5분. 화면 갱신 주기에 맞춰 API를 두드리면 안 된다.

ASCII만 쓴다. PowerShell 5.1은 BOM 없는 스크립트를 ANSI로 읽어서 한글 리터럴이 깨지기 때문이다. 한글 라벨은 XAML에만 두고, XAML은 UTF-8로 명시해서 읽는다.

이벤트 핸들러가 공유하는 상태는 `$state` 해시테이블 하나에 모은다. `GetNewClosure()`한 스크립트블록은 복제된 스코프에서 돌기 때문에, 만든 쪽이 나중에 대입한 `$script:` 변수도 감싸는 함수 안에 정의된 함수도 보지 못한다. 해시테이블은 참조로 넘어가므로 통과하고, 핸들러가 부를 헬퍼(`Add-MenuItem`, `Set-OnlyChecked`)는 스크립트 최상위에 둔다.

`widget.ps1`은 ASCII만 쓴다. PowerShell 5.1은 BOM 없는 스크립트를 ANSI로 읽어서 한글 리터럴이 깨지기 때문이다. 한글 라벨은 XAML에만 두고, XAML은 UTF-8로 명시해서 읽는다.

## 7. 보정 값 (하드코딩 금지)

실제 환경은 문서와 어긋난다. 아래 값은 `config.json`에 두고 사용자가 고칠 수 있게 한다.

| 값 | 기본 | 왜 조정 가능해야 하나 |
|---|---|---|
| `windowHours` | 5 | Anthropic이 창 길이를 바꿀 수 있다 |
| `pollSeconds` | 5 | 세션 파일이 많아지면 늘려야 한다 |
| `opacity` | 0.92 | 모니터/취향 차이 |
| `warnPct` / `dangerPct` | 70 / 90 | 노랑·빨강으로 넘어가는 지점 |
| `skin` / `left` / `top` | border / 우하단 | 위젯이 스스로 저장한다 |

`tokenLimit`은 필요 없어졌다. 서버가 계산한 사용률을 그대로 읽기 때문이다.

## 8. 단계

**1단계 — 숫자가 맞는지부터 · 완료**
`Get-ClaudeUsage` + `test-usage.ps1`. 가짜 로그 트리로 13개 항목 검증, 전부 통과. 전체 스캔 267ms.

**2단계 — 창 띄우기 · 완료**
스킨 3종 렌더 확인, 5초 타이머, 드래그 이동, 위치·스킨·불투명도 저장.

**3단계 — 다듬기 · 완료**
색상 경고 단계, 우클릭 메뉴, 시작프로그램 등록 안내(README).

**4단계 — 실제 Claude 연동 · 완료**
`/api/oauth/usage` 라이브 호출(5분 주기 + `Sync now`), `detail` 스킨에 사용자명·구독 배지, 출처 표시. 우클릭 메뉴의 스킨·불투명도를 라디오로 고침(`test-menu.ps1`로 검증).

**5단계 — 배포 준비 · 완료**
스킨 자동 높이(잘림 제거), 7일 막대를 붙인 스킨 변형 추가, 단일 인스턴스 잠금, Claude Code `SessionStart` 훅 설치 스크립트, `.gitignore`, README 전면 개편(설치·실행·자동 실행·연동 방식·문제 해결).

이 단계에서 잡은 버그 둘이 남길 만하다.

`SourceInitialized` 핸들러가 중간에 예외로 끊겨서 그 뒤의 폴링 타이머가 시작되지 않았다. 위젯은 멀쩡히 떠 있는데 첫 프레임에서 멈췄다. 죽은 위젯은 눈에 띄지만 멈춘 위젯은 안 띈다. 그래서 폴링 타이머를 가장 먼저, 무조건 시작하도록 순서를 바꿨다.

남은 시간이 Claude 앱·웹보다 정확히 한 시간 많게 나왔다. `[int]$span.TotalHours`가 원인이다 — PowerShell의 `[int]` 캐스트는 버림이 아니라 반올림이라 `[int]3.58`이 `4`가 된다. 분은 그대로 맞으니 `4h 34m`은 전혀 이상해 보이지 않았고, 없는 한 시간의 여유가 있는 것처럼 읽혔다. `[math]::Floor`로 바꿨다. 예산을 보여주는 숫자는 올림 쪽으로 틀리면 안 된다. 처음에 이 증상을 위의 멈춘 타이머 탓으로 진단한 것은 틀렸다 — 두 버그가 같은 증상을 냈다.

**6단계 (아직 안 함)**
모델별 상세 펼치기, 트레이 아이콘, 마우스 통과 + 전역 단축키.

## 9. 위험 요소

- **JSONL 스키마 변경**: Claude Code 업데이트로 필드명이 바뀌면 집계가 깨진다. 파싱 실패 시 위젯이 죽지 말고 "—"를 표시하고 계속 돌게 한다.
- **세션 파일 잠금**: Claude Code가 쓰는 중인 파일을 읽는다. 반드시 읽기 공유 모드로 열고, 실패하면 다음 폴링에서 재시도한다.
- **파일 수 증가**: 프로젝트가 쌓이면 스캔 대상이 늘어난다. mtime이 세션 창 밖인 파일은 열지 않고 건너뛴다.
- **문서화되지 않은 엔드포인트**: `/api/oauth/usage`는 공개 API가 아니라 Claude Code가 쓰는 것을 그대로 쓴다. 응답 형태가 바뀌면 동기화가 `unrecognized response`를 남기고 직전 캐시를 유지한다 — 화면이 비지 않는다. 그래도 안 되면 (d) 캐시로 자동 폴백된다.
- **토큰 만료**: 액세스 토큰이 만료되면 호출을 건너뛴다. 갱신은 Claude Code의 OAuth 흐름이 할 일이고, 위젯이 그것을 흉내 내지 않는다.
- **캐시가 오래됨**: (d) `cachedUsageUtilization`은 Claude Code가 받아올 때만 갱신된다. 실측 44시간. `resets_at`이 지났으면 %를 숨기고, 아랫줄에 출처와 나이를 항상 적는다.
- **자체 집계 ≠ 서버 집계**: JSONL 합산은 우리가 세는 값이라 Anthropic의 과금·한도 계산과 일치한다는 보장이 없다. 캐시 읽기 토큰이 청구 토큰의 20배를 넘기 때문에 둘을 따로 센다(`WindowBilled` / `WindowCacheRead`).

## 10. 완료 기준

- Claude Code로 작업하는 동안 위젯 숫자가 5초 안에 따라 움직인다.
- `/usage`가 보여주는 값과 세션 창 토큰 합이 일치한다.
- 위젯을 켜 둔 채 1시간 방치했을 때 CPU 점유가 눈에 띄지 않고 메모리가 늘지 않는다.
- Claude Code를 껐다 켜도 위젯이 죽지 않는다.
