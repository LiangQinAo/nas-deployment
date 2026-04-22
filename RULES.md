# 开发与部署规则 (NAS Media Manager)

为了确保 NAS 媒体管理器的功能能够正确更新并保持稳定，所有后续开发必须遵守以下规则：

## 1. 部署流程 (Deployment Pipeline)
必须通过根目录的 `deploy.sh` 脚本进行部署。该脚本已自动化以下关键步骤：
- **版本更新**: 自动生成 `version.txt` (格式: YYYYMMDDHHMMSS)。
- **前端编译**: 进入 `filebrowser-dev/frontend` 执行 `pnpm build`。这步至关重要，因为前端代码会被嵌入到 Go 二进制中。
- **后端编译**: 执行 `go build` 生成 `filebrowser-native`。
- **配置对齐**: 自动设置数据库中的 `root` 路径、端口以及 `hideDotfiles=true`。

## 2. 功能验证 (Post-Deployment Verification)
每次部署完成后，必须检查：
- **版本页面**: 访问 `/version` 确认构建时间已更新。如果未更新，说明前端编译或嵌入失败。
- **API 接口**: 确认 `/api/version` 返回正确的纯文本时间戳。

## 3. 图片预览 (Photo Viewer)
- **技术栈**: 使用 `PhotoSwipe v5`。
- **交互标准**: 必须提供类似 iOS 相册的流畅体验（支持双指缩放、弹性物理效果、顺滑的滑动切换）。
- **元数据**: 单个图片查看时，需确保 `EXIF` 接口返回的数据在“文件信息”弹窗中可见。

## 4. 环境要求
- **构建环境**: macOS Native (Native arm64)，支持 `sips` 工具。
- **代理设置**: 构建命令中由于涉及 `pnpm` 或 `go mod`，必须包含代理设置（当前为 `127.0.0.1:1087`）。

## 5. 隐藏文件策略
- 全局默认隐藏点文件 (`.`)。已在 `deploy.sh` 中通过 `config set --hideDotfiles=true` 强制执行。
