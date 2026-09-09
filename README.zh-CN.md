# ClaudMonWidget

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md) · **简体中文** · [Español](README.es.md)

一个半透明、始终置顶的 Windows 小组件，显示你的 Claude Code 用量。

```
┌──────────────────────────────────┐
│  ● 54%                   2h 57m  │
│  ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░  │
│  6%                       6d 4h  │
│  ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
└──────────────────────────────────┘
```

无需安装任何运行时。它只用 Windows 自带的 PowerShell 5.1 和 WPF。不需要
`npm install`，也不需要另外登录 —— 直接复用 Claude Code 已经保存好的凭据。

---

## 目录

- [安装](#安装)
- [运行](#运行)
- [开机自动运行](#开机自动运行)
  - [随 Windows 启动](#随-windows-启动)
  - [随 Claude Code 启动](#随-claude-code-启动)
- [操作](#操作)
- [皮肤](#皮肤)
- [数据从哪里来](#数据从哪里来)
- [配置](#配置)
- [排查](#排查)
- [测试](#测试)
- [构建](#构建)
- [自己写皮肤](#自己写皮肤)
- [已知限制](#已知限制)

---

## 安装

Windows 10/11，装好 Claude Code 并已登录，前提条件就这些。

```powershell
git clone https://github.com/is-an/ClaudMonWidget.git
cd ClaudMonWidget
```

下载 ZIP 解压到任意目录也可以。位置不限，但小组件会把 `config.json` 和
`usage-cache.json` 写进自己所在的文件夹，所以该目录需要可写。避开
`C:\Program Files`。

没有安装程序，也不写注册表。删除时直接删文件夹即可（如果配置过
[自动运行](#开机自动运行)，先解除）。

## 运行

双击 **`start-hidden.vbs`**。不会弹出控制台窗口。

或者从控制台运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1 -Skin detail
```

`-ExecutionPolicy Bypass` 只对这一次启动生效，不会改动系统策略。

仓库里不含 `.exe`。需要的话可以用 [`build.ps1`](#构建) 编出一个 46KB 的启动器，
但它就只是启动器 —— 旁边必须有 `widget.ps1`，单独拿走什么也做不了。它不是可以
单独分发的二进制文件，提交上去也只会招来 SmartScreen 警告。

不过**文件夹本身是便携的**：没有安装程序，不写注册表，`config.json` 和
`usage-cache.json` 都写在脚本旁边，所以配置会跟着走。复制到任何地方都行，包括
U 盘。但用量数字读的是运行所在电脑的 Claude Code 账号，而且[自动运行](#开机自动运行)
的条目保存的是绝对路径，所以移动文件夹之后要重新执行 `install-hook.ps1`。

小组件**同时只运行一个**。已经开着时再启动，第二个会静默退出。这样可以避免多个
小组件在屏幕上叠在一起，而最上面那个显示的是过期数值。

## 开机自动运行

### 随 Windows 启动

1. `Win+R` → `shell:startup` 打开"启动"文件夹。
2. 把 `start-hidden.vbs` 的**快捷方式**放进去。

删除该快捷方式即可解除。如果不喜欢脚本的默认图标，在快捷方式属性里"更改图标"，
指向本文件夹的 `icon.ico` 即可。

### 随 Claude Code 启动

让小组件在 Claude Code 会话开始时一起启动。如果你只在用 Claude 的时候需要它，
这种方式更合适。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1
```

它会在 `~/.claude/settings.json` 的 `hooks.SessionStart` 中加入一条。你已有的钩子
和设置保持不变，执行前会在同目录留一份带时间戳的备份。多次执行不会产生重复条目。

解除：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1 -Uninstall
```

手写的话是这样：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "wscript.exe \"C:\\路径\\ClaudMonWidget\\start-hidden.vbs\""
          }
        ]
      }
    ]
  }
}
```

钩子每个会话都会触发，但小组件是单实例的，所以第一次之后的启动都会立刻退出。

**Claude Code 退出后小组件仍然留着。** 用小组件右键菜单里的 `Exit` 关闭。要让它
随会话结束一起关闭，需要一个杀进程的停止钩子，而那个钩子在其他 Claude 会话还开着
时也会触发，所以没有加进来。

## 操作

| 动作 | 结果 |
|---|---|
| 拖动 | 移动位置。退出时保存到 `config.json` |
| 悬停 | 提示：窗口起始时刻、计费 token、缓存读取 token、数据来源 |
| 右键 | 菜单 |

菜单：

- **Skin** —— `simple1` / `simple2` / `border1` / `border2` / `detail`，单选。
- **Opacity** —— 55 / 75 / 92 / 100%，单选。
- **Always on top** —— 置顶开关。
- **Auto sync** —— 每 5 分钟向 Anthropic 询问的开关。
- **Sync now** —— 立即向 Anthropic 询问。
- **Refresh now** —— 只重读本地文件。
- **Exit** —— 退出。

## 皮肤

五个。名字末尾是 `1` 的只显示 5 小时会话，`2` 的还会显示 7 天窗口。

| 名称 | 宽度 | 内容 |
|---|---|---|
| `simple1` | 150 | 无背景，只有 5 小时数字 |
| `simple2` | 250 | 无背景，5 小时与 7 天两列 |
| `border1` | 270 | 圆角胶囊 + 5 小时进度条 |
| `border2` | 270 | 圆角胶囊 + 5 小时与 7 天进度条 |
| `detail` | 300 | 用户名与套餐徽章、两条进度条、token 与请求数、数据来源 |

默认是 `border2`。高度随内容自适应，所以在放大了字体的机器上也不会截断。

两个窗口都显示到下次重置的**剩余时间**。单位随量级变化 —— 5 小时窗口显示
`3h 04m`，7 天窗口显示 `6d 5h`。`149h 05m` 这种数字记不住。

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

`detail`：

```
ANIN                        [Pro]
─────────────────────────────────
● 5 小时会话              2h 57m
54%
▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░
6%                         6d 4h
▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
807.1k tok / 399 req / live 2m
```

两行遵循同一规则：左边是使用率，右边是剩余时间。

颜色分级：低于 70% 绿色，70% 起黄色，90% 起红色，无数值时灰色。

---

## 数据从哪里来

三个来源，按新鲜程度依次使用。

### 1. 直接问 Anthropic（默认每 5 分钟）

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <访问令牌>
anthropic-beta: oauth-2025-04-20
```

这正是 Claude Code 绘制 `/usage` 时调用的端点，所以小组件的百分比就是 `/usage`
显示的百分比。

令牌用的是 Claude Code 已经存好的那一份：

```
%USERPROFILE%\.claude\.credentials.json  →  claudeAiOauth.accessToken
```

小组件不会要求你登录，也不会把令牌发到上述请求头以外的任何地方。令牌过期时会跳过
调用 —— 刷新是 Claude Code 的 OAuth 流程该做的事，小组件不去模仿它。

响应：

```json
{
  "five_hour": { "utilization": 36.0, "resets_at": "2026-09-09T09:04:59+00:00" },
  "seven_day": { "utilization": 4.0,  "resets_at": "2026-09-15T09:59:59+00:00" },
  "limits": [ ... ],
  "spend": { ... }
}
```

原样保存到小组件目录下的 `usage-cache.json`。

**绝不写入 Claude Code 自己的文件。** `~/.claude.json` 会被 Claude Code 整体重写，
从外部同时写入可能损坏其状态。即使小组件失败或崩溃，Claude Code 那边也不受影响。

### 2. `%USERPROFILE%\.claude.json` → `cachedUsageUtilization`

同样的数值，但只在 Claude Code 自己去取的时候才更新。可能过期好几天。只在来源 1
不可用时才使用。

实测中这份缓存停留了 44 小时，显示 5 小时 70% / 7 天 60%，而同一时刻直接调用来源 1
得到的真实值是 28% / 3%。这就是加入实时调用的原因。

### 3. `%USERPROFILE%\.claude\projects\**\*.jsonl` → assistant 行

```json
"usage": { "input_tokens": 2, "cache_creation_input_tokens": 25110,
           "cache_read_input_tokens": 29894, "output_tokens": 599 }
```

每个请求的 token 数和时间戳，每 5 秒重读一次，完全不走网络。永远是最新的，但这是
我们自己的统计，不是服务端的。

只累加落在会话窗口内的行。窗口起点 = `five_hour.resets_at` − 5 小时。

缓存读取 token 是计费 token 的 20 倍以上，所以分开统计。屏幕上的 `tok` 是计费
token（input + output + 缓存写入），缓存读取只出现在悬停提示里。

### 用户名与套餐

从 `~/.claude.json` 的 `oauthAccount` 块读取 —— 不发网络请求。

| 字段 | 用途 |
|---|---|
| `displayName` | 用户名 |
| `emailAddress` | 用户名的悬停提示 |
| `organizationType` | 套餐徽章 |

`organizationType` 对应关系：`claude_pro`→`Pro`、`claude_max`→`Max`、
`claude_max_5x`→`Max 5x`、`claude_max_20x`→`Max 20x`、`claude_team`→`Team`、
`claude_enterprise`→`Enterprise`。

小组件运行期间不会变化，所以创建窗口时只读一次。

### 你现在看的是哪一份

`detail` 皮肤最底下一行会直接写出来源和它的新旧程度。

| 显示 | 含义 |
|---|---|
| `live now` | 刚从 Anthropic 取到 |
| `live 12m` | 12 分钟前取到的值 |
| `claude-code 2d` | 实时调用失败，正在用 Claude Code 的缓存，已过期两天 |
| `token expired` | 令牌过期。运行一次 Claude Code 即可刷新 |
| `http 429` | 调用过于频繁，下个周期会自行恢复 |
| `http 401` | 认证被拒。重新登录 Claude Code |
| `sync failed` | 网络错误之类 |

重启小组件时，如果缓存比 `syncSeconds`（默认 300 秒）还新，就不会重新去取。这可以
避免 Claude Code 钩子导致的频繁重启把端点打到 `http 429`。`Sync now` 会忽略这个
限制。

如果 `resets_at` 已经过去，那个百分比属于已结束的窗口，因此**不显示**，改为显示
我们自己的 token 统计。绝不把过期数值当作当前值展示，是这个小组件的基本原则。

不显示金额（$）。记录金额的 `cost-state` 行是在会话接近结束时写入的，进行中的会话
文件里没有。

---

## 配置

`config.json` 在小组件第一次退出时创建。大部分项都能用右键菜单改，很少需要直接打开
文件。

| 键 | 默认 | 含义 |
|---|---|---|
| `skin` | `border2` | 启动皮肤。名称不存在时回退到默认 |
| `opacity` | `0.92` | 窗口整体不透明度 |
| `left` / `top` | `-1` | 位置。`-1` 表示自动放到右下角 |
| `pollSeconds` | `5` | 重读本地文件的周期 |
| `syncSeconds` | `300` | 向 Anthropic 询问的周期 |
| `autoSync` | `true` | 自动同步。关闭后只能用 `Sync now` |
| `windowHours` | `5` | 会话窗口长度 |
| `warnPct` / `dangerPct` | `70` / `90` | 转黄、转红的阈值 |

`usage-cache.json` 是最后一次同步的响应。可以删除 —— 下次同步会重新生成。

## 排查

**屏幕上找不到小组件**
`config.json` 里的 `left` / `top` 可能指向一台你已经不用的显示器。删掉该文件重新
启动，它会回到右下角。

**剩余时间和 Claude 应用 / 网页不一致**
两者读的是同一个 `resets_at`，本不该有分歧。如果不一致，多半是小组件版本旧了 ——
检查是否有新版本。秒会被舍去，所以最多相差一分钟属于正常，超过就是 bug。

**数字不动了**
可能是开了很久的旧实例。用 `Exit` 关掉再启动。剩余时间每 5 秒重算一次，正常情况下
每过一分钟应该少一分钟。

**最底行一直停在 `claude-code`**
实时调用一直失败。按 `Sync now` 查看原因。如果是 `token expired`，运行一次
Claude Code 让令牌刷新。

**只显示 token 数，不显示 `%`**
说明手头只有已结束窗口的数值。按 `Sync now`，或在 Claude Code 里执行一次 `/usage`。

**脚本执行被拦截**
`start-hidden.vbs` 以及上面的命令都只对本次启动应用 `-ExecutionPolicy Bypass`。
如果仍被拦截，可能是组织策略。

## 测试

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test-usage.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File test-menu.ps1
```

`test-usage.ps1` 会在 TEMP 里造一棵假的 `.claude` 目录树并固定基准时刻，然后检验
汇总、账户解析、来源优先级和回退。它不走网络，也不依赖真实日志的内容，所以任何时候
运行结果都一样。

`test-menu.ps1` 检验右键菜单是否真的表现为单选。WPF 的 `MenuItem` 没有单选模式，
放着不管的话不透明度会被同时选中多项。

## 构建

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
```

它用 `System.Drawing` 画出 `icon.ico`，手工拼装 `.ico`，再用 Windows 自带的
.NET Framework C# 编译器编译 `ClaudMonWidget.exe`。不下载任何东西。

`icon.ico` 已提交；exe 没有，而且写进了 gitignore —— 它只是启动同目录下的
`widget.ps1`，不适合单独拿走，而 `start-hidden.vbs` 无需编译就能做同样的事。
只有想要一个带图标、可双击的文件时才需要构建它。

## 自己写皮肤

加一个 `skins\<名称>.xaml` 文件就行，`widget.ps1` 不用改。

宿主用 `FindName` 查找下列名称，**只填存在的那些**，所以你想要哪些就放哪些。

| `x:Name` | 类型 | 填入的内容 |
|---|---|---|
| `Dot` | Shape | 状态颜色 |
| `TxtMain` | TextBlock | 5 小时使用率；没有数值时显示自己的 token 统计 |
| `TxtReset` | TextBlock | 距 5 小时重置的剩余时间（`3h 04m`），未知为 `--` |
| `TxtWeek` | TextBlock | 7 天使用率 |
| `TxtWeekReset` | TextBlock | 距 7 天重置的剩余时间（`6d 5h`），未知为 `--` |
| `TxtSub` | TextBlock | `563.0k tok / 249 req / live now` |
| `TxtUser` | TextBlock | 用户名（悬停提示里是邮箱） |
| `TxtPlan` | TextBlock | 套餐徽章 |
| `BarTrack` / `BarFill` | Border | 5 小时进度条 |
| `WeekTrack` / `WeekFill` | Border | 7 天进度条 |
| `Root` | 任意容器 | 右键菜单挂载的位置 |

`Window` 需要 `WindowStyle="None"`、`AllowsTransparency="True"` 和
`Background="Transparent"`。高度用 `SizeToContent="Height"`，字号不同也不会被截断。

要让新皮肤出现在右键菜单里，把名称加进 `widget.ps1` 上方的 `$Skins` 数组，以及
`-Skin` 参数的 `ValidateSet`。

```powershell
$Skins = @('simple1','simple2','border1','border2','detail')
```

如果 `config.json` 指向一个已不存在的皮肤名，小组件会回退到默认皮肤，而不是拒绝启动。

## 已知限制

- 自己的 token 统计不保证与 Anthropic 的计费和限额算法一致。屏幕上的 `%` 是服务端的
  数值，`tok` 是我们自己的统计。
- `/api/oauth/usage` 不是有公开文档的 API。小组件用的就是 Claude Code 用的那个。
  如果响应结构变了，同步会记下 `unrecognized response` 并**保留上一份可用缓存** ——
  界面不会变空。
- 没有鼠标穿透。开启后右键菜单就点不到了，还得再搭一个全局热键。
- 如果 Claude Code 更新改了 JSONL 的字段名，统计可能归零。这种情况下小组件不会崩溃，
  只显示 `--`。
- 仅限 Windows，绑定在 WPF 上。

## 在 PowerShell 5.1 上踩过的坑

写下来是为了下次修改时不再踩。这些都不会报错，只会安静地给出错误的值。

- **不要用 `ConvertFrom-Json` 解析 `~/.claude.json`。** 它里面有一张以绝对路径为键的
  项目映射，而解析器对键不区分大小写，于是 `c:\...` 和 `C:\...` 作为重复键冲突，
  整个解析抛异常。改用正则只取需要的那几个值。
- **不要在 `.ps1` 里放非 ASCII 字符。** 没有 BOM 的脚本会被当作 ANSI 读取，字符会乱码。
  本地化文案只放在 XAML 里，并显式以 UTF-8 读取。同样的道理，绝不要用
  `Get-Content | Set-Content` 往返改写这些文件。
- **用 `GetNewClosure()` 的脚本块运行在克隆的作用域里。** 它既看不到创建方之后赋值的
  `$script:` 变量，也看不到定义在外层函数内部的函数。共享状态放进一个哈希表按引用传递，
  处理器要调用的辅助函数放到脚本顶层。忽略这点导致 `SourceInitialized` 处理器中途抛
  异常，它后面的轮询计时器就没启动。小组件看上去好端端地开着，实际停在第一帧 ——
  崩掉的小组件很显眼，停住的不显眼。所以现在轮询计时器**第一个、无条件**启动。
- **`[int]` 转换是四舍五入，不是截断。** `[int]3.58` 是 `4`。用
  `[int]$span.TotalHours` 算剩余时间，把 3 小时 34 分变成了 `4h 34m`。分钟仍然正确，
  所以看起来毫无破绽，读起来却像多出一小时并不存在的额度。切小时用 `[math]::Floor`。
  表示额度的数字不能往多了偏。
- **`return $数组` 会在管道里被展开。** 调用方拿到的是装箱元素的 `object[]`，不是要的
  `byte[]`。`.Length` 依然正确，所以图标目录看着没问题，而 `BinaryWriter.Write` 选中了
  另一个重载，每项只写 1 字节 —— 生成一个头部完美、没有图像的 108 字节 `.ico`。
  要写成 `, $数组`。
- **在 `StrictMode 2.0` 下不要对管道结果用 `.Count`。** 只有一个结果时返回的是标量，
  `.Count` 会抛异常。如果这发生在参数求值过程中，整个检查会被跳过 —— 测试就会安静地
  假装通过。用 `@(...)` 包起来。
