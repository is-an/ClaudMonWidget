# ClaudMonWidget

[English](README.md) · [한국어](README.ko.md) · **日本語** · [简体中文](README.zh-CN.md) · [Español](README.es.md)

Claude Code の使用量を表示する、半透明で常に最前面の Windows ウィジェット。

```
┌──────────────────────────────────┐
│  ● 54%                   2h 57m  │
│  ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░  │
│  6%                       6d 4h  │
│  ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
└──────────────────────────────────┘
```

インストールするものはありません。Windows 標準の PowerShell 5.1 と WPF だけで
動き、Claude Code が保存済みの認証情報をそのまま使います。`npm install` も別途の
ログインも不要です。

## インストール

Windows 10/11 に Claude Code が入っていてログイン済みなら、前提はそれだけです。

```powershell
git clone https://github.com/is-an/ClaudMonWidget.git
```

ZIP をどこかに展開しても構いません。ウィジェットが `config.json` と
`usage-cache.json` を自分のフォルダーに書くため、そこは書き込み可能である必要が
あります（`C:\Program Files` の下は避けてください）。インストーラーもレジストリ
登録もないので、削除はフォルダーごと消すだけです。

## 起動

**`start-hidden.vbs`** をダブルクリックします。コンソールは出ません。または:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1 -Skin detail
```

`-ExecutionPolicy Bypass` はその起動にだけ効き、システムのポリシーは変えません。

ウィジェットは**同時に 1 つだけ**動きます。起動中にもう一度実行しても静かに終了
するので、ウィジェットが重なって古い値を見せることはありません。

**フォルダーはポータブル**です。USB を含めどこへコピーしても設定が一緒に移動します。
ただし使用量の数値は、実行するその PC の Claude Code アカウントから読みます。

## 自動起動

**Windows 起動時** — `Win+R` → `shell:startup` に `start-hidden.vbs` の
ショートカットを置きます。アイコンの変更で `icon.ico` を指定すれば既定のスクリプト
アイコンを避けられます。解除はショートカットの削除だけです。

**Claude Code 起動時** — セッションごとに一緒に立ち上げます:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1 -Uninstall
```

`~/.claude/settings.json` の `hooks.SessionStart` に項目を 1 つ追加します。既存の
フックはそのままで、実行前にタイムスタンプ付きバックアップを残し、複数回実行しても
重複しません。どちらの方法も絶対パスを保存するため、フォルダーを移したら実行し直して
ください。

**Claude Code を終了してもウィジェットは残ります。** 右クリック メニューの `Exit`
で閉じます。

## 操作

ドラッグで移動。ホバーするとウィンドウ開始時刻とトークンの内訳がツールチップに
出ます。右クリック メニュー:

- **Skin**、**Opacity** — それぞれ 1 つだけ選択。
- **Always on top**、**Auto sync** — トグル。
- **Sync now** — 今すぐ Anthropic へ問い合わせ。**Refresh now** — ローカル ファイルのみ再読み込み。
- **Exit**。

## スキン

末尾の `1` は 5 時間セッションのみ、`2` は 7 日間の枠も表示します。既定は
`border2`。

| 名前 | 幅 | 内容 |
|---|---|---|
| `simple1` | 150 | 背景なし、5 時間の数値だけ |
| `simple2` | 250 | 背景なし、5 時間と 7 日間の 2 列 |
| `border1` | 270 | 角丸のピル + 5 時間バー |
| `border2` | 270 | 角丸のピル + 両方のバー |
| `detail` | 300 | ユーザー名とプラン バッジ、両方のバー、トークン数とリクエスト数、データ元 |

どの行も同じ規則です。左に使用率、右に残り時間、単位は規模に合わせて変わります
(`3h 04m`、`6d 5h`)。高さは内容に合わせて決まるので、フォントを拡大しても切れま
せん。色は 70% 未満が緑、70% 以上が黄、90% 以上が赤、値がなければ灰色です。

スキンの追加は `skins\<名前>.xaml` を 1 つ足すだけです（要素の取り決めは PLAN.md）。

## 数値の取得元

3 つ。新しい順に使います。

**1. Anthropic に直接、5 分ごと。**
`GET https://api.anthropic.com/api/oauth/usage`、ヘッダーは
`Authorization: Bearer <トークン>` と `anthropic-beta: oauth-2025-04-20`。
Claude Code が `/usage` を描くときに呼ぶのと同じエンドポイントなので % は一致します。
トークンは `%USERPROFILE%\.claude\.credentials.json` にあるものを読みます —
ウィジェットはログインを求めず、トークンを他のどこにも送りません。応答は
`usage-cache.json` に保存します。**Claude Code のファイルには一切書きません。**

**2. `%USERPROFILE%\.claude.json` → `cachedUsageUtilization`。**
同じ数値ですが、Claude Code が取得したときにしか更新されないキャッシュです。実測で
44 時間古いまま 70% を示し、同じ瞬間のライブ値は 28% でした。1 が使えないときの備え
にすぎません。

**3. `%USERPROFILE%\.claude\projects\**\*.jsonl`。**
リクエストごとのトークン数。ネットワークなしで 5 秒ごとに読み直します。サーバーの
集計ではなく自前の集計です。画面の `tok` は課金トークンで、20 倍を超えるキャッシュ
読み取りはツールチップにだけ出ます。

ユーザー名とプラン バッジは `~/.claude.json` の `oauthAccount` から、ネットワーク
なしで一度だけ読みます。

`detail` の最下行が取得元とその古さを示します — `live now`、`claude-code 2d`、
あるいは `token expired`・`http 429` などの失敗理由。`resets_at` が過ぎた % は
終わった枠のものなので**表示しません**。古い数値を現在の値のように見せないのがこの
ウィジェットの原則です。ポーリングが枠の切り替わりに気づくとすぐ新しい枠を取りに
行くので、その空白は数秒です。

金額（$）は表示しません。それを記録する `cost-state` 行はセッション終盤に書かれる
ため、進行中のセッションには存在しません。

## 設定

`config.json` は最初の終了時に作られます。ほとんどは右クリック メニューで変わります。

| キー | 既定 | 意味 |
|---|---|---|
| `skin` | `border2` | 起動時のスキン。存在しない名前なら既定に戻る |
| `opacity` | `0.92` | ウィンドウの不透明度 |
| `left` / `top` | `-1` | 位置。`-1` なら右下 |
| `pollSeconds` | `5` | ローカル ファイルを読み直す周期 |
| `syncSeconds` | `300` | Anthropic へ問い合わせる周期 |
| `autoSync` | `true` | オフなら `Sync now` のみ |
| `windowHours` | `5` | セッション枠の長さ |
| `warnPct` / `dangerPct` | `70` / `90` | 黄・赤に切り替わる位置 |

`usage-cache.json` は最後の同期応答です。消しても構いません。

## トラブルシューティング

| 症状 | 対処 |
|---|---|
| 画面に見当たらない | `left` / `top` が今はないモニターを指しているかもしれません。`config.json` を削除 |
| 止まっている / `%` でなくトークン数 | `Exit` して起動し直すか、`Sync now` を押して最下行の理由を確認 |
| 最下行が `token expired` | Claude Code を一度起動すればトークンが更新されます |
| 残り時間が Claude アプリと違う | 同じ `resets_at` を読みます。最新版か確認を。秒は切り捨てるので 1 分の差は正常 |
| スクリプトの実行がブロックされる | ここの命令はすべて起動単位で `-ExecutionPolicy Bypass` を使います。それでも止まるなら組織のポリシー |

## 開発

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test-usage.ps1   # 集計、オフライン
powershell -NoProfile -ExecutionPolicy Bypass -File test-menu.ps1    # メニューとイベント配線
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1        # icon.ico + ランチャー exe
```

テストは TEMP に偽の `.claude` ツリーを作り基準時刻を固定するので、ネットワークを
使わず、いつ走らせても同じ結果になります。`icon.ico` はコミット済みですが exe は
違います — 自分のフォルダーの `widget.ps1` を起動するだけで単独では意味がなく、
`start-hidden.vbs` がコンパイルなしで同じ仕事をするからです。

設計メモ、スキンの要素の取り決め、踏んだ PowerShell 5.1 の罠は PLAN.md にあります。

## 既知の制限

- 自前のトークン集計が Anthropic の課金と一致する保証はありません。`%` がサーバーの
  値です。
- `/api/oauth/usage` は文書化された API ではありません。形が変われば同期は
  `unrecognized response` を残し、直前のキャッシュを保持します。
- クリック透過はありません。有効にすると右クリック メニューに届かなくなります。
- Windows 専用。WPF に依存しています。
