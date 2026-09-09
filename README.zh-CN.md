# ClaudMonWidget

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md) · **简体中文** · [Español](README.es.md)

一个半透明、始终置顶的 Windows 小组件，显示你的 Claude Code 用量。

```
┌─────────────────────────────────┐
│ ANIN                      [Pro] │
│ ─────────────────────────────── │
│ ● 5 小时会话             2h 57m │
│ 54%                             │
│ ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░  │
│ 6%                        6d 4h │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│ 807.1k tok / 399 req / live 2m  │
└─────────────────────────────────┘
```

无需安装任何东西。它只用 Windows 自带的 PowerShell 5.1 和 WPF，并直接复用
Claude Code 已经保存好的凭据。不需要 `npm install`，也不需要另外登录。

## 安装

Windows 10/11，装好 Claude Code 并已登录，前提条件就这些。

```powershell
git clone https://github.com/is-an/ClaudMonWidget.git
```

下载 ZIP 解压到任意目录也可以。小组件会把 `config.json` 和 `usage-cache.json`
写进自己所在的文件夹，所以该目录需要可写（避开 `C:\Program Files`）。没有安装程序，
也不写注册表，删除时直接删文件夹即可。

## 运行

双击 **`start-hidden.vbs`**，不会弹出控制台窗口。或者：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1 -Skin detail
```

`-ExecutionPolicy Bypass` 只对这一次启动生效，不改动系统策略。

小组件**同时只运行一个**。已经开着时再启动会静默退出，因此不会多个叠在一起、
最上面那个还显示过期数值。

**文件夹是便携的** —— 复制到任何地方（包括 U 盘），配置会跟着走。但用量数字读的
始终是运行所在电脑的 Claude Code 账号。

## 开机自动运行

**随 Windows 启动** —— `Win+R` → `shell:startup`，把 `start-hidden.vbs` 的快捷方式
放进去。在"更改图标"里指向 `icon.ico` 就不用忍受脚本的默认图标。删除快捷方式即可解除。

**随 Claude Code 启动** —— 每个会话开始时一起启动：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1 -Uninstall
```

它会在 `~/.claude/settings.json` 的 `hooks.SessionStart` 中加入一条，保留你已有的
钩子，执行前留一份带时间戳的备份，多次执行也不会重复。两种方式都保存绝对路径，
所以移动文件夹之后要重新执行。

**Claude Code 退出后小组件仍然留着**，用右键菜单的 `Exit` 关闭。

## 操作

拖动可移动。悬停会显示窗口起始时刻和 token 明细。右键菜单：

- **Skin**、**Opacity** —— 各自单选。
- **Always on top**、**Auto sync** —— 开关。
- **Sync now** —— 立即向 Anthropic 询问。**Refresh now** —— 只重读本地文件。
- **Exit**。

## 皮肤

名字末尾是 `1` 的只显示 5 小时会话，`2` 的还会显示 7 天窗口。默认 `border2`。

| 名称 | 宽度 | 内容 |
|---|---|---|
| `simple1` | 150 | 无背景，只有 5 小时数字 |
| `simple2` | 250 | 无背景，5 小时与 7 天两列 |
| `border1` | 270 | 圆角胶囊 + 5 小时进度条 |
| `border2` | 270 | 圆角胶囊 + 两条进度条 |
| `detail` | 300 | 用户名与套餐徽章、两条进度条、token 与请求数、数据来源 |

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

`detail` 就是本页顶部那个。

每一行都遵循同一规则：左边使用率，右边剩余时间，单位随量级变化（`3h 04m`、
`6d 5h`）。高度随内容自适应，放大字体也不会截断。颜色：低于 70% 绿色，70% 起黄色，
90% 起红色，无数值时灰色。

加皮肤只需一个 `skins\<名称>.xaml` 文件 —— 元素约定见 PLAN.md。

## 数据从哪里来

三个来源，按新鲜程度依次使用。

**1. 直接问 Anthropic，每 5 分钟。**
`GET https://api.anthropic.com/api/oauth/usage`，请求头为
`Authorization: Bearer <令牌>` 和 `anthropic-beta: oauth-2025-04-20`。这正是
Claude Code 绘制 `/usage` 时调用的端点，所以百分比一致。令牌读的是
`%USERPROFILE%\.claude\.credentials.json` 里已有的那份 —— 小组件不要求你登录，
也不会把令牌发到别处。响应保存到 `usage-cache.json`。
**绝不写入 Claude Code 自己的文件。**

**2. `%USERPROFILE%\.claude.json` → `cachedUsageUtilization`。**
同样的数值，但只在 Claude Code 自己去取时才更新。实测中它停留了 44 小时显示 70%，
而同一时刻的实时值是 28%。仅作为来源 1 不可用时的备用。

**3. `%USERPROFILE%\.claude\projects\**\*.jsonl`。**
每个请求的 token 数，不走网络、每 5 秒重读一次。这是我们自己的统计，不是服务端的。
屏幕上的 `tok` 是计费 token，超过 20 倍的缓存读取只出现在悬停提示里。

用户名和套餐徽章从 `~/.claude.json` 的 `oauthAccount` 读取，不发网络请求，只读一次。

`detail` 最底行会写明来源和新旧 —— `live now`、`claude-code 2d`，或者
`token expired`、`http 429` 之类的失败原因。`resets_at` 已过去的百分比属于已结束的
窗口，因此**不显示**：绝不把过期数值当作当前值展示，是这个小组件的基本原则。轮询
一旦发现窗口翻页就立刻去取新窗口，所以空档只有几秒。

不显示金额（$）。记录金额的 `cost-state` 行在会话接近结束时才写入，进行中的会话
里没有。

## 配置

`config.json` 在第一次退出时创建，大部分项用右键菜单就能改。

| 键 | 默认 | 含义 |
|---|---|---|
| `skin` | `border2` | 启动皮肤。名称不存在时回退到默认 |
| `opacity` | `0.92` | 窗口不透明度 |
| `left` / `top` | `-1` | 位置。`-1` 表示右下角 |
| `pollSeconds` | `5` | 重读本地文件的周期 |
| `syncSeconds` | `300` | 向 Anthropic 询问的周期 |
| `autoSync` | `true` | 关闭后只能用 `Sync now` |
| `windowHours` | `5` | 会话窗口长度 |
| `warnPct` / `dangerPct` | `70` / `90` | 转黄、转红的阈值 |

`usage-cache.json` 是最后一次同步的响应，可以删除。

## 排查

| 现象 | 处理 |
|---|---|
| 屏幕上找不到 | `left` / `top` 可能指向已不存在的显示器。删掉 `config.json` |
| 数字不动，或只有 token 数没有 `%` | `Exit` 后重启，或按 `Sync now` 看最底行的原因 |
| 最底行是 `token expired` | 运行一次 Claude Code 让令牌刷新 |
| 剩余时间和 Claude 应用不一致 | 两者读同一个 `resets_at`，先确认是否最新版本。秒会舍去，差一分钟属正常 |
| 脚本执行被拦截 | 这里的命令都按次应用 `-ExecutionPolicy Bypass`。仍被拦截多半是组织策略 |

## 开发

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test-usage.ps1   # 汇总，离线
powershell -NoProfile -ExecutionPolicy Bypass -File test-menu.ps1    # 菜单与事件接线
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1        # icon.ico + 启动器 exe
```

测试会在 TEMP 里造一棵假的 `.claude` 目录树并固定基准时刻，因此不走网络，任何时候
运行结果都一样。`icon.ico` 已提交，exe 没有 —— 它只是启动同目录下的 `widget.ps1`，
单独没有意义，而 `start-hidden.vbs` 无需编译就能做同样的事。

设计笔记、皮肤元素约定，以及踩过的 PowerShell 5.1 的坑，都在 PLAN.md 里。

## 已知限制

- 自己的 token 统计不保证与 Anthropic 的计费一致。屏幕上的 `%` 才是服务端的数值。
- `/api/oauth/usage` 不是有公开文档的 API。响应结构一变，同步会记下
  `unrecognized response` 并保留上一份可用缓存。
- 没有鼠标穿透。开启后右键菜单就点不到了。
- 仅限 Windows，绑定在 WPF 上。
