# OpenClaw 项目介绍

> 语言：TypeScript | 运行时：Node 22+ | 许可证：MIT

---

## 一句话定位

**OpenClaw 是一个自托管的个人 AI 助手网关**，把 23+ 个聊天平台（WhatsApp、Telegram、Slack、Discord、Signal、iMessage 等）统一接入一个 AI Agent，在你自己的设备上运行，数据不经过第三方。

---

## 核心数字

| 指标 | 数值 |
|------|------|
| 语言 | TypeScript（ESM + strict mode）|
| 通道集成 | **23+**（含 Signal、iMessage、IRC、Matrix、Nostr）|
| 内置工具 | **70+** |
| 内置技能库 | **50+** SKILL.md |
| 扩展插件 | **33+** |
| 原生应用 | macOS（Swift）、iOS（Swift）、Android（Kotlin）|
| 测试覆盖率 | 70%+ |
| 存储 | SQLite-vec + JSONL（无需外部数据库）|
| 部署 | npm 包 + systemd/launchd，支持 Docker |

---

## 项目结构

```
openclaw/
├── src/
│   ├── agents/          Agent 运行时（70+ 工具、沙箱、Auth 轮换）
│   ├── gateway/         HTTP/WS 服务器 + 认证
│   ├── channels/        消息通道适配器（Telegram、Discord 等）
│   ├── canvas-host/     A2UI 交互式 Canvas 宿主
│   ├── memory/          向量内存（SQLite-vec / LanceDB）
│   ├── skills/          技能加载器（BM25 索引）
│   └── config/          JSON5 配置 + 热重载
├── extensions/          33+ 可选插件（通道、内存后端、Auth、OTel）
├── apps/
│   ├── macos/           SwiftUI 菜单栏应用
│   ├── ios/             Swift iOS 节点应用
│   └── android/         Kotlin Android 应用
├── ui/web/              React 19 + Vite 控制面板 + WebChat
└── skills/              50+ 内置技能（GitHub、Slack、Canvas、Obsidian…）
```

---

## Agent 执行机制

采用 **Pi 嵌入式运行时**，标准的 Think→Act→Observe 循环：

```
用户消息
    ↓
队列模式（main / followup / collect / steer）
    ↓
LLM 推理（Anthropic / OpenAI / Gemini 等）
    ↓
工具调用（文件、执行、浏览器、Canvas、内存…）
    ↓
上下文压缩（>75% 时自动摘要）
    ↓
回复 → 路由到原始通道
```

**Bootstrap 文件**（每个 Agent 的个性化配置）：
```
~/.openclaw/agents/<id>/workspace/
├── AGENTS.md     操作指令 + 长期记忆
├── SOUL.md       人设、语调、边界
├── IDENTITY.md   名字、表情
├── USER.md       用户档案
├── TOOLS.md      工具使用笔记
└── BOOTSTRAP.md  首次初始化（自动删除）
```

---

## 70+ 工具

| 类别 | 工具 |
|------|------|
| 文件 I/O | read、write、edit、delete、glob、search |
| 代码执行 | exec（bash，白名单 + deny 模式）|
| 浏览器 | screenshot、click、fill、navigate（Playwright）|
| Canvas | push、eval、reset（A2UI 交互式 UI）|
| 向量内存 | memory.save、memory.get、memory.search |
| 定时任务 | cron.at、cron.every、cron.schedule |
| 会话 | sessions.list、sessions.reset |
| 通道工具 | discord.send、telegram.send、slack.thread… |
| 子 Agent | subagent.create、subagent.call |

---

## 23+ 通道集成

| 通道 | 特点 |
|------|------|
| WhatsApp | Baileys web 协议 |
| Telegram | grammY（官方支持）|
| Slack | Bolt SDK |
| Discord | discord.js |
| Google Chat | Chat API |
| Signal | signal-cli |
| iMessage / BlueBubbles | 苹果原生（macOS）|
| IRC | TCP/TLS |
| Microsoft Teams | Bot Framework |
| Matrix / Element | matrix-js-sdk |
| Feishu / Lark | 飞书 API |
| LINE | LINE SDK |
| Mattermost | API |
| Nextcloud Talk | WebRTC |
| Nostr | WebSocket relay |
| Twitch | 聊天/API |
| Zalo | OA API |
| WebChat | 内置 React UI |
| … | 共 23+ |

**DM 安全默认**：陌生人发 DM → 返回 8 字符配对码，确认后才接入。

---

## 独特功能

### Canvas（A2UI 交互式界面）

Agent 可以动态生成和更新 HTML/CSS/JS 界面，用户在 macOS/iOS 应用中直接交互：

```
Agent 调用 tools.canvas.push({html, css, js})
    ↓
macOS 菜单栏 / iOS 应用显示 Canvas
    ↓
用户点击 / 输入 / 滑动
    ↓
事件回传给 Agent → 继续执行
```

适合做实时仪表盘、交互表单、数据可视化。

### macOS/iOS/Android 原生应用

- **macOS**：菜单栏常驻，语音唤醒，全局快捷键，Talk Mode 覆盖
- **iOS**：节点应用，与 macOS 应用协同
- **Android**：Kotlin 原生应用

### 33+ 扩展插件

按需加载，不影响核心体积：

| 类型 | 示例 |
|------|------|
| 通道扩展 | discord、slack、matrix、signal、zalo、msteams |
| 内存后端 | memory-core（内存）、memory-lancedb（持久向量）|
| Auth 门户 | gemini-portal-auth、qwen-portal-auth |
| 诊断 | diagnostics-otel（OpenTelemetry）|
| 语音 | voice-call（WebRTC）|

### 多 Agent 路由

```json5
{
  "agents.routing": [
    {
      "channels": ["telegram"],
      "peers": ["@vip_user"],
      "agent": "vip-assistant"   // 路由到专属 Agent
    },
    {
      "channels": ["slack"],
      "agent": "work-agent"
    }
  ]
}
```

不同平台、不同用户可路由到不同 Agent，各自有独立工作区和人设。

---

## 数据存储

| 数据 | 存储位置 | 说明 |
|------|---------|------|
| 对话历史 | `~/.openclaw/agents/<id>/sessions/*.jsonl` | JSONL 逐行存储 |
| 向量内存 | SQLite-vec 或 LanceDB | 插件可换 |
| Agent 配置文件 | `~/.openclaw/agents/<id>/workspace/*.md` | Markdown 纯文本 |
| 主配置 | `~/.openclaw/openclaw.json` | JSON5 格式 |
| API Key | `~/.openclaw/auth-profiles/` | AES-256-GCM 加密 |
| 设备配对 | `~/.openclaw/device-pairing.json` | WS 客户端信任列表 |

**无需外部数据库**，全部本地文件。

---

## 安全机制

| 机制 | 说明 |
|------|------|
| Gateway 认证 | Token / Password / Trusted-proxy（必须配置）|
| DM 配对码 | 陌生用户 8 字符验证 |
| API Key 加密 | AES-256-GCM |
| 工具策略 | `tools.exec.allow` 白名单 + deny 列表 |
| Docker 沙箱 | 可选，隔离代码执行 |
| 路径遍历防护 | 工作区绑定 + 符号链接检查 |
| SSRF 防护 | 浏览器/HTTP 请求 IP 过滤 |

**重要边界**：OpenClaw 是**单用户设计**，不支持多租户。一个 Gateway 对应一个信任用户，多用户场景需部署多个 Gateway 实例。

---

## 快速上手

```bash
# 安装
npm install -g openclaw@latest

# 初始化 + 安装系统服务
openclaw onboard --install-daemon

# 配置（~/.openclaw/openclaw.json）
{
  "agents": {
    "defaults": {
      "model": "anthropic/claude-sonnet-4-5",
      "workspace": "~/.openclaw/workspace"
    }
  },
  "channels": {
    "telegram": {
      "token": "your-bot-token",
      "dmPolicy": "pairing"
    }
  }
}

# 启动
openclaw gateway start

# 打开控制面板
open http://localhost:18789
```

---

## 适合场景

✅ **最适合**
- 个人开发者 / 独立创业者，需要在多个聊天 App 里用 AI
- 需要 macOS/iOS 原生体验（菜单栏、语音、Canvas）
- 接入小众通道（Signal、iMessage、IRC、Matrix、Nostr）
- 需要丰富插件生态自由扩展
- 隐私敏感，不想数据过云端

❌ **不适合**
- 企业多租户、多用户隔离场景
- "给需求自动生成完整项目"的自动化流水线
- 24/7 无人值守的自主工作流
- 大规模并发部署
