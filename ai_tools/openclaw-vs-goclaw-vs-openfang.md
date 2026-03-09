# GoClaw vs OpenClaw vs OpenFang 三项对比

> 核心问题：哪个更适合"给一句话需求 / 简单的需求话术文件 → 自动出项目"？

---

## 一句话定位

| 项目 | 定位 |
|------|------|
| **OpenClaw** | 个人 AI 助手网关，多平台聊天接入 + 工具链执行，偏"私人全能助手" |
| **GoClaw** | 企业级多租户 AI Agent 网关，多通道 + 多 Agent 协作，偏"企业 IM 接入层" |
| **OpenFang** | Agent 操作系统，7 个自治 Hand 按计划 24/7 运行，偏"自主工作流引擎" |

---

## 技术栈全景

| 维度 | OpenClaw | GoClaw | OpenFang |
|------|----------|--------|----------|
| 语言 | **TypeScript** (Node 22+) | **Go 1.25** | **Rust** |
| 存储 | SQLite-vec + JSONL | **PostgreSQL + pgvector** | SQLite + 向量 |
| Web UI | React 19 + Vite + Tailwind | React 19 + Vite + Tailwind | Alpine.js（编译进二进制）|
| 桌面应用 | ✅ **macOS/iOS/Android**（Swift/Kotlin）| ❌ | ✅ Tauri 2.0 |
| 部署形式 | npm 包 + systemd/launchd | 单二进制 + PG | **32MB 单二进制，零依赖** |
| 冷启动 | ~1.5s | ~1s | **180ms** |
| 内存占用 | ~120MB | ~80MB | **~40MB** |
| 代码规模 | 大型 TS monorepo | 40,000+ 行 Go | **137,728 行 Rust** |
| 测试数量 | 70%+ 覆盖率 | 336 个测试函数 | **1,767+ 自动化测试** |
| 许可证 | MIT | MIT | MIT |

---

## 核心能力全景

### 基础 Agent 能力

| 能力 | OpenClaw | GoClaw | OpenFang |
|------|----------|--------|----------|
| Agent 循环（Think→Act→Observe）| ✅ Pi 嵌入式运行时 | ✅ 自研 | ✅ 自研 |
| 最大迭代次数 | 配置驱动 | 20 次 | 50+ 次 |
| 流式响应 | ✅ SSE | ✅ SSE | ✅ SSE |
| 扩展思考（Extended Thinking）| ✅ | ✅ | ✅ |
| 多 Agent 路由 | ✅ `agents.routing` | ✅ Team | ✅ `agent_send` |
| 自动上下文压缩 | ✅ >75% | ✅ >75% | ✅ |
| 向量内存 | ✅ LanceDB/SQLite-vec | ✅ pgvector | ✅ SQLite-vec |
| 技能库（SKILL.md）| ✅ 50+ 技能 | ✅ 60+ 技能 | ✅ **60 技能，编译进二进制** |

---

### "给需求出项目"核心能力

| 能力 | OpenClaw | GoClaw | OpenFang |
|------|----------|--------|----------|
| **文档解析（PDF）** | ❌ 无内置 | ✅ **多模型链（Gemini/Anthropic）** | ❌ 无内置 |
| **图像/扫描件识别** | ❌ 无内置 | ✅ **read_image 多模型链** | ❌ 无内置 |
| **中文文档识别** | ❌ | ✅ Gemini 中文 PDF 好 | ❌ |
| **持久化任务规划（PRD）** | ❌（写文件凑合）| ❌ | ✅ Planner Agent → Epic/Story/Task |
| **声明式工作流引擎** | ❌ | ❌ | ✅ **JSON 声明，5 种编排模式** |
| **代码审查-修复循环** | ❌ | ❌（框架有，未接入）| ✅ code-reviewer + Loop 模式 |
| **自动运行测试** | ✅ exec + 捕获错误 | ❌ | ✅ shell_exec + 自动修复 |
| **项目脚手架工具** | ❌ | ❌ | ❌ |
| **多 Agent 并行开发** | ⚠️ 需手动配置路由 | ✅ Team 任务板 | ✅ **Fan-out 工作流** |
| **断点续跑（跨轮次）** | ⚠️ 依赖 JSONL 历史 | ❌ 无规划 Store | ✅ Tasks + KV Store |

---

### 平台与生态

| 能力 | OpenClaw | GoClaw | OpenFang |
|------|----------|--------|----------|
| LLM 提供商数量 | 多（Anthropic、OpenAI、Gemini 等）| 4+ | **27 个（123+ 模型）** |
| 通道集成数量 | **23+**（含 Signal/iMessage/IRC/Matrix）| 7 个 | **40 个** |
| macOS/iOS 原生应用 | ✅ **Swift/SwiftUI** | ❌ | ✅ Tauri |
| Android 应用 | ✅ **Kotlin** | ❌ | ✅ Tauri |
| Canvas（交互式 UI）| ✅ **A2UI 框架** | ❌ | ❌ |
| MCP 支持 | ✅ | ✅ | ✅ |
| 自治 Hand（24/7 无人值守）| ❌ 仅 Cron | ⚠️ Cron 任务 | ✅ **7 个 Hand** |
| 插件/扩展生态 | ✅ **33+ 扩展** | ❌ | ⚠️ 14 个 crate 内置 |

---

### 多租户与企业能力

| 能力 | OpenClaw | GoClaw | OpenFang |
|------|----------|--------|----------|
| 多租户隔离 | ❌ **明确单用户设计** | ✅ **owner_id + RBAC** | ❌ 单用户设计 |
| RBAC 权限 | ⚠️ 工具策略 | ✅ admin/operator/viewer | ⚠️ 基础权限 |
| 加密存储（API Key）| ✅ AES-256-GCM | ✅ AES-256-GCM | ✅ AES-256-GCM |
| 企业 IM 接入 | ✅ Teams/Slack/Feishu | ✅ Feishu/Discord/Slack | ✅ 40 个通道 |

---

### 安全防御

| 机制 | OpenClaw | GoClaw | OpenFang |
|------|----------|--------|----------|
| 防御层数 | ~8 层 | **5 层** | **16 层** |
| 沙箱隔离 | ✅ Docker（可选）| ✅ Docker 代码沙箱 | ✅ **WASM 双计量沙箱** |
| 审计链 | ❌ | ❌ | ✅ **Merkle 哈希链** |
| Agent 清单签名 | ❌ | ❌ | ✅ **Ed25519** |
| 污点追踪（Secrets）| ❌ | ❌ | ✅ |
| Prompt 注入检测 | ❌ | ✅ 检测+策略 | ✅ 净化 |
| SSRF 防护 | ✅ | ✅ | ✅ |
| 路径遍历防护 | ✅ | ✅ | ✅ |

---

## 场景评分：给需求自动出项目

### 场景一：一句话需求 → 完整项目

**"帮我做一个博客系统，Next.js + PostgreSQL"**

| 维度 | OpenClaw | GoClaw | OpenFang |
|------|----------|--------|----------|
| 理解需求 | ✅ | ✅ | ✅ |
| 规划分解 | ⚠️ 依赖 LLM 上下文 | ⚠️ 依赖 LLM 上下文 | ✅ Planner Agent |
| 并行多 Agent 开发 | ⚠️ 手配 | ✅ Team | ✅ Fan-out |
| 代码生成 | ✅ | ✅ | ✅ |
| 自动测试验证 | ✅ exec | ❌ | ✅ |
| 审查-修复循环 | ❌ | ❌ | ✅ Loop |
| 跨轮次断点续跑 | ⚠️ | ❌ | ✅ |
| 综合得分 | ⭐⭐⭐ | ⭐⭐⭐ | **⭐⭐⭐⭐** |

---

### 场景二：简单的需求话术文件（PDF/扫描图）→ 项目

**上传采购通知 PDF → 解析需求 → 生成系统**

| 维度 | OpenClaw | GoClaw | OpenFang |
|------|----------|--------|----------|
| PDF 原生解析 | ❌ 无 | ✅ **Gemini 50MB** | ❌ 无 |
| 扫描图识别 | ❌ | ✅ **多模型链** | ❌ |
| 中文文档效果 | ❌ | ✅ Gemini 中文好 | ❌ |
| 解析后自动生成 | ⚠️ 同场景一 | ⚠️ 同场景一 | ⚠️ 需外接解析 |
| 综合得分 | ⭐⭐ | **⭐⭐⭐⭐** | ⭐⭐ |

---

### 场景三：24/7 自主监控 + 周期性报告

| 维度 | OpenClaw | GoClaw | OpenFang |
|------|----------|--------|----------|
| 无人值守自主运行 | ⚠️ Cron 基础 | ⚠️ Cron 任务 | ✅ **7 个 Hand** |
| 按计划执行 | ✅ cron 工具 | ✅ Cron Store | ✅ **HAND.toml schedule** |
| 自动学习优化 | ❌ | ❌ | ✅ **6 个月自我改进** |
| 综合得分 | ⭐⭐⭐ | ⭐⭐ | **⭐⭐⭐⭐⭐** |

---

## 最适合的用户画像

### OpenClaw 最适合

```
✅ 个人开发者 / 独立创业者
✅ 需要 macOS/iOS 原生体验（菜单栏、语音唤醒、Canvas 可视化）
✅ 接入小众通道（Signal、iMessage、IRC、Matrix、Nostr）
✅ 丰富的插件生态（33+ 扩展）
✅ 轻量自托管（npm install，无需 Docker/数据库）

❌ 企业多租户
❌ 给需求自动出完整项目
❌ 24/7 无人值守工作流
```

### GoClaw 最适合

```
✅ 企业级多租户部署（多用户、多 Agent、RBAC）
✅ 需要解析 PDF/图像/简单的需求话术文件作为输入
✅ 企业 IM 接入（Telegram/Feishu/Discord + 权限策略）
✅ 向量内存大规模检索（pgvector）
✅ 复杂的多 Agent 团队协作

❌ 单机个人使用
❌ 自主工作流（无 Workflow Engine）
❌ 自动化"需求 → 项目"完整链路
```

### OpenFang 最适合

```
✅ "需求 → 代码"的自动化流水线
✅ 24/7 无人值守自主任务（研究、监控、内容生成）
✅ 极致性能需求（Rust，32MB，180ms 启动）
✅ 需要声明式工作流编排（Fan-out、Loop、Conditional）
✅ 边缘/嵌入式部署（单二进制，零依赖）

❌ 企业多租户
❌ PDF/中文文档解析
❌ macOS/iOS 深度集成
❌ 丰富的插件生态（相对封闭）
```

---

## 最优组合方案

如果目标是**"简单的需求话术文件 → 自动出项目"**，最优方案是两步组合：

```
简单的需求话术文件（PDF/扫描图）
        ↓
   GoClaw（解析文档）
   read_document / read_image
   → 输出结构化需求文本
        ↓
   OpenFang（自动流水线）
   architect → fan-out(coder, test-engineer)
   → loop(code-reviewer) → doc-writer
        ↓
   完整项目代码 + 文档
```

**或者，修改单一系统成本：**

| 目标 | 改造哪个 | 需补充什么 | 工期 |
|------|---------|-----------|------|
| 最快能跑通 | **OpenFang** | 补 read_document 工具 | 1-2 周 |
| 最完整企业方案 | **GoClaw** | 补 Workflow Engine + Planner Store | 4-6 周 |
| 最好的个人体验 | **OpenClaw** | 补 PDF 解析 + Workflow 编排 | 3-4 周 |

---

## 总览评分

| 维度 | OpenClaw | GoClaw | OpenFang |
|------|----------|--------|----------|
| 给需求出项目 | ⭐⭐⭐ | ⭐⭐⭐ | **⭐⭐⭐⭐** |
| 简单的需求话术文件解析 | ⭐⭐ | **⭐⭐⭐⭐⭐** | ⭐⭐ |
| 多租户企业部署 | ⭐ | **⭐⭐⭐⭐⭐** | ⭐ |
| 个人使用体验 | **⭐⭐⭐⭐⭐** | ⭐⭐ | ⭐⭐⭐⭐ |
| 24/7 自主运行 | ⭐⭐ | ⭐⭐ | **⭐⭐⭐⭐⭐** |
| 安全防御 | ⭐⭐⭐ | ⭐⭐⭐⭐ | **⭐⭐⭐⭐⭐** |
| 性能/部署简单 | ⭐⭐⭐ | ⭐⭐⭐ | **⭐⭐⭐⭐⭐** |
| 生态/扩展性 | **⭐⭐⭐⭐⭐** | ⭐⭐⭐ | ⭐⭐⭐ |
| 通道覆盖 | ⭐⭐⭐⭐ | ⭐⭐⭐ | **⭐⭐⭐⭐⭐** |
