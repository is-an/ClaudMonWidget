# ClaudMonWidget

[English](README.md) · **한국어** · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md)

Claude Code 토큰 사용량을 보여주는 Windows 반투명 위젯. 항상 화면 위에 뜬다.

```
┌─────────────────────────────────┐
│ ANIN                      [Pro] │
│ ─────────────────────────────── │
│ ● 5시간 세션             2h 57m │
│ 54%                             │
│ ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░  │
│ 6%                        6d 4h │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│ 807.1k tok / 399 req / live 2m  │
└─────────────────────────────────┘
```

설치할 것이 없다. Windows에 기본으로 들어 있는 PowerShell 5.1 + WPF만 쓰고,
Claude Code가 이미 저장해 둔 인증 토큰을 그대로 쓴다. `npm install`도 별도
로그인도 없다.

## 설치

Windows 10/11 + Claude Code가 설치되어 로그인된 상태면 준비 끝이다.

```powershell
git clone https://github.com/is-an/ClaudMonWidget.git
```

ZIP으로 받아 아무 폴더에나 풀어도 된다. 위젯이 `config.json`과
`usage-cache.json`을 그 폴더에 쓰므로 쓰기 권한이 필요하다 — `C:\Program Files`
아래는 피할 것. 설치 스크립트도 레지스트리 등록도 없으니, 지울 때는 폴더를
삭제하면 된다.

## 실행

**`start-hidden.vbs`**를 더블클릭한다. 콘솔 창이 뜨지 않는다. 또는:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1 -Skin detail
```

`-ExecutionPolicy Bypass`는 이 실행에만 적용되고 시스템 정책을 바꾸지 않는다.

위젯은 **한 번에 하나만** 뜬다. 이미 떠 있는데 또 실행하면 조용히 종료되므로,
위젯이 겹쳐 쌓이고 그중 오래된 것이 낡은 값을 보여주는 일이 없다.

**폴더 자체는 포터블**이다. USB를 포함해 어디로 복사해도 설정이 따라간다. 다만
사용량 숫자는 실행하는 PC의 Claude Code 계정에서 읽는다.

## 자동 실행

**Windows 시작 시** — `Win+R` → `shell:startup`에 `start-hidden.vbs` 바로가기를
넣는다. 아이콘 변경에서 `icon.ico`를 지정하면 기본 스크립트 아이콘을 면한다.
해제는 바로가기 삭제.

**Claude Code 실행 시** — 세션마다 같이 뜨게 한다:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1 -Uninstall
```

`~/.claude/settings.json`의 `hooks.SessionStart`에 항목 하나를 추가한다. 기존 훅은
그대로 두고 실행 전에 타임스탬프 백업을 남기며, 여러 번 실행해도 중복되지 않는다.
두 방식 모두 절대 경로를 저장하므로 폴더를 옮긴 뒤에는 다시 실행해야 한다.

**Claude Code가 끝나도 위젯은 남는다.** 우클릭 메뉴의 `Exit`로 닫는다.

## 조작

드래그로 이동. 마우스를 올리면 창 시작 시각과 토큰 내역이 툴팁으로 뜬다.
우클릭 메뉴:

- **Skin**, **Opacity** — 각각 하나만 선택된다.
- **Always on top**, **Auto sync** — 토글.
- **Sync now** — 지금 Anthropic에 물어본다. **Refresh now** — 로컬 파일만 다시 읽는다.
- **Exit**.

## 스킨

뒤에 `1`이 붙은 것은 5시간 세션만, `2`는 7일까지 보여준다. 기본값 `border2`.

| 이름 | 폭 | 내용 |
|---|---|---|
| `simple1` | 150 | 배경 없이 5시간 숫자만 |
| `simple2` | 250 | 배경 없이 5시간 + 7일, 2열 |
| `border1` | 270 | 둥근 알약 + 5시간 막대 |
| `border2` | 270 | 둥근 알약 + 두 막대 |
| `detail` | 300 | 사용자명 + 구독 배지, 두 막대, 토큰·요청 수, 데이터 출처 |

```
simple1            simple2
  ● 54%              ● 54%  │  6%
  2h 57m             2h 57m │  6d 4h

border1                     border2
┌──────────────────────┐    ┌──────────────────────┐
│ ● 54%        2h 57m  │    │ ● 54%        2h 57m  │
│ ▓▓▓▓▓▓▓░░░░░░░░░░░░  │    │ ▓▓▓▓▓▓▓░░░░░░░░░░░░  │
└──────────────────────┘    │ 6%             6d 4h │
                            │ ▓░░░░░░░░░░░░░░░░░░  │
                            └──────────────────────┘
```

`detail`은 이 문서 맨 위에 있는 것이다.

모든 행이 같은 규칙이다: 왼쪽에 사용률 %, 오른쪽에 남은 시간. 단위는 크기에 맞춰
바뀐다(`3h 04m`, `6d 5h`). 높이는 내용에 맞춰 정해지므로 글꼴을 키워도 잘리지
않는다. 색: 70% 미만 초록, 70% 이상 노랑, 90% 이상 빨강, 값 없으면 회색.

스킨 추가는 `skins\<이름>.xaml` 파일 하나면 된다 — 요소 계약은 PLAN.md 참고.

## 숫자가 어디서 오나

세 군데. 신선한 순서대로 쓴다.

**1. Anthropic에 직접, 5분마다.**
`GET https://api.anthropic.com/api/oauth/usage`,
헤더는 `Authorization: Bearer <토큰>`과 `anthropic-beta: oauth-2025-04-20`.
Claude Code가 `/usage`를 그릴 때 부르는 바로 그 엔드포인트라 %가 일치한다. 토큰은
`%USERPROFILE%\.claude\.credentials.json`에 이미 있는 것을 읽는다 — 위젯은 별도
로그인을 요구하지 않고 토큰을 다른 어디로도 보내지 않는다. 응답은
`usage-cache.json`에 저장한다. **Claude Code의 파일에는 절대 쓰지 않는다.**

**2. `%USERPROFILE%\.claude.json` → `cachedUsageUtilization`.**
같은 숫자지만 Claude Code가 받아올 때만 갱신되는 캐시다. 실측에서 44시간 묵은 채
70%를 가리켰고 같은 순간 라이브 값은 28%였다. 1번을 못 쓸 때의 대비책일 뿐이다.

**3. `%USERPROFILE%\.claude\projects\**\*.jsonl`.**
요청별 토큰 수. 네트워크 없이 5초마다 다시 읽는다. 서버 집계가 아니라 자체
집계다. 화면의 `tok`은 청구 토큰이고, 20배가 넘는 캐시 읽기는 툴팁에만 나온다.

사용자명과 구독 배지는 `~/.claude.json`의 `oauthAccount`에서 네트워크 없이 한 번만
읽는다.

`detail` 맨 아랫줄이 출처와 나이를 적는다 — `live now`, `claude-code 2d`, 또는
`token expired` · `http 429` 같은 실패 사유. `resets_at`이 지난 %는 끝난 창의
것이므로 **표시하지 않는다**. 오래된 숫자를 현재 값인 척 보여주지 않는 것이 이
위젯의 원칙이다. 폴링이 창 넘어감을 감지하면 즉시 새 창을 받아오므로 그 공백은
몇 초다.

비용($)은 표시하지 않는다. 비용을 기록하는 `cost-state` 줄은 세션이 끝날 때쯤
쓰이므로 진행 중인 세션에는 없다.

## 설정

`config.json`은 첫 종료 때 만들어진다. 대부분 우클릭 메뉴로 바뀐다.

| 키 | 기본 | 뜻 |
|---|---|---|
| `skin` | `border2` | 시작 스킨. 없는 이름이면 기본값으로 되돌린다 |
| `opacity` | `0.92` | 창 불투명도 |
| `left` / `top` | `-1` | 위치. `-1`이면 우하단 |
| `pollSeconds` | `5` | 로컬 파일 다시 읽는 주기 |
| `syncSeconds` | `300` | Anthropic에 물어보는 주기 |
| `autoSync` | `true` | 끄면 `Sync now`로만 갱신 |
| `windowHours` | `5` | 세션 창 길이 |
| `warnPct` / `dangerPct` | `70` / `90` | 노랑 / 빨강 전환 지점 |

`usage-cache.json`은 마지막 동기화 응답이다. 지워도 된다.

## 문제 해결

| 증상 | 조치 |
|---|---|
| 화면에 안 보인다 | `left` / `top`이 지금 없는 모니터를 가리킬 수 있다. `config.json` 삭제 |
| 멈췄거나 `%` 대신 토큰 수 | `Exit` 후 재실행, 또는 `Sync now` 누르고 아랫줄 사유 확인 |
| 아랫줄이 `token expired` | Claude Code를 한 번 실행하면 토큰이 갱신된다 |
| 남은 시간이 Claude 앱과 다르다 | 같은 `resets_at`을 읽는다. 최신 버전인지 확인. 초를 버리므로 1분 차이는 정상 |
| 스크립트 실행 차단 | 여기 명령은 모두 실행 단위로 `-ExecutionPolicy Bypass`를 쓴다. 그래도 막히면 조직 정책 |

## 개발

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test-usage.ps1   # 집계, 오프라인
powershell -NoProfile -ExecutionPolicy Bypass -File test-menu.ps1    # 메뉴·이벤트 배선
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1        # icon.ico + 런처 exe
```

테스트는 TEMP에 가짜 `.claude` 트리를 만들고 기준 시각까지 고정하므로, 네트워크를
타지 않고 언제 돌려도 결과가 같다. `icon.ico`는 커밋되어 있지만 exe는 아니다 —
`widget.ps1`을 띄우는 것이 전부고 `start-hidden.vbs`가 컴파일 없이 같은 일을 한다.
설계 노트, 스킨 요소 계약, 밟은 PowerShell 5.1 지뢰는 PLAN.md에 있다.

## 알려진 제약

- 자체 토큰 집계는 Anthropic의 과금과 일치한다는 보장이 없다. `%`가 서버 값이다.
- `/api/oauth/usage`는 문서화된 API가 아니다. 응답 형태가 바뀌면 동기화가
  `unrecognized response`를 남기고 직전 캐시를 유지한다.
- 마우스 통과는 없다. 켜면 우클릭 메뉴에 닿을 수 없어진다.
- Windows 전용. WPF에 묶여 있다.
