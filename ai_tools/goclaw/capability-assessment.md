# GoClaw 能力评估报告

> 核心问题：能否给一句话需求或红头文件，自动做出项目？

---

## 一句话结论

**不能，但距离能做到只差几个关键模块。**

GoClaw 的底座（Agent 循环、工具执行、多 Agent 协作、文档解析）都已生产级，但缺乏"需求→项目"链路上的关键胶水：持久化规划、项目脚手架、代码审查-修复循环。

---

## 完整能力矩阵

| 能力 | 完成度 | 成熟度 | 说明 |
|------|--------|--------|------|
| Agent 循环（Think→Act→Observe）| 100% | 生产级 | 最多 20 次迭代，无限循环检测 |
| 工具系统（110+ 工具）| 90% | 生产级 | 文件、执行、网页、媒体、协作均有 |
| 文档解析（PDF/图像）| 95% | 生产级 | Gemini/Anthropic 视觉链 |
| 技能系统（SKILL.md）| 95% | 生产级 | BM25+向量混合搜索、多层覆盖 |
| 多 Agent 协作 & 委派 | 80% | 生产级 | 同步/异步委派，Team 任务板 |
| 代理自我进化（SOUL.md）| 60% | 手动驱动 | 框架完整，但是人工触发 |
| **持久化规划（PRD/任务列表）** | **0%** | **缺失** | **Agent 没有自己的规划存储** |
| **项目初始化（scaffold）** | **0%** | **缺失** | **无脚手架工具** |
| **代码审查-修复循环** | **10%** | **框架仅** | Hooks 框架存在但未集成 |
| 自动测试集成 | 0% | 缺失 | 无 run_tests/build 专用工具 |
| 端到端工作流编排 | 30% | 高度手动 | 需 LLM 自行编排，无固化流程 |

---

## 场景一：一句话需求 → 项目

**输入示例：** "帮我做一个博客系统，Next.js + PostgreSQL"

### 能做到的 ✅
1. 理解需求（LLM 推理）
2. 规划步骤（LLM 在上下文中构建计划）
3. 用 `write_file` 逐个创建文件
4. 用 `exec` 运行 `npm install` / `pnpm build`
5. 把生成结果存入工作区
6. 委派给多个 Agent 并行写不同模块

### 做不到的 ❌
1. **无法持久化规划** —— 没有 PRD/任务列表 Store，计划只存在于上下文，20 次迭代限制到了就断
2. **无法脚手架初始化** —— 没有 `scaffold("nextjs")` 工具，只能手写每一行
3. **无自动测试-修复循环** —— 写完代码不会自动跑测试→捕获报错→修复
4. **无代码审查** —— 写完不会有 Agent 自动 review 质量
5. **无中间检查点** —— 中途断掉无法从断点恢复，只能重头来

### 实际效果预估

> 简单项目（<5 个文件，无复杂逻辑）：大概率能完成
> 中等项目（博客、Todo App）：能生成骨架，细节靠运气
> 复杂项目（多服务、微服务、带 CI/CD）：会卡住或生成残缺代码

---

## 场景二：红头文件 → 项目

**输入示例：** 上传一份政府采购通知 PDF / 扫描件

### 能做到的 ✅
1. **读取文档** —— `read_document` 支持 PDF（20MB）、DOCX；`read_image` 支持扫描图
2. **识别文本** —— Gemini Pro Vision / Anthropic Claude 提取文本和结构
3. **理解需求** —— LLM 分析公文内容，提取功能点
4. **生成代码** —— 同场景一的生成能力
5. **表格解析** —— 能识别红头文件中的表格、条款、附件

### 做不到的 ❌
1. **无标准化需求提取** —— 解析结果只传给 LLM，没有持久化为结构化需求单
2. **无公文格式理解的专用工具** —— 没有针对政府公文的 prompt 模板或 SKILL.md
3. **无文件类型的自动路由** —— 用户需要知道传哪个工具（read_document vs read_image）

### 实际效果预估

> 文档解析本身：**可以，质量不错**（Gemini 对中文 PDF 识别较好）
> 解析后自动生成项目：**受限于场景一的缺陷**

---

## 与 OpenHands / Devin 对比

| 维度 | GoClaw | OpenHands | Devin |
|------|--------|-----------|-------|
| 多 Agent 协作 | ✅ 强（Team+任务板）| ⚠️ 弱 | ⚠️ 弱 |
| 多平台通道（Telegram 等）| ✅ 7 个 | ❌ | ❌ |
| 文档解析 | ✅ 强 | ⚠️ 弱 | ⚠️ 弱 |
| 技能库 | ✅ 完整 | ❌ | ❌ |
| 向量内存 | ✅ pgvector | ⚠️ 简单 | ⚠️ 简单 |
| 持久化规划（PRD）| ❌ 缺失 | ✅ 有 | ✅ 有 |
| 项目脚手架 | ❌ 缺失 | ✅ 有 | ✅ 有 |
| 自动测试-修复 | ❌ 缺失 | ✅ 有 | ✅ 有 |
| 自主项目生成 | ⚠️ 部分 | ✅ 强 | ✅ 强 |
| 多租户企业部署 | ✅ 生产级 | ❌ | ❌ |

**总结：** GoClaw 的基础设施比 OpenHands/Devin 更完善（多租户、多通道、技能库、团队协作），但在"自主写项目"的核心用例上反而不如它们，因为缺少那 3 个关键环节。

---

## 要补什么才能达到"给需求自动出项目"

按优先级排列，共 **3 个关键缺口**：

### P0 — 持久化规划 Store（2-3 周）

```go
// 新增 PlanStore 接口
type PlanStore interface {
    CreatePlan(ctx, agentID, userID string, prd PRD) (*Plan, error)
    GetPlan(ctx, planID string) (*Plan, error)
    UpdateTask(ctx, taskID string, status TaskStatus) error
    ListTasks(ctx, planID string) ([]*Task, error)
}

type PRD struct {
    Title       string
    Goal        string
    TechStack   []string
    Features    []*Feature
    Tasks       []*Task      // 可执行的任务分解
    Checkpoint  int          // 当前执行到第几步
}
```

为什么重要：Agent 迭代限制是 20 次，复杂项目需要跨多轮对话执行，没有持久化规划就无法断点续传。

### P0 — 项目脚手架工具（1-2 周）

```go
// 新增 scaffold 工具
// 输入：{ stack: "nextjs", template: "blog", dir: "./my-blog" }
// 输出：创建完整目录结构 + 依赖文件 + .gitignore + README
scaffold("nextjs-postgres")
// → package.json, tsconfig.json, next.config.js, prisma/schema.prisma
//   src/app/page.tsx, src/lib/db.ts, .env.example, Dockerfile
```

为什么重要：目前只能用 `write_file` 一个个手写，效率极低且容易出错。

### P1 — 测试-修复循环 Hook（2-3 周）

```go
// hooks.go 已有框架，需接入：
HookConfig{
    Event:          "tool.exec.completed",
    Trigger:        "bash_exec contains 'npm test'",
    Type:           HookTypeAgent,
    TargetAgent:    "code-fixer",  // 专门的修复 Agent
    BlockOnFailure: false,
    MaxRetries:     3,
}
```

为什么重要：写完代码跑测试失败，当前只能靠 LLM 在下一次迭代里猜问题，有了 Hook 就能自动触发修复。

---

## 实现路线图

```
Week 1-2: 持久化规划 Store
  → 新增 plan_store.go 接口 + pg 实现
  → 新增 plans/plan_tasks 数据库表
  → 新增 create_plan / update_task / get_plan 工具

Week 3: 项目脚手架工具
  → 内置主流技术栈模板（Next.js, Go, Python FastAPI, Spring Boot）
  → scaffold 工具调用模板引擎
  → 支持自定义模板 YAML

Week 4-5: 测试-修复 Hook
  → 激活 hooks.go 的命令钩子
  → 集成 exec 失败 → 捕获错误 → 传给修复 Agent
  → 最多 3 次重试

Week 6: 红头文件专用 SKILL.md
  → 政府公文需求提取 prompt 模板
  → 自动路由 PDF/图片 → read_document/read_image
  → 输出标准化 PRD 格式
```

完成以上 6 周工作后，GoClaw 可以做到：

> **上传红头文件 → 提取需求 → 生成 PRD → 脚手架初始化 → 逐模块开发（多 Agent 并行）→ 自动测试修复 → 输出完整项目**
