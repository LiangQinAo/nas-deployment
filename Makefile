# =============================================================================
# Makefile — filebrowser 常用命令封装
# 用法：make <target>，例如 make up
# =============================================================================

.PHONY: setup up down restart logs status shell reset-password add-disk \
        dev-clone dev-backend dev-frontend help

# 确保 OrbStack / Docker Desktop 的 docker 二进制可被 make 找到
export PATH := /opt/homebrew/bin:$(HOME)/.orbstack/bin:/usr/local/bin:$(PATH)

# 自动选择 docker compose 或 docker-compose
COMPOSE := $(shell docker compose version >/dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

# 读取 .env 中的端口（默认 8080）
PORT ?= $(shell grep -E '^PORT=' .env 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo 8080)

# ============================================================
# 部署管理
# ============================================================

## setup   : 首次部署（检查依赖、初始化数据库、启动服务）
setup:
	@bash setup.sh

## deploy  : (推荐) 执行原生 macOS 一键部署与更新
deploy:
	@chmod +x deploy.sh
	@./deploy.sh

## up      : (Docker) 启动服务（后台运行）
up:
	@$(COMPOSE) up -d
	@echo "服务已启动：http://localhost:$(PORT)"

## down    : 停止并移除容器（数据保留）
down:
	@$(COMPOSE) down

## restart : 重启服务
restart:
	@$(COMPOSE) restart filebrowser

## pull    : 拉取最新镜像并重启
pull:
	@$(COMPOSE) pull
	@$(COMPOSE) up -d

# ============================================================
# Sidecar 微服务管理
# ============================================================

## sidecar-build : 编译 RAW 转换微服务
sidecar-build:
	@echo "编译 RAW 转换服务..."
	@cd raw-converter && go build -o raw-converter .

## sidecar-start : 在后台启动 RAW 转换服务
sidecar-start: sidecar-build
	@echo "启动 RAW 转换微服务..."
	@cd raw-converter && source ../.env && nohup ./raw-converter > convert.log 2>&1 &
	@echo "服务已在后台启动 (日志: raw-converter/convert.log)"

## sidecar-stop  : 停止 RAW 转换服务
sidecar-stop:
	@pkill -f "./raw-converter" || echo "微服务未运行"

# ============================================================
# 监控与调试
# ============================================================

## logs    : 实时查看日志（Ctrl+C 退出）
logs:
	@$(COMPOSE) logs -f filebrowser

## status  : 查看容器状态和健康检查
status:
	@$(COMPOSE) ps
	@echo ""
	@echo "健康检查："
	@curl -sf http://localhost:$(PORT)/health && echo "✓ 服务正常" || echo "✗ 服务异常"

## shell   : 进入容器 Shell（调试用）
shell:
	@$(COMPOSE) exec filebrowser /bin/sh

# ============================================================
# 用户管理（在容器内执行 filebrowser CLI）
# ============================================================

## reset-password : 重置管理员密码（交互式输入）
reset-password:
	@read -p "管理员用户名 [admin]: " username; \
	 username=$${username:-admin}; \
	 read -sp "新密码: " password; echo ""; \
	 $(COMPOSE) exec filebrowser /filebrowser users update "$$username" \
	   --password "$$password" \
	   --database /database/filebrowser.db; \
	 echo "密码已更新"

## list-users : 列出所有用户
list-users:
	@$(COMPOSE) exec filebrowser /filebrowser users ls \
	  --database /database/filebrowser.db

# ============================================================
# 磁盘管理
# ============================================================

## add-disk : 提示如何挂载新硬盘
add-disk:
	@echo "挂载新硬盘步骤："
	@echo "1. 确认硬盘路径：ls /Volumes/"
	@echo "2. 在 .env 中设置 DISK2_PATH=/Volumes/<名称>"
	@echo "3. 在 compose.yaml 中取消注释第二块硬盘的卷挂载"
	@echo "4. 运行 make restart"

## disk-usage : 查看各挂载目录的磁盘使用情况
disk-usage:
	@$(COMPOSE) exec filebrowser df -h /srv/

# ============================================================
# 二次开发
# ============================================================

## dev-clone : 克隆 filebrowser 源码到 filebrowser-dev/ 目录
dev-clone:
	@if [ -d "filebrowser-dev" ]; then \
	  echo "filebrowser-dev/ 已存在，跳过克隆"; \
	else \
	  echo "正在克隆 filebrowser 源码..."; \
	  git clone https://github.com/filebrowser/filebrowser.git filebrowser-dev; \
	  echo "克隆完成：filebrowser-dev/"; \
	  echo ""; \
	  echo "后续步骤："; \
	  echo "  cd filebrowser-dev"; \
	  echo "  go mod download          # 下载 Go 依赖"; \
	  echo "  cd frontend && pnpm i    # 安装前端依赖"; \
	  echo "  pnpm run dev             # 启动前端开发服务器"; \
	fi

## dev-backend : 在本地运行 filebrowser 后端（需先 make dev-clone）
dev-backend:
	@cd filebrowser-dev && \
	  go run . \
	    -r "$(shell grep DISK1_PATH .env | cut -d= -f2 | tr -d ' ')" \
	    -a 127.0.0.1 \
	    -p 8090 \
	    -d ./dev.db

## dev-frontend : 在本地运行前端开发服务器（需先 make dev-clone）
dev-frontend:
	@cd filebrowser-dev/frontend && pnpm run dev

# ============================================================
# 帮助
# ============================================================

## help    : 显示所有可用命令
help:
	@echo ""
	@echo "FileBrowser 管理命令："
	@echo ""
	@grep -E '^## ' Makefile | sed 's/## /  make /g'
	@echo ""

.DEFAULT_GOAL := help
