
<!-- TOC -->

- [1. everything-claude-code (ECC Tool)](#1-everything-claude-code-ecc-tool)
  - [1.1. 官网](#11-官网)
  - [1.2. 安装](#12-安装)
    - [第一步：安装插件](#第一步安装插件)
    - [第二步：安装规则（必需）](#第二步安装规则必需)
  - [常用命令](#常用命令)

<!-- /TOC -->

# 1. everything-claude-code (ECC Tool)

## 1.1. 官网
* https://github.com/affaan-m/everything-claude-code

## 1.2. 安装
### 第一步：安装插件
```
# 添加市场
/plugin marketplace add affaan-m/everything-claude-code

# 安装插件
/plugin install everything-claude-code@everything-claude-code
````

### 第二步：安装规则（必需）
> ⚠️ **重要提示：** Claude Code 插件无法自动分发 `rules`，需要手动安装：

```
# 首先克隆仓库
git clone https://github.com/affaan-m/everything-claude-code.git

# 复制规则（通用 + 语言特定）
```
cp -r everything-claude-code/rules/common/* ~/.claude/rules/
cp -r everything-claude-code/rules/typescript/* ~/.claude/rules/   # 选择你的技术栈
cp -r everything-claude-code/rules/python/* ~/.claude/rules/
cp -r everything-claude-code/rules/golang/* ~/.claude/rules/
cp -r everything-claude-code/rules/perl/* ~/.claude/rules/
````

## 常用命令
```
/everything-claude-code:plan          # 功能规划，开始新模块前用
/everything-claude-code:architect     # 架构设计
/everything-claude-code:review        # 代码审查
/everything-claude-code:tdd           # 测试驱动开发引导
/everything-claude-code:security      # 安全审查
/everything-claude-code:refactor      # 重构清理
/everything-claude-code:doc-update    # 文档同步

```
