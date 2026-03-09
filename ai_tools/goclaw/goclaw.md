# GoClaw Gateway - 项目技术文档

> 生成日期：2026-03-09

---

## 1. 项目概览

**GoClaw** 是一个企业级多租户 AI Agent Gateway，基于 Go 1.25 开发，采用单二进制部署模式，零额外运行时依赖。它连接 13+ LLM 提供商、多个通讯平台和工具生态，支持复杂的 Agent 编排、跨 Agent 委派、团队协作和质量门控工作流。

### 核心特性

| 特性 | 说明 |
|------|------|
| 多租户隔离 | PostgreSQL + owner_id + 工作空间隔离 |
| 通信协议 | WebSocket RPC v3 + REST HTTP API |
| 内置工具 | 110+ 工具（文件、网页、图像、音频、执行、模型调用等）|
| Agent 编排 | 同步/异步委派、Team 协作 |
| 多平台通道 | Telegram、Discord、Slack、Feishu、WhatsApp、Zalo |
| 向量内存 | pgvector + BM25 混合搜索 |
| MCP 支持 | Model Context Protocol 桥接 |
| 沙箱执行 | Docker 容器化代码执行 |
| 可观测性 | OpenTelemetry 追踪 + 结构化日志 |
| 权限系统 | 5 层细粒度权限控制 |

---

## 2. 整体架构

```
┌─────────────────────────────────────────────┐
│           Web UI (React 19 + Vite)          │
│  (Zustand 状态管理, Radix UI, Tailwind CSS) │
└────────────┬────────────────────────────────┘
             │
        ┌────▼────────────────────────────────────┐
        │  API Gateway (WebSocket v3 + REST)      │
        │  连接管理 | 帧路由 | 速率限制 | 配对   │
        └────┬──────────────────┬─────────────────┘
             │                  │
    ┌────────▼────────┐  ┌──────▼──────┐
    │  Agent Router   │  │  HTTP API   │
    │  解析 | 委派    │  │  /v1/...    │
    │  多 Agent 编排  │  │  50+ 端点   │
    └────────┬────────┘  └─────────────┘
             │
    ┌────────▼──────────────────────────────────┐
    │        Agent Loop (Think→Act→Observe)     │
    │  Provider 调用 | 工具执行 | 压缩 | 流式  │
    └────────┬──────────────────┬───────────────┘
             │                  │
    ┌────────▼────────┐  ┌──────▼──────┐
    │  Tool Registry  │  │  Scheduler  │
    │  110+ 工具      │  │  4 Lane 模型│
    └────────┬────────┘  └─────────────┘
             │
    ┌────────▼──────────────────────────────────┐
    │        Provider Layer (LLM + Embedding)   │
    │  Anthropic | OpenAI | Claude CLI | 自定义 │
    └────────┬──────────────────────────────────┘
             │
    ┌────────▼──────────────────────────────────┐
    │        Store Layer (Interface + PG 实现)  │
    │  13 个 Store 接口 | PostgreSQL 实现       │
    └────────┬──────────────────────────────────┘
             │
    ┌────────▼──────────────────────────────────┐
    │     PostgreSQL 15+ + pgvector             │
    │  多租户 | UUID v7 | JSONB 配置            │
    └───────────────────────────────────────────┘
```

---

## 3. 项目目录结构

```
cmd/                          CLI 命令、网关启动、首次配置、迁移
internal/
├── gateway/                  WS + HTTP 服务器、客户端、方法路由
│   └── methods/              RPC 处理器（50+ 方法）
├── agent/                    Agent 循环（think→act→observe）、路由、解析
├── providers/                LLM 提供商：Anthropic（原生 HTTP+SSE）、OpenAI 兼容
├── tools/                    工具注册表、文件、执行、网页、内存、子 Agent、MCP 桥接
├── store/                    Store 接口 + pg/ PostgreSQL 实现
├── bootstrap/                系统提示文件（SOUL.md、IDENTITY.md）+ 种子数据
├── config/                   配置加载（JSON5）+ 环境变量覆盖
├── channels/                 通道管理器：Telegram、Feishu、Zalo、Discord、WhatsApp
├── http/                     HTTP API（/v1/chat/completions、/v1/agents 等）
├── skills/                   SKILL.md 加载器 + BM25 搜索
├── memory/                   内存系统（pgvector）
├── tracing/                  LLM 调用追踪 + 可选 OTel 导出
├── scheduler/                Lane 并发控制（main/subagent/cron）
├── cron/                     Cron 调度（at/every/cron 表达式）
├── permissions/              RBAC（admin/operator/viewer）
├── pairing/                  浏览器配对（8 字符码）
├── crypto/                   AES-256-GCM 加密（API 密钥）
├── sandbox/                  Docker 代码沙箱
└── tts/                      文本转语音（OpenAI、ElevenLabs、Edge、MiniMax）
pkg/protocol/                 Wire 协议类型（帧、方法、错误、事件）
pkg/browser/                  浏览器自动化（Rod + CDP）
migrations/                   PostgreSQL 迁移文件（10 个版本）
ui/web/                       React SPA（pnpm、Vite、Tailwind、Radix UI）
```

---

## 4. 核心模块详解

### 4.1 Agent 执行循环（internal/agent/）

Agent 循环是系统核心，采用 Think→Act→Observe 模式：

```
Input（消息）
  ↓
注入上下文（Agent ID、User ID、Workspace、Tool Policy）
  ↓
输入安全扫描（注入模式检测）
  ↓
加载 Bootstrap + Context Files + 消息历史
  ↓
Provider.Chat（Think）→ {content, tool_calls, thinking}
  ↓
工具路由与执行（deny 检查 → 委派检查 → 执行）
  ↓
Provider.Chat（Observe）→ 下一次迭代
  ↓
令牌累积 + 压缩检查（>75% context → 触发压缩）
  ↓
内存刷新（向量化 → pgvector 存储）
  ↓
EmitEvent("run.completed")
```

**Agent 类型：**
- `open` - 每用户独立上下文文件（7 个文件）
- `predefined` - 共享 Agent 级上下文 + 每用户 USER.md

**关键文件：**

| 文件 | 功能 |
|------|------|
| `loop.go` | 主循环入口 |
| `loop_run.go` | think→act→observe 核心 |
| `loop_compact.go` | 会话压缩与修剪 |
| `loop_history.go` | 消息历史管理 |
| `loop_media.go` | 媒体处理 |
| `resolver.go` | Agent 创建与初始化 |
| `input_guard.go` | 注入模式扫描 |

### 4.2 WebSocket 网关（internal/gateway/）

**协议 v3 帧格式：**

```json
// 客户端请求
{
  "type": "req",
  "id": "uuid-1",
  "method": "chat.send",
  "params": { "sessionKey": "...", "message": "..." }
}

// 服务器响应
{
  "type": "res",
  "id": "uuid-1",
  "ok": true,
  "payload": { ... }
}

// 服务器推送事件
{
  "type": "event",
  "event": "run.completed",
  "payload": { ... },
  "seq": 42
}
```

**主要 RPC 方法（50+）：**
- `chat.send` - 发送聊天消息
- `agents.*` - Agent CRUD 管理
- `sessions.*` - 会话管理
- `skills.*` - 技能搜索
- `cron.*` - 任务调度
- `delegations.*` - Agent 委派
- `channels.*` - 通道管理
- `pairing.*` - 设备配对

### 4.3 LLM 提供商（internal/providers/）

```go
type Provider interface {
    Name() string
    DefaultModel() string
    SupportsThinking() bool   // 扩展思考支持
    Chat(ctx, req) (*ChatResponse, error)
}
```

**支持的提供商：**

| 提供商 | 类型 | 特性 |
|--------|------|------|
| Anthropic | 原生 HTTP+SSE | 支持扩展思考 |
| OpenAI 兼容 | HTTP+SSE | 通用（OpenRouter、Grok 等）|
| Claude CLI | 本地进程 | MCP 本地集成 |
| 自定义 | HTTP | 通用端点 |

**重试策略：** 指数退避，初始 1s，最大 30s，最多 5 次。

### 4.4 存储层（internal/store/）

**13 个 Store 接口：**

| Store | 功能 |
|-------|------|
| SessionStore | 会话消息历史、令牌累积、压缩计数 |
| AgentStore | Agent 元数据、配置、上下文文件 |
| MemoryStore | pgvector 向量、BM25 搜索 |
| CronStore | 计划任务存储 |
| TeamStore | 团队成员、任务板、委派历史 |
| ProviderStore | LLM 提供商、加密密钥 |
| SkillStore | 技能库管理 |
| MCPServerStore | MCP 服务器连接 |
| CustomToolStore | 动态工具定义 |

**核心约定：**
- Raw SQL + `$1, $2` 位置参数（无 ORM）
- `execMapUpdate()` 辅助函数处理动态更新
- Nullable 列使用 `*string`、`*time.Time` 等指针类型

### 4.5 工具系统（internal/tools/）

**110+ 工具分类：**

| 类别 | 工具示例 |
|------|---------|
| 文件操作 | `read_file`、`write_file`、`edit_file`、`list_files` |
| 代码执行 | `bash_exec`、`python_exec` |
| 网页/浏览器 | `web_search`、`web_fetch`、`browser.*` |
| 视觉/多媒体 | `read_image`、`create_image`、`create_video`、`tts` |
| 向量内存 | `memory_search`、`memory_add`、`memory_get` |
| Agent 协作 | `delegate`、`delegate_async`、`subagent_call` |
| MCP 桥接 | `mcp.resource.*`、`mcp.tool.*` |

**工具政策（多层控制）：**
```
全局（config.json）→ Agent 级（数据库 JSONB）→ 通道/组级
```

### 4.6 调度器（internal/scheduler/）

**4 Lane 并发模型：**

| Lane | 用途 | 特性 |
|------|------|------|
| main | 主 Agent 运行 | 每会话序列化 |
| subagent | 子 Agent 嵌套调用 | 独立并发 |
| delegate | Agent 委派运行 | 后台执行 |
| cron | 计划任务 | 独立执行 |

**自适应限流：** 根据 `lastPromptTokens` 和 `contextWindow` 动态调整并发。

### 4.7 多通道集成（internal/channels/）

**支持的通道：**

| 通道 | 实现方式 |
|------|---------|
| Telegram | Bot API + Webhook |
| Discord | WebSocket + SDK |
| Slack | Bolt SDK |
| Feishu/Lark | Card + Message API |
| WhatsApp | Cloud API |
| Zalo | OA API + P2P |

**DM 政策：** `pairing`（配对码）| `allowlist`（白名单）| `open`（开放）| `disabled`

**Group 政策：** `open` | `allowlist` | `disabled`

**Telegram 输出格式化：**
```
LLM 输出 → SanitizeAssistantContent() → markdownToTelegramHTML()
        → chunkHTML(4096 字节限制) → sendHTML()
```

---

## 5. 数据库设计

### 5.1 核心表结构

**agents**
```sql
id UUID PRIMARY KEY
agent_key VARCHAR(100) UNIQUE
display_name VARCHAR(255)
owner_id VARCHAR(255)
provider VARCHAR(50)
model VARCHAR(200)
context_window INT
max_tool_iterations INT
workspace TEXT
tools_config JSONB        -- 工具政策（覆盖全局）
sandbox_config JSONB
memory_config JSONB
compaction_config JSONB
agent_type VARCHAR(20)    -- "open" | "predefined"
status VARCHAR(20)        -- "active" | "inactive"
```

**sessions**
```sql
session_key VARCHAR(500) UNIQUE
agent_id UUID
user_id VARCHAR(255)
messages JSONB            -- [{role, content, tool_calls, ...}]
summary TEXT
input_tokens BIGINT
output_tokens BIGINT
compaction_count INT
metadata JSONB
```

**memory_chunks**（pgvector）
```sql
id UUID
session_id UUID
agent_id UUID
user_id VARCHAR(255)
content TEXT
embedding vector(1536)    -- OpenAI embeddings
```

**llm_providers**
```sql
id UUID
name VARCHAR(50) UNIQUE
provider_type VARCHAR(30)  -- "openai_compat" | "anthropic"
api_key TEXT               -- 加密（AES-256-GCM）
settings JSONB
```

### 5.2 设计原则

- **多租户**：`owner_id`、`user_id` 字段隔离
- **软删除**：`deleted_at` 字段
- **JSONB 灵活性**：工具策略、沙箱、内存配置可 Agent 级覆盖
- **UUID v7**：时间序列主键
- **pgvector HNSW**：快速向量近邻搜索

### 5.3 迁移版本

| 版本 | 内容 |
|------|------|
| 000001 | 初始 Schema |
| 000002 | Agent Links（inter-agent 委派）|
| 000003 | Agent Teams |
| 000004 | Teams v2 |
| 000005 | Phase 4（扩展功能）|
| 000006 | 内置工具 |
| 000007 | Team Metadata |
| 000008 | Team Tasks 用户范围 |
| 000009 | 配额索引 |
| 000010 | Agents MD v2 |

---

## 6. HTTP API

### 6.1 OpenAI 兼容接口

**POST /v1/chat/completions**
```http
Authorization: Bearer <token>
Content-Type: application/json

{
  "model": "agent-name",
  "messages": [{"role": "user", "content": "..."}],
  "stream": false,
  "user": "external-user-id"
}
```

### 6.2 GoClaw REST API

| 端点 | 功能 |
|------|------|
| `GET /v1/agents` | Agent 列表 |
| `POST /v1/agents` | 创建 Agent |
| `PATCH /v1/agents/:id` | 更新 Agent |
| `GET /v1/agents/:id/files` | 上下文文件 |
| `GET /v1/sessions` | 会话列表（分页）|
| `GET /v1/sessions/:key/preview` | 消息预览 |
| `GET /v1/skills` | 技能搜索 |
| `GET /v1/cron` | 计划任务列表 |
| `POST /v1/cron/:id/run` | 手动触发任务 |
| `GET /v1/exec/approvals` | 待批准执行列表 |
| `GET /v1/mcp/servers` | MCP 服务器列表 |

---

## 7. 安全机制

### 7.1 五层权限系统

```
Layer 1: 网关认证（WebSocket connect）
  → token/password 验证 → role: admin|operator|viewer

Layer 2: 全局工具政策（config.json）
  → tools.allow, tools.deny, tools.profile

Layer 3: Agent 级工具政策（数据库 tools_config JSONB）
  → 每 Agent 的 allow/deny 覆盖

Layer 4: 通道/组工具政策
  → 通道或群组特定的工具限制

Layer 5: Owner 检查（permissions.IsOwner）
  → 某些工具和方法仅 admin/owner 可用
```

### 7.2 注入防护

**input_guard.go** 检测以下模式：
- SQL 注入：SELECT、INSERT、DELETE、DROP
- Prompt 注入：SYSTEM:、INSTRUCTIONS:、FOLLOW NEW:
- Shell 展开：`$(...)`、`` `...` ``、`$((...))`

**处理模式：** `log`（记录）| `warn`（警告）| `block`（拒绝）| `off`（禁用）

### 7.3 其他安全措施

| 机制 | 说明 |
|------|------|
| AES-256-GCM 加密 | API 密钥等敏感数据加密存储 |
| 路径遍历防护 | 文件操作限制在 workspace 内 |
| SSRF 防护 | web_fetch 屏蔽内网 IP 范围 |
| Shell deny 模式 | 禁止危险 Shell 命令 |
| 速率限制 | 网关层（100 req/s）+ 工具层（每小时）|
| CORS 控制 | 可配置的跨域策略 |

---

## 8. Web UI（React 19）

### 8.1 技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| React | 19.0 | UI 框架 |
| React Router | 7.1 | 路由管理 |
| Zustand | 5.0 | 状态管理 |
| Radix UI | 1.4 | 无障碍组件 |
| Tailwind CSS | 4.0 | 样式 |
| TanStack Query | 5.x | 数据请求 |
| Framer Motion | 12.x | 动画 |

### 8.2 核心模块

```
src/
├── api/
│   ├── ws-client.ts     WebSocket 连接管理
│   ├── http-client.ts   REST API 客户端
│   └── protocol.ts      协议类型定义
├── components/
│   ├── chat/            聊天界面（消息、输入框、会话选择）
│   ├── layout/          侧边栏、顶栏、主布局
│   └── shared/          通用组件（对话框、文件树）
└── pages/               各功能页面
```

### 8.3 流式响应处理

```typescript
wsClient.on('chunk', (data) => {
  chatStore.updateMessage(id, prev =>
    prev.content += data.content
  )
})

wsClient.on('run.completed', () => {
  chatStore.setStreaming(false)
})
```

---

## 9. 配置与部署

### 9.1 快速启动

```bash
# 构建
go build -o goclaw .

# 交互式首次配置
./goclaw onboard

# 加载密钥（PostgreSQL、API keys）
source .env.local

# 启动网关
./goclaw

# 数据库迁移
./goclaw migrate up

# Web UI（开发模式）
cd ui/web && pnpm install && pnpm dev
```

### 9.2 配置文件结构（config.json）

```json
{
  "agents": {
    "defaults": {
      "workspace": "~/.goclaw/workspace",
      "provider": "anthropic",
      "model": "claude-sonnet-4-5-20250929",
      "context_window": 200000,
      "max_tool_iterations": 20
    }
  },
  "channels": {
    "telegram": {
      "token": "...",
      "dm_policy": "pairing",
      "group_policy": "allowlist"
    }
  },
  "gateway": {
    "listen": "0.0.0.0:8080",
    "password": "secure-password"
  }
}
```

### 9.3 关键环境变量

| 变量 | 说明 |
|------|------|
| `GOCLAW_CONFIG` | 配置文件路径 |
| `GOCLAW_POSTGRES_DSN` | PostgreSQL 连接字符串 |
| `GOCLAW_VERBOSE` | 开启 debug 日志 |
| `GOCLAW_OTEL_EXPORTER` | OTel 导出器（otlp/jaeger/noop）|

### 9.4 运维命令

```bash
./goclaw doctor              # 健康检查（数据库、提供商、模式版本）
./goclaw migrate up          # 应用迁移
./goclaw migrate down N      # 回滚 N 个版本
```

---

## 10. 可观测性

**OpenTelemetry Span 类型：**

| Span | 属性 |
|------|------|
| `llm.chat` | 模型、令牌数、延迟 |
| `tool.execute` | 工具名、状态 |
| `run.loop` | 完整 Agent 运行 |
| `delegation` | 源/目标 Agent |

**日志规范：** 安全相关日志统一使用 `slog.Warn("security.*", ...)`

---

## 11. 关键设计决策

1. **单二进制部署** - 无额外依赖，简化运维
2. **PostgreSQL 优先** - 多租户隔离、事务、全文搜索、pgvector
3. **Interface-driven stores** - 灵活替换数据后端
4. **Lane 调度器** - 公平的 Agent 并发控制
5. **流式响应** - 实时用户反馈
6. **JSONB 配置** - Agent 级灵活覆盖全局默认
7. **多层工具政策** - 细粒度安全控制
8. **自动压缩** - 长对话的上下文管理
9. **Bootstrap 自清理** - 自动化首次运行设置
10. **MCP 桥接** - 开放的工具生态扩展

---

## 12. 项目统计

| 指标 | 数值 |
|------|------|
| Go 文件数 | 150+ |
| TypeScript/TSX 文件 | 80+ |
| Go 代码行数 | 40,000+ |
| 内置工具数 | 110+ |
| HTTP API 端点 | 50+ |
| WebSocket 方法 | 40+ |
| 数据库表 | 25+ |
| 通道集成 | 7+ |
| LLM 提供商 | 4+ |
| 数据库迁移版本 | 10 |

---

## 13. 关键文件速查

| 功能 | 文件路径 |
|------|---------|
| 网关启动 | `cmd/gateway.go` |
| Agent 主循环 | `internal/agent/loop.go` |
| Agent 核心执行 | `internal/agent/loop_run.go` |
| WebSocket 客户端 | `internal/gateway/client.go` |
| Store 接口定义 | `internal/store/stores.go` |
| PostgreSQL 实现 | `internal/store/pg/` |
| 工具注册表 | `internal/tools/registry.go` |
| 调度器 | `internal/scheduler/scheduler.go` |
| Anthropic 提供商 | `internal/providers/anthropic.go` |
| 配置加载 | `internal/config/config.go` |
| 协议帧定义 | `pkg/protocol/frames.go` |
| Web UI 入口 | `ui/web/src/App.tsx` |
| 初始 Schema | `migrations/000001_init_schema.up.sql` |
| 权限系统 | `internal/permissions/policy.go` |
| AES 加密 | `internal/crypto/aes.go` |
| 输入安全扫描 | `internal/agent/input_guard.go` |
| Schema 版本 | `internal/upgrade/version.go` |
