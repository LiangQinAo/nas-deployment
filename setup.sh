#!/usr/bin/env bash
# =============================================================================
# setup.sh — filebrowser 初始化脚本
#
# 功能：
#   1. 检查依赖（Docker、Docker Compose）
#   2. 检查 .env 配置
#   3. 检查外接硬盘是否已挂载
#   4. 初始化 filebrowser 数据库（管理员账号、中文界面、缩略图等）
#   5. 启动服务并验证健康状态
#
# 用法：bash setup.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---- 确保 OrbStack / Docker Desktop 二进制可被找到 -------------------
export PATH="/opt/homebrew/bin:$HOME/.orbstack/bin:/usr/local/bin:$PATH"

# ---------- 颜色输出 ----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }

# ---------- 检查依赖 ----------------------------------------------------------
info "检查依赖..."

command -v docker >/dev/null 2>&1 || error "未找到 Docker，请先安装 Docker Desktop: https://www.docker.com/products/docker-desktop/"
docker info >/dev/null 2>&1      || error "Docker 未运行，请启动 Docker Desktop"

# 支持新版 'docker compose'（插件）和旧版 'docker-compose'
if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
else
    error "未找到 Docker Compose，请更新 Docker Desktop 到最新版"
fi

success "Docker $(docker --version | awk '{print $3}' | tr -d ',')"
success "Compose ${COMPOSE}"

# ---------- 检查 .env ---------------------------------------------------------
info "检查 .env 配置..."

[[ -f ".env" ]] || error ".env 文件不存在，请先：cp .env.example .env 并修改配置"

# 读取 .env（安全方式：仅读取 key=value 格式，忽略注释和空行）
set -a
# shellcheck disable=SC1091
source .env
set +a

# 检查密码是否已修改
if [[ "${ADMIN_PASSWORD:-}" == "ChangeMe123!@#" ]]; then
    warn "检测到默认密码 'ChangeMe123!@#'，强烈建议在 .env 中修改 ADMIN_PASSWORD"
    read -rp "继续使用默认密码？[y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || error "请修改 .env 中的 ADMIN_PASSWORD 后重新运行"
fi

success ".env 已加载"

# ---------- 检查外接硬盘 -------------------------------------------------------
info "检查外接硬盘挂载..."

DISK1="${DISK1_PATH:-}"

if [[ -z "$DISK1" ]]; then
    warn "DISK1_PATH 未配置，将使用临时目录 /tmp/filebrowser-fallback（仅用于测试）"
    mkdir -p /tmp/filebrowser-fallback
elif [[ ! -d "$DISK1" ]]; then
    error "DISK1_PATH='$DISK1' 目录不存在，请确认外接硬盘已挂载。\n       macOS 硬盘通常挂载在 /Volumes/ 目录下，可通过 'ls /Volumes/' 查看"
else
    success "主硬盘已挂载：$DISK1"
fi

# 检查可选的第二块硬盘
if [[ -n "${DISK2_PATH:-}" ]]; then
    if [[ ! -d "$DISK2_PATH" ]]; then
        warn "DISK2_PATH='$DISK2_PATH' 目录不存在，请确认硬盘已挂载，或注释掉 compose.yaml 中对应的卷挂载"
    else
        success "第二块硬盘已挂载：$DISK2_PATH"
    fi
fi

# ---------- 创建目录 ----------------------------------------------------------
info "创建必要目录..."
mkdir -p config database logs
success "目录就绪"

# ---------- 初始化 filebrowser 数据库（仅首次）---------------------------------
DB_FILE="database/filebrowser.db"

if [[ ! -f "$DB_FILE" ]]; then
    info "首次初始化 filebrowser 数据库..."

    # 初始化数据库（使用标准镜像，binary 在 /bin/filebrowser）
    docker run --rm \
        --entrypoint /bin/filebrowser \
        -v "$SCRIPT_DIR/config:/config" \
        -v "$SCRIPT_DIR/database:/database" \
        filebrowser/filebrowser:latest \
        config init \
            --database /database/filebrowser.db

    # 配置中文、24h token、禁用命令执行
    docker run --rm \
        --entrypoint /bin/filebrowser \
        -v "$SCRIPT_DIR/config:/config" \
        -v "$SCRIPT_DIR/database:/database" \
        filebrowser/filebrowser:latest \
        config set \
            --database /database/filebrowser.db \
            --address 0.0.0.0 \
            --port 80 \
            --root /srv \
            --log stdout \
            --locale zh-cn \
            --tokenExpirationTime 24h \
            --minimumPasswordLength 8

    # 创建管理员账号
    docker run --rm \
        --entrypoint /bin/filebrowser \
        -v "$SCRIPT_DIR/config:/config" \
        -v "$SCRIPT_DIR/database:/database" \
        filebrowser/filebrowser:latest \
        users add \
            "${ADMIN_USERNAME:-admin}" "${ADMIN_PASSWORD:-ChangeMe123}" \
            --perm.admin \
            --database /database/filebrowser.db \
            --locale zh-cn

    success "数据库初始化完成"
else
    info "数据库已存在（$DB_FILE），跳过初始化"
fi

# ---------- 启动服务 ----------------------------------------------------------
info "启动 filebrowser 服务..."
$COMPOSE up -d

# ---------- 等待服务健康 -------------------------------------------------------
info "等待服务就绪（最长 60 秒）..."
for i in $(seq 1 12); do
    if curl -sf "http://127.0.0.1:${PORT:-8888}/health" >/dev/null 2>&1; then
        echo ""
        success "服务已就绪！"
        break
    fi
    printf "."
    sleep 5
    if [[ $i -eq 12 ]]; then
        echo ""
        warn "服务启动超时，请检查日志：make logs"
    fi
done

# ---------- 完成提示 ----------------------------------------------------------
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN} FileBrowser 部署成功！${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
  echo -e "  本地访问:   ${BLUE}http://localhost:${PORT:-8888}${NC}"
echo -e "  用户名:     ${BLUE}${ADMIN_USERNAME:-admin}${NC}"
echo -e "  密码:       ${BLUE}（来自 .env 中的 ADMIN_PASSWORD）${NC}"
echo ""
echo -e "  常用命令（在项目目录运行）:"
echo -e "    make up      — 启动服务"
echo -e "    make down    — 停止服务"
echo -e "    make logs    — 查看日志"
echo -e "    make status  — 查看状态"
echo ""
echo -e "  外网访问（Tailscale）: 见 README 中的 Tailscale 配置章节"
echo ""
