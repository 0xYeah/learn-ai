<!-- TOC -->

- [1. DGX Spark: vLLM + vllm-playground 部署手册](#1-dgx-spark-vllm--vllm-playground-部署手册)
    - [注意事项:](#注意事项)
    - [1.1. 前置依赖](#11-前置依赖)
    - [1.2. 一键安装(推荐)](#12-一键安装推荐)
    - [1.3. 脚本做了什么(目录与文件清单)](#13-脚本做了什么目录与文件清单)
    - [1.4. `vllm.conf` 字段说明](#14-vllmconf-字段说明)
    - [1.5. 常用运维命令](#15-常用运维命令)
    - [1.6. 冒烟测试](#16-冒烟测试)
    - [1.7. 手动步骤(对照参考)](#17-手动步骤对照参考)
        - [1.7.1. 准备目录](#171-准备目录)
        - [1.7.2. 安装 vLLM](#172-安装-vllm)
        - [1.7.3. 安装 vllm-playground](#173-安装-vllm-playground)
        - [1.7.4. 创建 `~/.vllm-env/vllm.conf`](#174-创建-vllm-envvllmconf)
        - [1.7.5. 创建 `~/.vllm-env/vllm-start.sh`](#175-创建-vllm-envvllm-startsh)
        - [1.7.6. systemd unit](#176-systemd-unit)
    - [1.8. 故障排查](#18-故障排查)

<!-- /TOC -->

# 1. DGX Spark: vLLM + vllm-playground 部署手册

> 在 DGX Spark 上安装最新版 `vllm` 和 `vllm-playground`,配置成开机自启,模型走 `hf-mirror.com`。
>
> 推荐用配套的一键脚本 `install_dgx-spark_vllm_vllm-playground.sh`,后面也附了手动步骤作为对照。
>
> 参考:
> - <https://docs.vllm.ai/en/latest/getting_started/quickstart/>
> - <https://github.com/micytao/vllm-playground>

---
## 注意事项:
* <font color=red> 文档中出现的 `<Custom_User>` 为必须替换项 </font>
* <font color=red> 文档中出现的 `<Custom_User>` 为必须替换项 </font>
* <font color=red> 文档中出现的 `<Custom_User>` 为必须替换项 </font>

## 1.1. 前置依赖

```bash
nvidia-smi              # GB10 / Blackwell
nvcc --version          # CUDA 13.0
python3.12 --version
```

`uv` 没装的话脚本会自动装,手动装也行:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
```

---

## 1.2. 一键安装(推荐)

把 `install_dgx-spark_vllm_vllm-playground.sh` 放到任意目录,然后:

```bash
bash install_dgx-spark_vllm_vllm-playground.sh
```

脚本特性:

- **幂等**:重复跑只会补齐缺失的步骤,已经完成的会跳过
- **动态识别用户**:`SUDO_USER` / `USER` 自动识别,从 `/etc/passwd` 拿真实 home
- **检测包是否真装好**:用 `importlib.metadata` 而不是看目录,坏了的环境也能检出来
- **保护你的配置**:`vllm.conf` 已存在就不覆盖,避免覆盖你改过的模型选择
- **systemd unit 内容比对**:一致就跳过,不一致才覆盖并 `daemon-reload`
- **完整日志**:所有步骤和 `uv pip install` 输出落到 `~/.vllm-install.log`

常用参数:

```bash
bash install_dgx-spark_vllm_vllm-playground.sh             # 正常安装/补齐
bash install_dgx-spark_vllm_vllm-playground.sh --status    # 只检查不改动
bash install_dgx-spark_vllm_vllm-playground.sh --force     # 强制重装两个 venv
```

跑完后按打印的提示启动:

```bash
sudo systemctl start vllm.service vllm-playground.service
sudo journalctl -u vllm.service -f
```

浏览器打开 `http://<dgx-spark-ip>:7860`。

---

## 1.3. 脚本做了什么(目录与文件清单)

| 路径 | 说明 |
|---|---|
| `~/.vllm-env/` | vLLM server venv |
| `~/.vllm-env/vllm.conf` | vLLM 启动参数(可改) |
| `~/.vllm-env/vllm-start.sh` | systemd 调用的启动脚本 |
| `~/.vllm-playground-env/` | vllm-playground venv(独立隔离) |
| `/opt/vllm/logs/` | 服务日志(systemd 落盘) |
| `/opt/vllm/hf-cache/` | HuggingFace 模型缓存(由 `HF_HOME` 控制) |
| `/etc/systemd/system/vllm.service` | vLLM 服务 unit |
| `/etc/systemd/system/vllm-playground.service` | Playground 服务 unit |
| `~/.vllm-install.log` | 一键脚本的安装日志 |

> **重建 venv 的注意事项**:`vllm.conf` 和 `vllm-start.sh` 在 `~/.vllm-env/` 根目录里。如果以后 `rm -rf ~/.vllm-env` 重建,先 `cp ~/.vllm-env/vllm.conf /tmp/` 备份,装完拷回来。`hf-cache` 和 `logs` 在 `/opt/vllm/` 下,不受影响。

---

## 1.4. `vllm.conf` 字段说明

```bash
# ---- 模型 ----
VLLM_MODEL=Qwen/Qwen3-14B-FP8       # HuggingFace 模型 ID,或本地路径
SERVED_MODEL_NAME=qwen3-14b         # API 暴露的别名,客户端用这个调用

# ---- 监听 ----
VLLM_HOST=0.0.0.0                   # 0.0.0.0 = 对外;127.0.0.1 = 仅本机
VLLM_PORT=8000

# ---- 运行参数 ----
MAX_MODEL_LEN=32768                 # 上下文长度,大了吃显存
GPU_MEMORY_UTILIZATION=0.90         # 显存利用上限

# 额外 flag,空格分隔。例如:
# EXTRA_FLAGS="--enable-auto-tool-choice --tool-call-parser hermes --reasoning-parser qwen3"
EXTRA_FLAGS=""

# ---- 鉴权(可选)----
VLLM_API_KEY=                       # 非空就启用 Bearer 鉴权

# ---- HuggingFace ----
HF_TOKEN=                           # gated 模型(Llama 等)需要
HF_HOME=/opt/vllm/hf-cache          # 模型缓存目录
HF_ENDPOINT=https://hf-mirror.com   # 国内镜像
```

**换模型**:改 `VLLM_MODEL` + `SERVED_MODEL_NAME`,然后 `sudo systemctl restart vllm.service`。

**用本地模型**:`VLLM_MODEL` 直接写绝对路径,vllm 检测到是路径就不联网。

---

## 1.5. 常用运维命令

```bash
# 查看状态
sudo systemctl status vllm.service
sudo systemctl status vllm-playground.service

# 看实时日志
sudo journalctl -u vllm.service -f
sudo journalctl -u vllm-playground.service -f
tail -f /opt/vllm/logs/vllm.log

# 重启
sudo systemctl restart vllm.service
sudo systemctl restart vllm-playground.service

# 换模型
vi ~/.vllm-env/vllm.conf
sudo systemctl restart vllm.service

# 升级 vllm
source ~/.vllm-env/bin/activate
uv pip install -U vllm
deactivate
sudo systemctl restart vllm.service

# 升级 vllm-playground
source ~/.vllm-playground-env/bin/activate
uv pip install -U vllm-playground
deactivate
sudo systemctl restart vllm-playground.service

# 看模型缓存占用
du -sh /opt/vllm/hf-cache/hub/models--*

# 看安装日志(脚本跑过的历史)
tail -100 ~/.vllm-install.log
```

---

## 1.6. 冒烟测试

```bash
# 1. 模型列表
curl -sS http://127.0.0.1:8000/v1/models | python3 -m json.tool

# 2. Chat completion
curl -sS http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-14b",
    "messages": [{"role": "user", "content": "12*17=?"}],
    "max_tokens": 32
  }' | python3 -m json.tool
```

**Web UI**:浏览器 `http://<dgx-spark-ip>:7860`,在 **Management → Instances** 加一个 Remote 后端,URL 填 `http://127.0.0.1:8000`,API Key 和 `vllm.conf` 一致(没设留空)。

---

## 1.7. 手动步骤(对照参考)

如果你不想用一键脚本,或者想理解每一步做了什么。

### 1.7.1. 准备目录

```bash
sudo mkdir -p /opt/vllm/{logs,hf-cache}
sudo chown -R $USER:$USER /opt/vllm
```

### 1.7.2. 安装 vLLM

```bash
# 国内 PyPI 镜像加速
export UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple

uv venv --python 3.12 ~/.vllm-env
source ~/.vllm-env/bin/activate
uv pip install vllm
python -c "import vllm; print(vllm.__version__)"
deactivate
```

### 1.7.3. 安装 vllm-playground

```bash
uv venv --python 3.12 ~/.vllm-playground-env
source ~/.vllm-playground-env/bin/activate
uv pip install vllm-playground
vllm-playground --help
deactivate
```

### 1.7.4. 创建 `~/.vllm-env/vllm.conf`

```bash
cat > ~/.vllm-env/vllm.conf <<'EOF'
VLLM_MODEL=Qwen/Qwen3-14B-FP8
SERVED_MODEL_NAME=qwen3-14b
VLLM_HOST=0.0.0.0
VLLM_PORT=8000
MAX_MODEL_LEN=32768
GPU_MEMORY_UTILIZATION=0.90
EXTRA_FLAGS=""
VLLM_API_KEY=
HF_TOKEN=
HF_HOME=/opt/vllm/hf-cache
HF_ENDPOINT=https://hf-mirror.com
EOF
chmod 600 ~/.vllm-env/vllm.conf
```

### 1.7.5. 创建 `~/.vllm-env/vllm-start.sh`

```bash
cat > ~/.vllm-env/vllm-start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

VENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${VENV_DIR}/vllm.conf"
source "${VENV_DIR}/bin/activate"

export HF_HOME
export HF_ENDPOINT
[[ -n "${HF_TOKEN}" ]] && export HF_TOKEN

ARGS=(
    "${VLLM_MODEL}"
    --served-model-name "${SERVED_MODEL_NAME}"
    --host "${VLLM_HOST}"
    --port "${VLLM_PORT}"
    --max-model-len "${MAX_MODEL_LEN}"
    --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION}"
)

[[ -n "${VLLM_API_KEY}" ]] && ARGS+=(--api-key "${VLLM_API_KEY}")

# shellcheck disable=SC2206
EXTRAS=(${EXTRA_FLAGS})

exec vllm serve "${ARGS[@]}" "${EXTRAS[@]}"
EOF
chmod +x ~/.vllm-env/vllm-start.sh
```

### 1.7.6. systemd unit

> `User` / `Group` / `HOME` / `ExecStart` 路径里的用户名按你实际情况改。

`/etc/systemd/system/vllm.service`:

```ini
[Unit]
Description=vLLM OpenAI-compatible server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=<Custom_User>
Group=<Custom_User>
Environment=HOME=/home/<Custom_User>
TimeoutStartSec=1800
Restart=on-failure
RestartSec=10
ExecStart=/home/<Custom_User>/.vllm-env/vllm-start.sh
StandardOutput=append:/opt/vllm/logs/vllm.log
StandardError=append:/opt/vllm/logs/vllm.err.log
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
```

`/etc/systemd/system/vllm-playground.service`:

```ini
[Unit]
Description=vLLM Playground Web UI
After=network-online.target vllm.service
Wants=network-online.target

[Service]
Type=simple
User=<Custom_User>
Group=<Custom_User>
Environment=HOME=/home/<Custom_User>
Restart=on-failure
RestartSec=10
ExecStart=/bin/bash -lc 'source /home/<Custom_User>/.vllm-playground-env/bin/activate && exec vllm-playground --port 7860'
StandardOutput=append:/opt/vllm/logs/playground.log
StandardError=append:/opt/vllm/logs/playground.err.log

[Install]
WantedBy=multi-user.target
```

启用并启动:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vllm.service
sudo systemctl enable --now vllm-playground.service
```

---

## 1.8. 故障排查

| 现象 | 处理 |
|---|---|
| `vllm serve` 找不到 | venv 没激活,`source ~/.vllm-env/bin/activate` |
| systemd 启动卡住很久 | 在下载模型,`tail -f /opt/vllm/logs/vllm.log` 看进度 |
| 下载慢 | 确认 `HF_ENDPOINT=https://hf-mirror.com` 已在 `vllm.conf` 且被 export |
| OOM / KV cache 不够 | 降 `MAX_MODEL_LEN` 或 `GPU_MEMORY_UTILIZATION` 到 0.85 |
| systemd 起不来但手跑可以 | service 里 `Environment=HOME=...` 必须是绝对路径,不能用 `~` |
| Web UI 连不上 vLLM | Management → Instances 加 Remote,URL `http://127.0.0.1:8000`,API Key 对齐 |
| 7860 访问不了 | 防火墙/Tailscale 检查,`vllm-playground` 默认监听 `0.0.0.0` |
| 想看脚本跑过啥 | `cat ~/.vllm-install.log` |
