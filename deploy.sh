#!/bin/bash

# =============================================================================
# deploy.sh — FileBrowser 一键部署与更新脚本 (macOS Native)
# =============================================================================

# 0. 更新版本信息
date +%Y%m%d%H%M%S > version.txt
echo "--- Build Version: $(cat version.txt) ---"

# 1. 加载环境变量
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "错误: 未找到 .env 文件，请参考 .env.example 创建。"
    exit 1
fi

# 确保 Go 和系统工具在 PATH 中
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# 确保必要的目录存在
mkdir -p ./database ./config ./cache/raw_previews

# 2. 编译前端
echo "--- 正在编译前端 (Vue 3) ---"
cd filebrowser-dev/frontend
export PATH="/opt/homebrew/bin:$PATH"
export http_proxy=http://127.0.0.1:1087
export https_proxy=http://127.0.0.1:1087
# 使用 pnpm 构建
pnpm build
if [ $? -ne 0 ]; then
    echo "前端构建失败！"
    exit 1
fi
cd ../..

# 3. 编译后端
echo "--- 正在编译后端 (Native arm64) ---"
cd filebrowser-dev
export http_proxy=http://127.0.0.1:1087
export https_proxy=http://127.0.0.1:1087
export ALL_PROXY=socks5://127.0.0.1:1080
go build -o ../filebrowser-native .
if [ $? -ne 0 ]; then
    echo "后端编译失败！"
    exit 1
fi
cd ..

# 3. 停止旧进程
echo "--- 正在停止旧进程 ---"
pkill -f "./filebrowser-native" || true

# 4. 数据库对齐 (确保 DB 内的 root 和 scope 与 native 环境一致)
echo "--- 正在对齐数据库路径 ---"
./filebrowser-native config set --root "${DISK1_PATH}" --hideDotfiles=true -d ./database/filebrowser.db
./filebrowser-native users update admin --scope "/" --hideDotfiles=true -d ./database/filebrowser.db

# 5. 启动新进程
echo "--- 正在启动服务 (Port: ${PORT:-8888}) ---"
# 设置环境变量，FileBrowser 会自动读取以 FB_ 开头的变量
export FB_DATABASE="./database/filebrowser.db"
export FB_ROOT="${DISK1_PATH}"
export FB_PORT="${PORT:-8888}"
export FB_ADDRESS="0.0.0.0"
export FB_LOG="stdout"

# 使用 nohup 后台运行
nohup ./filebrowser-native > filebrowser.log 2>&1 &


echo "-------------------------------------------------------"
echo "部署完成！"
echo "服务地址: http://localhost:${PORT:-8888}"
echo "实时日志: tail -f filebrowser.log"
echo "-------------------------------------------------------"
