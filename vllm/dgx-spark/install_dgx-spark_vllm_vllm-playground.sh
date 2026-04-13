#!/usr/bin/env bash
#
# DGX Spark: vLLM + vllm-playground 一键安装 / 幂等修复脚本
#
# 用法:
#   bash install.sh            # 正常安装,跳过已完成的步骤
#   bash install.sh --force    # 强制重装两个 venv
#   bash install.sh --status   # 只检查当前状态,不做任何改动
#

set -euo pipefail

# ==================== 配置 ====================
RUN_USER="${SUDO_USER:-$USER}"
RUN_HOME="$(getent passwd "${RUN_USER}" | cut -d: -f6)"
RUN_GROUP="$(id -gn "${RUN_USER}")"

VLLM_VENV="${RUN_HOME}/.vllm-env"
PLAYGROUND_VENV="${RUN_HOME}/.vllm-playground-env"

OPT_DIR="/opt/vllm"
LOG_DIR="${OPT_DIR}/logs"
HF_CACHE="${OPT_DIR}/hf-cache"

VLLM_CONF="${VLLM_VENV}/vllm.conf"
VLLM_START="${VLLM_VENV}/vllm-start.sh"

VLLM_UNIT="/etc/systemd/system/vllm.service"
PG_UNIT="/etc/systemd/system/vllm-playground.service"

PLAYGROUND_PORT=7860

# 安装日志(每次跑都追加)
INSTALL_LOG="${RUN_HOME}/.vllm-install.log"

# 默认模型(首次创建 vllm.conf 时用,之后不会覆盖)
DEFAULT_MODEL="Qwen/Qwen3-14B-FP8"
DEFAULT_SERVED_NAME="qwen3-14b"

# 国内 PyPI 镜像(留空则用默认源)
PYPI_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"

# ==================== 颜色输出 ====================
if [[ -t 1 ]]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'
    C_BLU=$'\033[34m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_DIM=""; C_RST=""
fi

log()   { local m="[*] $*"; echo "${C_BLU}[*]${C_RST} $*"; echo "$(date '+%F %T') ${m}" >> "${INSTALL_LOG}"; }
ok()    { local m="[✓] $*"; echo "${C_GRN}[✓]${C_RST} $*"; echo "$(date '+%F %T') ${m}" >> "${INSTALL_LOG}"; }
skip()  { local m="[-] $* (已就绪,跳过)"; echo "${C_DIM}${m}${C_RST}"; echo "$(date '+%F %T') ${m}" >> "${INSTALL_LOG}"; }
warn()  { local m="[!] $*"; echo "${C_YLW}[!]${C_RST} $*"; echo "$(date '+%F %T') ${m}" >> "${INSTALL_LOG}"; }
err()   { local m="[✗] $*"; echo "${C_RED}[✗]${C_RST} $*" >&2; echo "$(date '+%F %T') ${m}" >> "${INSTALL_LOG}"; }

# ==================== 参数解析 ====================
FORCE=0
STATUS_ONLY=0
for arg in "$@"; do
    case "${arg}" in
        --force)   FORCE=1 ;;
        --status)  STATUS_ONLY=1 ;;
        -h|--help)
            sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) err "未知参数: ${arg}"; exit 1 ;;
    esac
done

# ==================== 需要 root 时自动 sudo ====================
need_sudo() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# ==================== 步骤 ====================

print_header() {
    echo
    echo "=================================================="
    echo " DGX Spark: vLLM + vllm-playground 安装"
    echo "=================================================="
    echo " 用户:          ${RUN_USER}  (home: ${RUN_HOME})"
    echo " vLLM venv:     ${VLLM_VENV}"
    echo " Playground:    ${PLAYGROUND_VENV}"
    echo " 日志:          ${LOG_DIR}"
    echo " HF cache:      ${HF_CACHE}"
    if [[ ${FORCE} -eq 1 ]]; then
        echo " 模式:          ${C_YLW}--force(强制重装 venv)${C_RST}"
    fi
    if [[ ${STATUS_ONLY} -eq 1 ]]; then
        echo " 模式:          ${C_YLW}--status(只检查,不修改)${C_RST}"
    fi
    echo "=================================================="
    echo
}

check_prereqs() {
    log "检查前置依赖"

    local missing=()
    for cmd in nvidia-smi curl python3.12; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing+=("${cmd}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        err "缺少命令: ${missing[*]}"
        err "请先安装再跑这个脚本"
        exit 1
    fi
    ok "nvidia-smi / curl / python3.12 都在"

    # uv
    if ! command -v uv >/dev/null 2>&1 && [[ ! -x "${RUN_HOME}/.local/bin/uv" ]]; then
        if [[ ${STATUS_ONLY} -eq 1 ]]; then
            warn "uv 未安装"
            return
        fi
        log "安装 uv"
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi

    # 确保 uv 在 PATH(从 ~/.local/bin 取)
    export PATH="${RUN_HOME}/.local/bin:${PATH}"
    if ! command -v uv >/dev/null 2>&1; then
        err "uv 安装后仍不可用,检查 PATH"
        exit 1
    fi
    ok "uv: $(uv --version)"
}

ensure_opt_dirs() {
    log "确保 ${OPT_DIR} 目录存在"
    if [[ -d "${LOG_DIR}" && -d "${HF_CACHE}" ]]; then
        local owner
        owner="$(stat -c '%U' "${OPT_DIR}")"
        if [[ "${owner}" == "${RUN_USER}" ]]; then
            skip "${OPT_DIR}"
            return
        fi
    fi

    [[ ${STATUS_ONLY} -eq 1 ]] && { warn "${OPT_DIR} 未就绪"; return; }

    need_sudo mkdir -p "${LOG_DIR}" "${HF_CACHE}"
    need_sudo chown -R "${RUN_USER}:${RUN_GROUP}" "${OPT_DIR}"
    ok "${OPT_DIR} 就绪"
}

venv_has_package() {
    local venv="$1" pkg="$2"
    [[ -x "${venv}/bin/python" ]] || return 1
    "${venv}/bin/python" -c "import importlib.metadata, sys; \
        sys.exit(0 if importlib.metadata.distribution('${pkg}') else 1)" 2>/dev/null
}

uv_pip_install() {
    local venv="$1"; shift
    local args=()
    if [[ -n "${PYPI_MIRROR}" ]]; then
        args+=(--index-url "${PYPI_MIRROR}")
    fi
    # 同时输出到终端和日志
    VIRTUAL_ENV="${venv}" uv pip install "${args[@]}" "$@" 2>&1 | tee -a "${INSTALL_LOG}"
    return "${PIPESTATUS[0]}"
}

install_venv() {
    local venv="$1" pkg="$2" label="$3"

    log "检查 ${label} (${venv})"

    if [[ ${FORCE} -eq 1 && -d "${venv}" ]]; then
        warn "--force 模式,删除旧 venv: ${venv}"
        rm -rf "${venv}"
    fi

    if venv_has_package "${venv}" "${pkg}"; then
        local ver
        ver="$("${venv}/bin/python" -c "import importlib.metadata; print(importlib.metadata.version('${pkg}'))")"
        skip "${label} 已安装 (${pkg} ${ver})"
        return
    fi

    [[ ${STATUS_ONLY} -eq 1 ]] && { warn "${label} 未安装"; return; }

    if [[ ! -d "${venv}" ]]; then
        log "创建 venv: ${venv}"
        uv venv --python 3.12 "${venv}"
    fi

    log "安装 ${pkg} 到 ${venv}(可能需要几分钟)"
    uv_pip_install "${venv}" "${pkg}"

    ok "${label} 安装完成"
}

write_vllm_conf() {
    if [[ -f "${VLLM_CONF}" ]]; then
        skip "${VLLM_CONF}(已存在,不覆盖)"
        return
    fi

    [[ ${STATUS_ONLY} -eq 1 ]] && { warn "${VLLM_CONF} 未创建"; return; }

    log "创建 ${VLLM_CONF}"
    cat > "${VLLM_CONF}" <<EOF
# ---- 模型 ----
VLLM_MODEL=${DEFAULT_MODEL}
SERVED_MODEL_NAME=${DEFAULT_SERVED_NAME}

# ---- 监听 ----
VLLM_HOST=0.0.0.0
VLLM_PORT=8000

# ---- 运行参数 ----
MAX_MODEL_LEN=32768
GPU_MEMORY_UTILIZATION=0.90

# 额外 flag,空格分隔
EXTRA_FLAGS=""

# ---- 鉴权(可选)----
VLLM_API_KEY=

# ---- HF ----
HF_TOKEN=
HF_HOME=${HF_CACHE}
HF_ENDPOINT=https://hf-mirror.com
EOF
    chmod 600 "${VLLM_CONF}"
    ok "${VLLM_CONF}"
}

write_vllm_start() {
    if [[ -x "${VLLM_START}" ]]; then
        skip "${VLLM_START}"
        return
    fi

    [[ ${STATUS_ONLY} -eq 1 ]] && { warn "${VLLM_START} 未创建"; return; }

    log "创建 ${VLLM_START}"
    cat > "${VLLM_START}" <<'EOF'
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
    chmod +x "${VLLM_START}"
    ok "${VLLM_START}"
}

write_systemd_unit() {
    local unit_path="$1" content="$2" label="$3"

    if [[ -f "${unit_path}" ]]; then
        if diff -q <(echo "${content}") "${unit_path}" >/dev/null 2>&1; then
            skip "${label}"
            return 1
        fi
        warn "${unit_path} 内容变化,覆盖"
    fi

    [[ ${STATUS_ONLY} -eq 1 ]] && { warn "${unit_path} 需要更新"; return 1; }

    log "写入 ${unit_path}"
    echo "${content}" | need_sudo tee "${unit_path}" >/dev/null
    ok "${label}"
    return 0
}

setup_systemd() {
    local vllm_unit_content pg_unit_content changed=0

    vllm_unit_content="[Unit]
Description=vLLM OpenAI-compatible server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RUN_USER}
Group=${RUN_GROUP}
Environment=HOME=${RUN_HOME}
TimeoutStartSec=1800
Restart=on-failure
RestartSec=10
ExecStart=${VLLM_START}
StandardOutput=append:${LOG_DIR}/vllm.log
StandardError=append:${LOG_DIR}/vllm.err.log
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target"

    pg_unit_content="[Unit]
Description=vLLM Playground Web UI
After=network-online.target vllm.service
Wants=network-online.target

[Service]
Type=simple
User=${RUN_USER}
Group=${RUN_GROUP}
Environment=HOME=${RUN_HOME}
Restart=on-failure
RestartSec=10
ExecStart=/bin/bash -lc 'source ${PLAYGROUND_VENV}/bin/activate && exec vllm-playground --port ${PLAYGROUND_PORT}'
StandardOutput=append:${LOG_DIR}/playground.log
StandardError=append:${LOG_DIR}/playground.err.log

[Install]
WantedBy=multi-user.target"

    if write_systemd_unit "${VLLM_UNIT}" "${vllm_unit_content}" "vllm.service"; then
        changed=1
    fi
    if write_systemd_unit "${PG_UNIT}" "${pg_unit_content}" "vllm-playground.service"; then
        changed=1
    fi

    if [[ ${STATUS_ONLY} -eq 1 ]]; then
        return
    fi

    if [[ ${changed} -eq 1 ]]; then
        log "systemctl daemon-reload"
        need_sudo systemctl daemon-reload
    fi

    for svc in vllm.service vllm-playground.service; do
        if ! need_sudo systemctl is-enabled "${svc}" >/dev/null 2>&1; then
            log "enable ${svc}"
            need_sudo systemctl enable "${svc}"
        else
            skip "${svc} 已 enable"
        fi
    done
}

print_summary() {
    echo
    echo "=================================================="
    echo " 状态汇总"
    echo "=================================================="

    # vllm
    if venv_has_package "${VLLM_VENV}" "vllm"; then
        local v
        v="$("${VLLM_VENV}/bin/python" -c "import vllm; print(vllm.__version__)" 2>/dev/null || echo '?')"
        ok "vllm ${v}  @ ${VLLM_VENV}"
    else
        err "vllm 未安装"
    fi

    # vllm-playground
    if venv_has_package "${PLAYGROUND_VENV}" "vllm-playground"; then
        local v
        v="$("${PLAYGROUND_VENV}/bin/python" -c "import importlib.metadata; print(importlib.metadata.version('vllm-playground'))" 2>/dev/null || echo '?')"
        ok "vllm-playground ${v}  @ ${PLAYGROUND_VENV}"
    else
        err "vllm-playground 未安装"
    fi

    # 配置文件
    [[ -f "${VLLM_CONF}"  ]] && ok "${VLLM_CONF}"  || err "${VLLM_CONF} 缺失"
    [[ -x "${VLLM_START}" ]] && ok "${VLLM_START}" || err "${VLLM_START} 缺失"

    # systemd
    for svc in vllm.service vllm-playground.service; do
        if [[ -f "/etc/systemd/system/${svc}" ]]; then
            local state
            state="$(systemctl is-active "${svc}" 2>/dev/null || echo 'inactive')"
            local enabled
            enabled="$(systemctl is-enabled "${svc}" 2>/dev/null || echo 'disabled')"
            ok "${svc}: ${state} / ${enabled}"
        else
            err "${svc} 未创建"
        fi
    done

    echo "=================================================="

    if [[ ${STATUS_ONLY} -eq 0 ]]; then
        echo
        echo "下一步:"
        echo "  1. 按需调整模型:  vi ${VLLM_CONF}"
        echo "  2. 启动服务:      sudo systemctl start vllm.service vllm-playground.service"
        echo "  3. 看日志:        sudo journalctl -u vllm.service -f"
        echo "  4. 访问 Web UI:   http://<本机IP>:${PLAYGROUND_PORT}"
        echo
    fi
}

# ==================== 主流程 ====================
# 初始化日志文件
mkdir -p "$(dirname "${INSTALL_LOG}")"
{
    echo
    echo "================================================================"
    echo " 安装日志开始: $(date '+%F %T')"
    echo " 用户: ${RUN_USER}  参数: $*"
    echo "================================================================"
} >> "${INSTALL_LOG}"

print_header
check_prereqs
ensure_opt_dirs
install_venv "${VLLM_VENV}"       "vllm"            "vLLM"
install_venv "${PLAYGROUND_VENV}" "vllm-playground" "vllm-playground"
write_vllm_conf
write_vllm_start
setup_systemd
print_summary

echo
echo "${C_DIM}完整安装日志: ${INSTALL_LOG}${C_RST}"
