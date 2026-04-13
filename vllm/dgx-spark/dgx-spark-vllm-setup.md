# DGX Spark: vLLM + vllm-playground 部署手册

> 在 DGX Spark(GB10 / Blackwell / sm_121 / **CUDA 13**)上安装最新版 `vllm` 和 `vllm-playground`,**用 vllm 官方 cu130 wheel 直接对齐系统 CUDA**,模型默认走 `hf-mirror.com` + `hf_transfer` 加速,systemd 自启动,日志走 journald。
>
> 推荐用配套的一键脚本 `install_dgx-spark_vllm_vllm-playground.sh`,后面也保留了手动步骤作为对照。
>
> 参考:
> - <https://docs.vllm.ai/en/stable/getting_started/installation/gpu/>
> - <https://github.com/micytao/vllm-playground>

---

## DGX Spark 关键背景

DGX Spark 系统装的是 **CUDA 13.0**(`/usr/local/cuda` 下是 `libcudart.so.13`)。**vllm PyPI 默认 wheel 以前只编 cu12.x**,装上之后会到处缺 `libcudart.so.12` / `libtorch_cuda.so` 这种 cu12 链接库。

**正确的解法不是补 cu12 runtime,而是直接装 vllm 的 cu130 wheel**,版本对齐,系统的 `/usr/local/cuda` 直接能用,**零 LD_LIBRARY_PATH workaround**:

```bash
uv pip install vllm \
    --torch-backend=auto \
    --extra-index-url https://wheels.vllm.ai/0.19.0/cu130
```

- `--torch-backend=auto`:让 uv 自动从 PyTorch 官方源拿对应 cu130 的 torch wheel
- `--extra-index-url https://wheels.vllm.ai/0.19.0/cu130`:vllm 官方 cu130 wheel 索引

**vllm 0.19.0 起,CUDA 13 支持已成为官方稳定版本**。0.18 及之前的版本默认 wheel 只到 cu12.x。

---

## 0. 前置依赖

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

## 1. 一键安装(推荐)

```bash
bash install_dgx-spark_vllm_vllm-playground.sh
```

脚本特性:

- **幂等**:重复跑只补缺失步骤,已完成的跳过
- **动态识别用户**:从 `SUDO_USER` / `USER` + `/etc/passwd` 拿真实 home
- **检测 cu130 是否就位**:用 `torch.version.cuda` 校验,装错 cu12 会自动检出并重装
- **保护配置**:`vllm.conf` 已存在就不覆盖
- **systemd unit 内容比对**:一致就跳过,不一致才覆盖并 `daemon-reload`
- **优先 `--torch-backend=auto`,自动 fallback** 到双 extra-index + `unsafe-best-match`(老 uv 兼容)
- **走清华 PyPI 镜像 + hf-mirror + hf_transfer**:三层下载加速
- **日志走 journald**:不写 `/opt/vllm/logs/`,统一 `journalctl` 看
- **完整安装日志**:所有输出落到 `~/.vllm-install.log`

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

## 2. 脚本做了什么(目录与文件清单)

| 路径 | 说明 |
|---|---|
| `~/.vllm-env/` | vLLM server venv(cu130) |
| `~/.vllm-env/vllm.conf` | vLLM 启动参数(可改) |
| `~/.vllm-env/vllm-start.sh` | systemd 调用的启动脚本 |
| `~/.vllm-playground-env/` | vllm-playground venv(独立隔离) |
| `/opt/vllm/hf-cache/` | HuggingFace 模型缓存(由 `HF_HOME` 控制) |
| `/etc/systemd/system/vllm.service` | vLLM 服务 unit |
| `/etc/systemd/system/vllm-playground.service` | Playground 服务 unit |
| `~/.vllm-install.log` | 一键脚本的安装日志 |

> **重建 venv 的注意事项**:`vllm.conf` 和 `vllm-start.sh` 在 `~/.vllm-env/` 根目录里。如果 `rm -rf ~/.vllm-env` 重建,先 `cp ~/.vllm-env/vllm.conf /tmp/` 备份,装完拷回来。`hf-cache` 在 `/opt/vllm/` 下,不受影响。

---

## 3. `vllm.conf` 字段说明

```bash
# ---- 模型 ----
VLLM_MODEL=KyleHessling1/Qwopus3.5-27B-v3-FP8-vllm-ready
SERVED_MODEL_NAME=qwopus3.5-27b-fp8

# ---- 监听 ----
VLLM_HOST=0.0.0.0
VLLM_PORT=8000

# ---- 运行参数 ----
MAX_MODEL_LEN=131072                # 上下文长度
GPU_MEMORY_UTILIZATION=0.92         # 显存利用上限

# 额外 flag
EXTRA_FLAGS="--dtype bfloat16 --trust-remote-code --reasoning-parser qwen3 --enable-prefix-caching"

# ---- 鉴权(可选)----
VLLM_API_KEY=

# ---- HuggingFace ----
HF_TOKEN=
HF_HOME=/opt/vllm/hf-cache
HF_ENDPOINT=https://hf-mirror.com
HF_HUB_ENABLE_HF_TRANSFER=1
```

### EXTRA_FLAGS 的含义

| Flag | 作用 |
|---|---|
| `--dtype bfloat16` | FP8 模型的标准 recipe:权重 FP8 + 激活 BF16 |
| `--trust-remote-code` | 允许执行模型仓库自带的 Python 代码,Qwen3.5 架构必需 |
| `--reasoning-parser qwen3` | 把 `<think>...</think>` 思考链分离到 `reasoning_content` 字段 |
| `--enable-prefix-caching` | 重复 prompt 前缀缓存复用,长上下文/agent 多轮对话提速巨大 |

### 换模型

改 `VLLM_MODEL` + `SERVED_MODEL_NAME`,然后 `sudo systemctl restart vllm.service`。

### 用本地模型

`VLLM_MODEL` 直接写绝对路径,vllm 检测到是路径就不联网。

---

## 4. 默认模型说明

默认配置用的是 **`KyleHessling1/Qwopus3.5-27B-v3-FP8-vllm-ready`**:

- 这是 `Jackrong/Qwopus3.5-27B-v3-FP8` 的修复版,**权重 bit-identical**,只修了 metadata
- Jackrong 原版的 safetensors tensor 名带 `model.language_model.*` 前缀(VL 模型痕迹),vllm 加载会失败
- Kyle 这个 fork 把 tensor 名重命名成 `model.*`,删掉 transformers 5.x 专属字段
- ~30 GB,Blackwell FP8 tensor core 原生加速,质量 ≈ BF16 原版

### 其他模型选择

| 模型 | 大小 | 特点 |
|---|---|---|
| `KyleHessling1/Qwopus3.5-27B-v3-FP8-vllm-ready` | 30 GB | **默认推荐**,FP8 加速 + 大上下文 |
| `Jackrong/Qwopus3.5-27B-v3` | 54.7 GB | BF16 原版,无量化损失 |
| `Qwen/Qwen3-14B-FP8` | 14 GB | 更小,适合先跑通链路 |
| `mconcat/Qwopus3.5-27B-v3-NVFP4` | 24 GB | NVFP4,但 vanilla vllm 性能未充分释放 |

---

## 5. 常用运维命令

```bash
# 查看状态
sudo systemctl status vllm.service
sudo systemctl status vllm-playground.service

# 看实时日志(走 journald)
sudo journalctl -u vllm.service -f
sudo journalctl -u vllm-playground.service -f

# 看历史日志
sudo journalctl -u vllm.service --since "1 hour ago"
sudo journalctl -u vllm.service -n 200 --no-pager

# 重启
sudo systemctl restart vllm.service
sudo systemctl restart vllm-playground.service

# 换模型
vi ~/.vllm-env/vllm.conf
sudo systemctl restart vllm.service

# 升级 vllm(继续走 cu130)
source ~/.vllm-env/bin/activate
uv pip install -U vllm \
    --torch-backend=auto \
    --extra-index-url https://wheels.vllm.ai/<新版本>/cu130
deactivate
sudo systemctl restart vllm.service

# 升级 vllm-playground
source ~/.vllm-playground-env/bin/activate
uv pip install -U vllm-playground
deactivate
sudo systemctl restart vllm-playground.service

# 看模型缓存占用
du -sh /opt/vllm/hf-cache/hub/models--*

# 看安装日志
tail -100 ~/.vllm-install.log
```

---

## 6. 冒烟测试

```bash
# 1. 模型列表
curl -sS http://127.0.0.1:8000/v1/models | python3 -m json.tool

# 2. Chat completion
curl -sS http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwopus3.5-27b-fp8",
    "messages": [{"role": "user", "content": "12*17=?"}],
    "max_tokens": 32
  }' | python3 -m json.tool
```

**Web UI**:浏览器 `http://<dgx-spark-ip>:7860`,在 **Management → Instances** 加一个 Remote 后端,URL 填 `http://127.0.0.1:8000`,API Key 和 `vllm.conf` 一致(没设留空)。

---

## 7. 手动步骤(对照参考)

### 7.1 准备目录

```bash
sudo mkdir -p /opt/vllm/hf-cache
sudo chown -R $USER:$USER /opt/vllm
```

### 7.2 安装 vLLM(cu130 wheel)

```bash
export UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple

uv venv --python 3.12 ~/.vllm-env
source ~/.vllm-env/bin/activate

# 推荐写法(uv 0.5+)
uv pip install vllm \
    --torch-backend=auto \
    --extra-index-url https://wheels.vllm.ai/0.19.0/cu130

# 或者老 uv 的 fallback 写法
# uv pip install vllm \
#     --extra-index-url https://wheels.vllm.ai/0.19.0/cu130 \
#     --extra-index-url https://download.pytorch.org/whl/cu130 \
#     --index-strategy unsafe-best-match

# 下载加速
uv pip install hf_transfer

# 验证(关键:torch.version.cuda 必须是 13.0)
python -c "
import torch, vllm
print('vllm:', vllm.__version__)
print('torch:', torch.__version__)
print('cuda:', torch.version.cuda)
print('available:', torch.cuda.is_available())
print('device:', torch.cuda.get_device_name(0))
"
deactivate
```

期望输出:

```
vllm: 0.19.0
torch: 2.10.0+cu130
cuda: 13.0
available: True
device: NVIDIA GB10
```

### 7.3 安装 vllm-playground

```bash
uv venv --python 3.12 ~/.vllm-playground-env
source ~/.vllm-playground-env/bin/activate
uv pip install vllm-playground
vllm-playground --help
deactivate
```

### 7.4 创建 `~/.vllm-env/vllm.conf`

```bash
cat > ~/.vllm-env/vllm.conf <<'EOF'
# ---- 模型 ----
VLLM_MODEL=KyleHessling1/Qwopus3.5-27B-v3-FP8-vllm-ready
SERVED_MODEL_NAME=qwopus3.5-27b-fp8

# ---- 监听 ----
VLLM_HOST=0.0.0.0
VLLM_PORT=8000

# ---- 运行参数 ----
MAX_MODEL_LEN=131072
GPU_MEMORY_UTILIZATION=0.92

# 额外 flag
EXTRA_FLAGS="--dtype bfloat16 --trust-remote-code --reasoning-parser qwen3 --enable-prefix-caching"

# ---- 鉴权(可选)----
VLLM_API_KEY=

# ---- HF ----
HF_TOKEN=
HF_HOME=/opt/vllm/hf-cache
HF_ENDPOINT=https://hf-mirror.com
HF_HUB_ENABLE_HF_TRANSFER=1
EOF

chmod 600 ~/.vllm-env/vllm.conf
```

### 7.5 创建 `~/.vllm-env/vllm-start.sh`

cu130 路径下,**不需要任何 `LD_LIBRARY_PATH` workaround**,启动脚本非常干净:

```bash
cat > ~/.vllm-env/vllm-start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

VENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${VENV_DIR}/vllm.conf"
source "${VENV_DIR}/bin/activate"

# vllm 用 cu130 wheel,torch 也是 cu130,系统 CUDA 也是 13,
# 不需要任何 LD_LIBRARY_PATH workaround

export HF_HOME
export HF_ENDPOINT
[[ -n "${HF_TOKEN}" ]] && export HF_TOKEN
[[ -n "${HF_HUB_ENABLE_HF_TRANSFER:-}" ]] && export HF_HUB_ENABLE_HF_TRANSFER

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

### 7.6 systemd unit

> `User` / `Group` / `HOME` / `ExecStart` 路径里的用户名按你实际情况改(下面以 `unis3` 为例)。
>
> **不写 `StandardOutput=` / `StandardError=`**:让 stdout/stderr 自动走 journald,统一用 `journalctl -u vllm.service` 查看。

`/etc/systemd/system/vllm.service`:

```ini
[Unit]
Description=vLLM OpenAI-compatible server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=unis3
Group=unis3
Environment=HOME=/home/unis3
TimeoutStartSec=1800
Restart=on-failure
RestartSec=10
ExecStart=/home/unis3/.vllm-env/vllm-start.sh
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
User=unis3
Group=unis3
Environment=HOME=/home/unis3
Restart=on-failure
RestartSec=10
ExecStart=/bin/bash -c 'source /home/unis3/.vllm-playground-env/bin/activate && exec vllm-playground --port 7860'

[Install]
WantedBy=multi-user.target
```

> **为什么两个 service 写法不对称**:systemd 的 `ExecStart=` 不经过 shell,`~` 不会展开,所以必须写绝对路径。`vllm.service` 直接 exec 一个脚本文件,一行搞定;`vllm-playground.service` 需要先 `source` venv 的 activate 再启动,必须借一层 `bash -c` 才能执行复合命令 —— 但路径同样用绝对路径,不用 `~`。

启用并启动:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vllm.service
sudo systemctl enable --now vllm-playground.service
```

---

## 8. 从 cu12 旧版本迁移过来

如果你之前装的是 cu12 wheel(典型症状:启动报 `ImportError: libcudart.so.12` 或 `libtorch_cuda.so`),迁移步骤:

```bash
# 1. 卸载 cu12 残留
source ~/.vllm-env/bin/activate
uv pip uninstall vllm torch torchvision torchaudio \
    nvidia-cuda-runtime-cu12 nvidia-cuda-nvrtc-cu12 \
    nvidia-cublas-cu12 nvidia-cudnn-cu12 \
    nvidia-cusparse-cu12 nvidia-cusolver-cu12 \
    nvidia-curand-cu12 nvidia-cufft-cu12 \
    nvidia-nccl-cu12 nvidia-nvtx-cu12 2>/dev/null || true

# 2. 装 cu130 版
uv pip install vllm \
    --torch-backend=auto \
    --extra-index-url https://wheels.vllm.ai/0.19.0/cu130

# 3. 验证 torch.version.cuda 是 13.0
python -c "import torch; print(torch.version.cuda)"
deactivate

# 4. 简化 vllm-start.sh,删掉所有 LD_LIBRARY_PATH 相关行
#    用第 7.5 节那段干净版本覆盖

# 5. 重启服务
sudo systemctl restart vllm.service
sudo journalctl -u vllm.service -f
```

或者直接用一键脚本,它会自动检测到 `torch.version.cuda` 不是 13.x 然后自动重装 cu130 版本:

```bash
bash install_dgx-spark_vllm_vllm-playground.sh
```

---

## 9. 故障排查

| 现象 | 原因 | 处理 |
|---|---|---|
| `ImportError: libcudart.so.12: cannot open shared object file` | 装的是 cu12 wheel,系统是 CUDA 13 | 按第 8 节迁移到 cu130 |
| `ImportError: libtorch_cuda.so: cannot open shared object file` | 同上,torch 是 cu12 版本 | 同上 |
| `vllm serve` 找不到 | venv 没激活 | `source ~/.vllm-env/bin/activate` |
| 启动卡在下载阶段 | 模型在拉,30GB 需要时间 | `journalctl -u vllm.service -f`,或 `du -sh /opt/vllm/hf-cache/hub/models--*` 看进度 |
| 下载慢 | hf-mirror 没生效 | 确认 `vllm.conf` 有 `HF_ENDPOINT=https://hf-mirror.com` 且 `vllm-start.sh` 里 `export HF_ENDPOINT` |
| OOM / KV cache 不够 | `MAX_MODEL_LEN` 太大或 util 太高 | 降 `MAX_MODEL_LEN`(比如 131072 → 65536)或 `GPU_MEMORY_UTILIZATION` 到 0.88 |
| systemd 起不来但手跑可以 | service 里 `Environment=HOME=...` 必须是绝对路径,不能用 `~` | 检查 unit |
| `status=209/STDOUT` | 老版本 systemd unit 里有 `StandardOutput=append:` 但目录不存在 | 删掉那两行,改用 journald(本手册的默认做法) |
| Web UI 连不上 vLLM | 配置错误 | Management → Instances 加 Remote,URL `http://127.0.0.1:8000`,API Key 对齐 |
| 7860 访问不了 | 防火墙 / 端口未对外 | 检查防火墙 / Tailscale,playground 默认监听 `0.0.0.0` |
| sm_121 相关 warning | PyTorch max 列表只到 sm_120 | 预期行为,sm_121 前向兼容 sm_120,忽略 |
| `--torch-backend=auto: unknown option` | uv 版本太老 | 升级 uv,或退回到 fallback 写法(双 extra-index + `unsafe-best-match`) |
| 想看脚本跑过啥 | - | `cat ~/.vllm-install.log` |

### 调试 vllm 启动失败

```bash
# 1. 看完整启动日志
sudo journalctl -u vllm.service -n 100 --no-pager

# 2. 直接手动跑启动脚本(绕过 systemd,看真实报错)
sudo -u unis3 bash ~/.vllm-env/vllm-start.sh

# 3. 验证 cu130 装对了
sudo -u unis3 ~/.vllm-env/bin/python -c "
import torch, vllm
print('vllm:', vllm.__version__)
print('torch.version.cuda:', torch.version.cuda)  # 必须是 13.0
print('torch.cuda.is_available:', torch.cuda.is_available())
"
```

第二种方式经常能看到 systemd 日志里被截断的 Python 堆栈,定位问题最快。
