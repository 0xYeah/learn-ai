# GoClaw vs OpenFang 对比报告

> 核心用途：给一句话需求 / 红头文件 → 自动生成项目

---

## 一句话定位对比

| 项目 | 定位 |
|------|------|
| **GoClaw** | 企业级多租户 AI Agent **网关**，多平台通道 + 多 Agent 协作，偏"企业 IM 接入层" |
| **OpenFang** | Agent **操作系统**，7 个自治 Hand 按计划 24/7 运行，偏"自主工作流引擎" |

**两者都不是 Devin/OpenHands 的直接竞品，但 OpenFang 更接近"给需求出项目"这个用途。**

---

## 技术栈对比

| 维度 | GoClaw | OpenFang |
|------|--------|----------|
| 语言 | Go 1.25 | **Rust**（14 个 crate）|
| 存储 | PostgreSQL 15 + pgvector | **SQLite** + 向量存储 |
| Web UI | React 19 + Vite + Tailwind | Alpine.js SPA（编译进二进制）|
| 桌面 | 无 | **Tauri 2.0**（系统托盘）|
| 二进制大小 | 需 PG 依赖 | **32MB 单一二进制，零依赖** |
| 冷启动 | ~1s | **180ms** |
| 代码规模 | 40,000+ 行 Go | **137,728 行 Rust** |
| 测试数量 | 336 个测试函数 | **1,767+ 自动化测试** |
| LLM 提供商 | 4+ | **27 个（123+ 模型）** |
| 通道集成 | 7 个 | **40 个** |

---

## 核心能力对比

### "给一句话需求 → 项目" 能力

| 能力 | GoClaw | OpenFang |
|------|--------|----------|
| 需求理解（LLM 推理）| ✅ | ✅ |
| 持久化任务规划（PRD）| ❌ 缺失 | ✅ Planner Agent 输出 Epic→Story→Task |
| 多 Agent 并行协作 | ✅ Team 任务板 | ✅ **Workflow Engine（Fan-out）** |
| 代码生成 | ✅ write_file | ✅ Coder Agent（读→计划→实现→测试→验证）|
| 自动运行测试 | ❌ 缺失 | ✅ shell_exec + 错误捕获 |
| 代码审查循环 | ❌ 框架仅 | ✅ Code-reviewer Agent + Loop 模式 |
| 项目脚手架 | ❌ 缺失 | ❌ 无内置（需 prompt 手写）|
| 工作流引擎 | ❌ 运行时动态编排 | ✅ **声明式 JSON 工作流**（Sequential/Fan-out/Loop）|
| 文档生成 | ✅ write_file | ✅ Doc-writer Agent |

### "红头文件（PDF/图像）→ 项目" 能力

| 能力 | GoClaw | OpenFang |
|------|--------|----------|
| PDF 解析 | ✅ read_document（Gemini，20MB）| ⚠️ 无专用工具（需外接 Gemini/Anthropic）|
| 扫描图/图像识别 | ✅ read_image（多模型链）| ⚠️ 无直接支持 |
| 中文文档识别 | ✅ Gemini 中文 PDF 支持好 | ⚠️ 取决于外接模型 |
| 解析 → 结构化需求 | ❌ 无自动化管道 | ❌ 无自动化管道 |
| 文档 → 工作流触发 | ❌ | ❌ |

**结论：在红头文件解析这一块，GoClaw 反而更强（内置 read_document/read_image 多模型链）。**

---

## OpenFang 的核心优势

### 1. Workflow Engine（GoClaw 完全没有）

```json
{
  "name": "project-from-requirements",
  "steps": [
    { "agent": "architect", "prompt": "设计架构: {{input}}", "output_var": "arch" },
    {
      "mode": "fan-out",
      "steps": [
        { "agent": "coder", "prompt": "实现 API: {{arch}}" },
        { "agent": "test-engineer", "prompt": "写测试: {{arch}}" }
      ]
    },
    { "agent": "code-reviewer", "mode": "loop", "until": "APPROVED", "max_retries": 3 },
    { "agent": "doc-writer", "prompt": "写 README 和部署文档" }
  ]
}
```

这个 JSON 可以把"需求 → 架构 → 并行开发 → 审查循环 → 文档"固化成可重复执行的流水线，GoClaw 没有这个。

### 2. 30 个预构建 Agent 模板 + 4 层质量分级

```
Tier 1（深度推理）: orchestrator, architect, security-auditor
Tier 2（强分析）:  coder, code-reviewer, test-engineer, researcher
Tier 3（日常任务）: planner, writer, doc-writer
Tier 4（快速响应）: ops, translator, tutor
```

GoClaw 没有分层 Agent，所有 Agent 共用同一套执行机制。

### 3. 7 个自治 Hand（24/7 按计划运行）

OpenFang 的 Hand 是"无人值守的自治能力包"，比 GoClaw 的 Cron 任务更高层：

| Hand | 用途 |
|------|------|
| Researcher | 深度研究 + 学术报告，多源交叉验证 |
| Lead | 潜在客户发现，自动学习 ICP profile |
| Collector | OSINT 情报收集，变化检测 |
| Predictor | 预测引擎，Brier 评分追踪 |
| Twitter | 自治推文管理，7 种内容格式轮转 |
| Clip | YouTube → 竖屏短视频（FFmpeg 管道）|
| Browser | Web 自动化（购买需人工审批）|

### 4. 16 层安全防御（远超 GoClaw 的 5 层）

```
GoClaw：网关认证 → 工具政策 → Agent 策略 → 通道策略 → Owner 检查

OpenFang：WASM 双计量沙箱 → Merkle 哈希链审计 → 污点追踪 →
          Ed25519 签名 Agent 清单 → SSRF 保护 → 子进程沙箱 →
          秘密清零 → 速率限制 → ... (16 层)
```

---

## GoClaw 的核心优势

### 1. 文档解析能力（red flag 场景 GoClaw 更强）

```
GoClaw read_document:
  → Gemini Pro Vision（50MB PDF，258 tokens/page）
  → Anthropic 回退
  → OpenRouter 回退
  → DashScope 回退

OpenFang:
  → 无内置 PDF/图像解析工具
  → 需要通过 shell_exec 调用外部工具
```

### 2. 向量内存 + BM25 混合搜索

GoClaw 使用 PostgreSQL + pgvector，OpenFang 使用 SQLite + 向量存储。GoClaw 的内存系统更适合大规模多租户场景。

### 3. 多租户企业部署

GoClaw 天生支持多租户（owner_id 隔离、RBAC、加密 API 密钥），OpenFang 是单用户/单机设计。

### 4. 企业 IM 接入（GoClaw 7 个 vs OpenFang 40 个）

虽然 OpenFang 通道数更多（40 vs 7），但 GoClaw 的通道支持更深（有政策控制、群组配置、配对码机制）。

---

## "给需求出项目"场景综合评分

| 维度 | GoClaw | OpenFang | 说明 |
|------|--------|----------|------|
| 文档解析（PDF/图像）| ⭐⭐⭐⭐⭐ | ⭐⭐ | GoClaw 有内置多模型链 |
| 需求→结构化规划 | ⭐⭐ | ⭐⭐⭐⭐ | OpenFang Planner Agent |
| 代码生成流程 | ⭐⭐⭐ | ⭐⭐⭐⭐ | OpenFang 有读→计划→实现→测试→验证 |
| 工作流编排 | ⭐⭐ | ⭐⭐⭐⭐⭐ | OpenFang Workflow Engine 远强于 GoClaw |
| 多 Agent 协作 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 两者都有，模型不同 |
| 自动测试-修复 | ⭐ | ⭐⭐⭐⭐ | OpenFang Code-reviewer Loop |
| 持久化规划 | ⭐ | ⭐⭐⭐⭐ | OpenFang 有 Tasks + KV Store |
| 项目脚手架 | ⭐ | ⭐⭐ | 两者都没有内置，差不多 |
| **综合** | **⭐⭐⭐** | **⭐⭐⭐⭐** | OpenFang 更适合此用途 |

---

## 最优组合方案

如果目标是"给需求（包括红头文件）自动出项目"，**两个项目组合使用效果最好**：

```
红头文件（PDF/扫描图）
    ↓
GoClaw read_document / read_image（解析文档）
    ↓
输出结构化需求文本
    ↓
OpenFang Workflow Engine（自动流水线）
    architecture → fan-out(coder, test-engineer) → loop(reviewer) → doc-writer
    ↓
完整项目代码
```

或者在单一系统上实现：

**优先选 OpenFang** 如果：
- 核心诉求是"需求 → 代码"的自动化流水线
- 需要持久化工作流，可重复执行
- 不需要解析 PDF/图像文档
- 单机或边缘部署

**优先选 GoClaw** 如果：
- 需要解析 PDF/红头文件作为输入
- 需要多租户企业部署
- 需要对接 Telegram/企业微信等 IM
- 需要复杂的用户权限体系

---

## 各自补什么能达到"给需求出项目"

### GoClaw 需要补（6 周）

1. **持久化规划 Store**（PRD + 任务列表）— 2-3 周
2. **声明式工作流引擎**（类 OpenFang Workflow Engine）— 2-3 周
3. **测试-修复 Hook 循环**（激活现有框架）— 1-2 周
4. ~~文档解析~~（已有，不需要补）

### OpenFang 需要补（2-3 周）

1. **PDF/图像解析工具**（read_document + read_image）— 1-2 周
2. **项目脚手架工具**（与 GoClaw 相同的短板）— 1-2 周
3. ~~工作流引擎~~（已有，不需要补）

**OpenFang 的缺口更小，更快能达到目标。**
