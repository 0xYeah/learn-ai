# OpenFang 项目介绍

> 版本：v0.3.30 | 语言：Rust | 许可证：MIT

---

## 一句话定位

**OpenFang 是一个用 Rust 构建的开源 Agent 操作系统**，不是聊天框架，不是 Python LLM 包装器——它的核心是"**Hands**"：预构建的自治能力包，可在无人干预的情况下按计划 24/7 运行，自动生成报告、监控目标、建立知识图谱、编写代码。

---

## 核心数字

| 指标 | 数值 |
|------|------|
| 代码规模 | 137,728 行 Rust |
| 模块（Crate）| 14 个 |
| 自动化测试 | 1,767+ |
| 二进制大小 | **32MB，零外部依赖** |
| 冷启动时间 | **180ms** |
| 内存占用 | **~40MB** |
| 预构建 Agent 模板 | 30 个 |
| 自治 Hand | 7 个 |
| 内置技能库（SKILL.md）| 60 个 |
| LLM 提供商 | **27 个（123+ 模型）** |
| 通道集成 | **40 个**（Telegram、Discord、Slack 等）|
| HTTP API 端点 | 76 个 |
| 安全防御层 | **16 层** |

---

## 整体架构

### 14 个 Crate 的分层设计

```
openfang-cli / openfang-desktop
        ↓
openfang-api          HTTP/WS/SSE API（76 个端点，Axum 0.8）
        ↓
openfang-kernel       内核：调度 + RBAC + 工作流引擎 + 触发器
        ↓
openfang-runtime      Agent 执行引擎（LLM 驱动 + 53 个工具 + WASM 沙箱）
openfang-channels     40 个消息通道适配器
openfang-memory       SQLite + 向量存储 + 知识图谱
openfang-skills       60 个预构建技能库
openfang-hands        7 个自治 Hand（编译进二进制）
openfang-extensions   MCP / OAuth2 / A2A 集成
openfang-wire         OFP P2P 协议
openfang-types        核心类型定义
openfang-migrate      OpenClaw 迁移引擎
```

### 技术选型

| 技术 | 用途 |
|------|------|
| Rust + Tokio | 异步运行时，低内存，高性能 |
| Axum 0.8 | HTTP API 框架 |
| SQLite | 嵌入式存储（无需外部数据库）|
| WASM（Wasmtime）| 工具执行沙箱 |
| Alpine.js | Web UI（编译进二进制）|
| Tauri 2.0 | 桌面应用（系统托盘、通知）|
| Ed25519 | Agent 清单签名 |

---

## 核心概念

### 1. Agent（代理）

Agent 是 OpenFang 的基本执行单元，通过 `agent.toml` 定义：

```toml
[agent]
name = "coder"
module = "builtin:chat"        # LLM 驱动
provider = "groq"
model = "llama-3.3-70b-versatile"
max_tokens = 8192
temperature = 0.2
system_prompt = """
你是一名专业的软件工程师...
"""

[capabilities]
tools = ["file_read", "file_write", "shell_exec", "web_fetch", "memory_store"]
shell = ["cargo *", "git *", "npm *"]   # 白名单命令

[resources]
max_llm_tokens_per_hour = 200000
max_concurrent_tools = 10
```

**4 个质量层级：**

| 层级 | 代表 Agent | 默认模型 |
|------|-----------|---------|
| Tier 1 — Frontier | orchestrator, architect, security-auditor | DeepSeek |
| Tier 2 — Smart | coder, code-reviewer, test-engineer, researcher | Gemini 2.5 Flash |
| Tier 3 — Balanced | planner, writer, doc-writer, assistant | Groq llama-3.3-70b |
| Tier 4 — Fast | ops, translator, tutor, home-automation | Groq llama-3.1-8b |

**30 个预构建模板：** architect, coder, orchestrator, planner, researcher, analyst, code-reviewer, test-engineer, debugger, data-scientist, security-auditor, doc-writer, writer, email-assistant, social-media, customer-support, sales-assistant, recruiter, meeting-assistant, legal-assistant, translator, tutor, health-tracker, personal-finance, travel-planner, home-automation, ops, assistant, hello-world...

---

### 2. Hands（自治能力包）

Hand 是比 Agent 更高级的概念——**无需用户触发，按计划自主运行**，有自己的调度策略、工具权限和知识库。

**7 个内置 Hand：**

#### Researcher Hand
- **用途**：深度自主研究，多源交叉验证，生成学术级报告
- **调度**：`periodic: every 5m`（持续监控）或按需触发
- **特性**：自动判断信息可靠性，标注置信度，建立知识图谱
- **工具**：web_search, web_fetch, knowledge_graph, memory_store, file_write

#### Lead Hand
- **用途**：B2B 潜在客户发现，自动学习 ICP（理想客户画像）
- **调度**：定时搜索，输出 CSV/JSON
- **特性**：随使用时间自动优化搜索策略（6 个月持续改进）

#### Collector Hand
- **用途**：OSINT 情报收集，变化检测，实体追踪
- **特性**：建立知识图谱，检测网页/数据变化并告警

#### Predictor Hand
- **用途**：预测引擎，输出置信区间，用 Brier 评分追踪准确率
- **特性**：自我校准，历史预测可查

#### Twitter Hand
- **用途**：自治 Twitter/X 账号管理
- **特性**：7 种轮转内容格式，自动生成推文，有审批队列
- **调度**：按设定频率自动发布

#### Clip Hand
- **用途**：YouTube URL → 竖屏短视频（Reels/Shorts）
- **流程**：下载 → 转码（FFmpeg）→ 识别高光片段 → 裁剪竖屏 → 添加字幕
- **工具**：yt-dlp, FFmpeg, shell_exec

#### Browser Hand
- **用途**：Web 自动化，表单填充，多步工作流
- **安全**：**购买类操作必须人工审批**，不会自动花钱

---

### 3. Workflow Engine（工作流引擎）

OpenFang 的核心差异化能力。用声明式 JSON 定义复杂 Agent 管道，支持 5 种编排模式：

```json
{
  "name": "需求到项目",
  "steps": [
    {
      "name": "设计架构",
      "agent_name": "architect",
      "prompt": "分析需求，设计系统架构：{{input}}",
      "output_var": "arch",
      "mode": "sequential"
    },
    {
      "name": "并行开发",
      "mode": "fan-out",
      "steps": [
        { "agent_name": "coder", "prompt": "实现后端 API：{{arch}}" },
        { "agent_name": "test-engineer", "prompt": "编写集成测试：{{arch}}" }
      ]
    },
    {
      "name": "代码审查",
      "agent_name": "code-reviewer",
      "mode": "loop",
      "until": "APPROVED",
      "max_retries": 3,
      "timeout_secs": 300
    },
    {
      "name": "写文档",
      "agent_name": "doc-writer",
      "prompt": "写 README、API 文档和部署指南"
    }
  ]
}
```

**5 种编排模式：**

| 模式 | 说明 |
|------|------|
| `sequential` | 顺序执行，上一步输出作为下一步输入 |
| `fan-out` | 多个 Agent 并行运行 |
| `collect` | 汇总所有并行输出 |
| `conditional` | 满足条件才执行（如"上一步包含 error"）|
| `loop` | 循环直到满足质量门槛（如"APPROVED"）|

---

### 4. 技能库（Skills）

60 个预构建 SKILL.md 文件，涵盖编程语言、框架、领域知识。采用 BM25 + 向量混合搜索，Agent 自动检索相关技能注入上下文。

**技能层级（优先级从高到低）：**
1. 工作区技能（`./skills/`）
2. 项目技能（`./.agents/skills/`）
3. 用户技能（`~/.agents/skills/`）
4. 全局技能（`~/.openfang/skills/`）
5. 内置技能（编译进二进制）

---

### 5. 内存系统

**SQLite Schema v5，7 张核心表：**

| 表 | 内容 |
|----|------|
| agents | Agent 清单和状态 |
| sessions | 对话历史 |
| canonical_sessions | 跨通道压缩摘要 |
| kv_store | 每 Agent 键值存储（agent 私有 + shared 共享）|
| entities | 知识图谱实体（人物、概念、组织）|
| relations | 实体关系 |
| embeddings | 向量嵌入（语义搜索）|

**记忆衰减：** 置信度每小时自动下降 5%（`decay_rate = 0.05`），防止过时信息污染上下文。

---

## 53 个工具分类

| 类别 | 工具 |
|------|------|
| 文件系统 | file_read, file_write, file_delete, file_move, directory_list, glob |
| 代码执行 | shell_exec（白名单模式）|
| 网络 | web_search, web_fetch（SSRF 防护）|
| 浏览器 | browser_action（DOM 交互、点击、截图）|
| 内存 | memory_store, memory_get, memory_search, knowledge_graph |
| Agent 协作 | agent_send（同步）, agent_spawn（异步）|
| 媒体 | image_analyze（无内置 PDF 解析）|
| MCP | mcp_call（Model Context Protocol）|
| A2A | a2a_call（Agent-to-Agent 协议）|

---

## 16 层安全防御

```
1.  WASM 双计量沙箱       fuel 限制 + epoch 超时
2.  Merkle 哈希链审计      每次操作不可篡改记录
3.  污点追踪              Secrets 从源到汇全程追踪
4.  Ed25519 签名          Agent 清单防篡改验证
5.  SSRF 保护             屏蔽内网 IP 范围
6.  子进程沙箱            Shell 白名单，deny list
7.  秘密清零              内存中密钥用完立即清零
8.  速率限制              每 Agent 每小时 Token 配额
9.  RBAC                  角色权限分层
10. 输入净化              Prompt 注入检测
11. 路径遍历防护          文件操作限制在 workspace
12. 网络隔离              可配置的出站限制
13. 审批队列              购买等高风险操作须人工确认
14. 令牌使用追踪          计费级精度记录
15. Agent 签名验证        运行前验证清单完整性
16. 加密存储              敏感配置 AES-256-GCM
```

---

## 快速上手

### 安装与启动

```bash
# 下载单一二进制（32MB，无依赖）
curl -L https://github.com/RightNow-AI/openfang/releases/latest/download/openfang-linux-amd64 -o openfang
chmod +x openfang

# 初始化
./openfang init

# 配置 LLM（至少一个）
export GROQ_API_KEY=your_key        # 免费，推荐入门
export GEMINI_API_KEY=your_key      # 多模态能力
export DEEPSEEK_API_KEY=your_key    # Tier 1 推理

# 启动守护进程
./openfang start

# 或启动桌面应用（Tauri）
./openfang desktop
```

### Web UI

```
http://localhost:4200
```

### 和 Agent 对话

```bash
# CLI 交互
./openfang chat --agent coder "用 Rust 写一个 JWT 中间件"

# API 调用
curl -X POST http://localhost:4200/api/chat \
  -H "Content-Type: application/json" \
  -d '{"agent": "coder", "message": "用 Rust 写一个 JWT 中间件"}'
```

### 运行工作流

```bash
# 创建工作流
curl -X POST http://localhost:4200/api/workflows \
  -d @workflow.json

# 执行工作流
curl -X POST http://localhost:4200/api/workflows/{id}/run \
  -d '{"input": "帮我做一个博客系统，Next.js + PostgreSQL"}'
```

### 启动自治 Hand

```bash
# 启动 Researcher Hand（开始自主研究）
./openfang hand start researcher

# 启动 Lead Hand（开始寻找潜在客户）
./openfang hand start lead

# 查看运行状态
./openfang hand status
```

---

## 与其他系统对比

| 维度 | OpenFang | Devin | OpenHands | GoClaw |
|------|----------|-------|-----------|--------|
| 自主运行（无人值守）| ✅ Hands | ❌ 交互式 | ❌ 交互式 | ⚠️ 仅 Cron |
| 工作流引擎 | ✅ 声明式 JSON | ❌ | ❌ | ❌ |
| 单一二进制部署 | ✅ 32MB | ❌ | ❌ | ❌ |
| 多 Agent 协作 | ✅ | ❌ | ⚠️ | ✅ |
| LLM 提供商 | ✅ 27 个 | ❌ 闭源 | ✅ 多个 | ✅ 4 个 |
| 通道集成 | ✅ 40 个 | ❌ | ❌ | ✅ 7 个 |
| PDF/文档解析 | ❌ 无内置 | ✅ | ⚠️ | ✅ 强 |
| 多租户企业部署 | ❌ 单用户 | ❌ | ❌ | ✅ |
| 安全防御层 | ✅ 16 层 | 未知 | ~5 层 | ✅ 5 层 |
| 开源 | ✅ MIT | ❌ 闭源 | ✅ | ✅ |

---

## 最适合的使用场景

✅ **适合**
- 需要 24/7 无人值守自主运行的自动化任务（研究、监控、内容生成）
- 多 Agent 协作的代码生成流水线
- 边缘/本地部署（单机，32MB，低内存）
- 对接 40 个通道的消息自动化
- 需要严格安全审计的场景

❌ **不适合**
- 企业多租户 SaaS 部署
- 需要解析 PDF/扫描图文档（无内置支持）
- 需要 PostgreSQL 级别的多租户数据隔离
- 实时交互式对话为主的产品
