# Claude Code v2.1.108 命令行参考（中文版）

## 基本用法

```
claude [选项] [命令] [提示词]
```

默认进入交互式会话；使用 `-p/--print` 进入非交互式输出模式（适合管道）。

---

## 参数

**prompt** — 你的提示词（直接写在命令末尾）

---

## 会话控制类

| 选项 | 说明 |
|---|---|
| `-c, --continue` | 继续当前目录下最近的一次会话 |
| `-r, --resume [值]` | 按 session ID 恢复会话，或打开交互式选择器（可带搜索词） |
| `--session-id <uuid>` | 指定会话 ID（必须合法 UUID） |
| `--fork-session` | 恢复时创建新 session ID 而非复用原 ID，配合 `--resume/--continue` 使用 |
| `--no-session-persistence` | 禁用会话持久化，不落盘、不可恢复（仅 `--print` 下有效） |
| `-n, --name <名称>` | 设置会话显示名（`/resume` 列表和终端标题会显示） |
| `--from-pr [值]` | 按 PR 号或 URL 恢复与该 PR 关联的会话，或打开交互式选择器 |

---

## 模型与效率

| 选项 | 说明 |
|---|---|
| `--model <模型>` | 指定模型，支持别名（`sonnet`/`opus`）或完整名（`claude-sonnet-4-6`） |
| `--fallback-model <模型>` | 默认模型过载时自动降级到指定模型（仅 `--print` 下有效） |
| `--effort <级别>` | 思考强度：`low` / `medium` / `high` / `max` |
| `--max-budget-usd <金额>` | 本次调用最大花费上限（美元，仅 `--print` 下有效） |

---

## 权限与工具

| 选项 | 说明 |
|---|---|
| `--permission-mode <模式>` | 权限模式：`acceptEdits` / `auto` / `bypassPermissions` / `default` / `dontAsk` / `plan` |
| `--dangerously-skip-permissions` | ⚠️ 直接跳过所有权限检查。仅建议在无网络的沙箱中使用 |
| `--allow-dangerously-skip-permissions` | 允许"跳过权限检查"作为一个选项存在，但默认不启用 |
| `--allowedTools <tools...>` | 允许的工具白名单，例如 `"Bash(git *) Edit"` |
| `--disallowedTools <tools...>` | 禁用的工具黑名单 |
| `--tools <tools...>` | 从内置工具集中指定可用工具；`""` 全禁用，`default` 全启用，或指定 `"Bash,Edit,Read"` |
| `--disable-slash-commands` | 禁用所有 skills |
| `--add-dir <目录...>` | 额外允许工具访问的目录 |

---

## 系统提示词

| 选项 | 说明 |
|---|---|
| `--system-prompt <提示词>` | 用自定义 system prompt 替换默认的 |
| `--append-system-prompt <提示词>` | 在默认 system prompt 后追加内容 |
| `--exclude-dynamic-system-prompt-sections` | 把每机器相关段（cwd、env、memory 路径、git status）从 system prompt 移到首条 user message。可提升跨用户的 prompt cache 命中率。仅对默认 system prompt 有效 |

---

## 输入输出格式（管道/脚本）

| 选项 | 说明 |
|---|---|
| `-p, --print` | 打印响应后退出，适合管道。⚠️ 此模式会跳过 workspace 信任对话框，只在可信目录使用 |
| `--input-format <格式>` | 输入格式：`text`（默认）或 `stream-json`（实时流式输入），仅 `--print` 下有效 |
| `--output-format <格式>` | 输出格式：`text` / `json` / `stream-json`，仅 `--print` 下有效 |
| `--include-partial-messages` | 输出部分消息块（仅 `--print` + `--output-format=stream-json`） |
| `--include-hook-events` | 输出中包含所有 hook 生命周期事件（仅 `--output-format=stream-json`） |
| `--replay-user-messages` | 把 stdin 的 user 消息回显到 stdout 作为确认（仅 `--input-format=stream-json` + `--output-format=stream-json`） |
| `--json-schema <schema>` | 用 JSON Schema 校验结构化输出 |

---

## Agent 与 Plugin

| 选项 | 说明 |
|---|---|
| `--agent <agent>` | 本次会话使用的 agent，覆盖配置中的 `agent` 设置 |
| `--agents <json>` | 用 JSON 定义自定义 agents，如 `'{"reviewer": {"description": "...", "prompt": "..."}}'` |
| `--plugin-dir <路径>` | 从目录加载插件（可重复使用：`--plugin-dir A --plugin-dir B`） |

---

## MCP

| 选项 | 说明 |
|---|---|
| `--mcp-config <configs...>` | 从 JSON 文件或字符串加载 MCP servers（空格分隔） |
| `--strict-mcp-config` | 只使用 `--mcp-config` 指定的 MCP servers，忽略其他所有 MCP 配置 |
| `--mcp-debug` | ⚠️ 已废弃，改用 `--debug` |

---

## 配置与环境

| 选项 | 说明 |
|---|---|
| `--settings <文件或JSON>` | 加载额外设置（路径或 JSON 字符串） |
| `--setting-sources <sources>` | 逗号分隔的设置来源：`user` / `project` / `local` |
| `--betas <betas...>` | API 请求中带的 beta headers（仅 API key 用户） |
| `--file <specs...>` | 启动时下载的文件资源，格式 `file_id:相对路径`，如 `--file file_abc:doc.txt file_def:img.png` |

---

## Bare 模式（极简模式）

`--bare` — 极简启动，跳过以下所有内容：

- hooks、LSP、plugin sync、attribution、auto-memory
- 后台预取、keychain 读取、CLAUDE.md 自动发现

同时设置环境变量 `CLAUDE_CODE_SIMPLE=1`。

**认证约束**：

- Anthropic 认证严格限定为 `ANTHROPIC_API_KEY` 或通过 `--settings` 指定的 `apiKeyHelper`
- 绝不读取 OAuth 和 keychain
- 第三方 provider（Bedrock/Vertex/Foundry）使用自己的凭证

**上下文必须显式提供**，通过：`--system-prompt[-file]`、`--append-system-prompt[-file]`、`--add-dir`（CLAUDE.md 目录）、`--mcp-config`、`--settings`、`--agents`、`--plugin-dir`。

Skills 仍可通过 `/skill-name` 解析。

---

## 集成

| 选项 | 说明 |
|---|---|
| `--ide` | 启动时若恰好存在一个可用 IDE，自动连接 |
| `--chrome` / `--no-chrome` | 启用/禁用 Claude in Chrome 集成 |
| `-w, --worktree [名称]` | 为本次会话创建一个新的 git worktree |
| `--tmux` | 为 worktree 创建 tmux 会话（需配合 `--worktree`）。有 iTerm2 时使用原生分屏；`--tmux=classic` 强制使用传统 tmux |
| `--brief` | 启用 `SendUserMessage` 工具，支持 agent 主动向用户通信 |
| `--remote-control-session-name-prefix <前缀>` | 自动生成的 Remote Control 会话名前缀（默认 hostname） |

---

## 调试

| 选项 | 说明 |
|---|---|
| `-d, --debug [filter]` | 启用 debug，可按类别过滤，如 `"api,hooks"` 或 `"!1p,!file"` |
| `--debug-file <路径>` | 写 debug 日志到指定文件（隐式启用 debug） |
| `--verbose` | 覆盖配置中的 verbose 设置 |

---

## 其他

| 选项 | 说明 |
|---|---|
| `-h, --help` | 显示帮助 |
| `-v, --version` | 显示版本号 |

---

## 子命令

| 命令 | 说明 |
|---|---|
| `agents` | 列出已配置的 agents |
| `auth` | 管理认证 |
| `auto-mode` | 查看 auto mode 分类器配置 |
| `doctor` | 检查自动更新器健康状况。⚠️ 会跳过 workspace 信任对话框，并会拉起 `.mcp.json` 中的 stdio servers 做健康检查，只在可信目录使用 |
| `install [target]` | 安装 Claude Code 原生构建版本。`target` 可选 `stable`、`latest` 或特定版本号 |
| `mcp` | 配置和管理 MCP servers |
| `plugin` / `plugins` | 管理 Claude Code 插件 |
| `setup-token` | 设置长期认证 token（需订阅） |
| `update` / `upgrade` | 检查并安装更新 |

---

## 针对你使用场景的几点说明

结合你在搭建 AI 推理栈（vLLM + open-webui）和做 agent 编排的背景，几个可能用得上的点：

1. **`--bare` + `--mcp-config` + `--settings`** 组合，非常适合跑在 CI 或 sandbox 里的脚本化场景，可以完全避开 keychain 和 CLAUDE.md 自动发现的副作用，用 `ANTHROPIC_API_KEY` 做干净的认证。

2. **`-p` + `--output-format stream-json` + `--include-partial-messages`** 适合接到你自己的 LLM client 或 agent orchestrator 里做流式处理。

3. **`--max-budget-usd`** 在跑批量 agent 任务时可以兜底防止失控。

4. **`--agents`** 支持直接从命令行 JSON 注入 agent 定义，做一次性特化 agent 很方便，不用落盘。

5. **`--strict-mcp-config`** 在做 MCP server 开发测试时很有用，可以隔离掉全局已连接的其他 MCP，只用你当前在调试的那个。
