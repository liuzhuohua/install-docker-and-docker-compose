#!/bin/bash
# Debian 13 一键安装 Docker 和 Docker Compose 脚本
# 作者：ajeef | 适用系统：Debian 13 (理论向下兼容)
# 功能：自动安装 Docker Engine、Docker Compose 插件、添加用户到 docker 组，并验证安装

set -euo pipefail  # 严格模式：任何错误立即退出

# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[*]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[X]${NC} $1" >&2
    exit 1
}

# 检查是否以 root 权限运行
if [[ $EUID -ne 0 ]]; then
    error "此脚本必须以 root 权限运行，请使用 sudo 执行。"
fi

# 检查系统是否为 Debian 13
if ! grep -q "Debian GNU/Linux 13" /etc/os-release; then
    warn "检测到系统非 Debian 13，但继续尝试安装（可能不兼容）..."
fi

# 更新系统包列表
log "正在更新系统包列表..."
apt-get update

# 安装基础依赖
log "安装必要的依赖包：ca-certificates, curl, gnupg, lsb-release..."
apt-get install -y ca-certificates curl gnupg lsb-release

# 添加 Docker 官方 GPG 密钥
log "添加 Docker 官方 GPG 密钥..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 添加 Docker APT 仓库（使用 Debian 13 对应的 codename: bookworm）
log "添加 Docker 仓库（Debian Bookworm）..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 再次更新包列表
log "更新 APT 包索引..."
apt-get update

# 安装 Docker Engine
log "正在安装 Docker Engine..."
apt-get install -y docker-ce docker-ce-cli containerd.io

# 启动并启用 Docker 服务
log "启动并设置 Docker 开机自启..."
systemctl enable --now docker

# 检查 Docker 是否安装成功
if ! command -v docker &> /dev/null; then
    error "Docker 安装失败，请检查网络或手动执行：apt-get install docker-ce"
fi

# 安装 Docker Compose V2（官方推荐方式，作为插件）
log "安装 Docker Compose V2（插件模式）..."
mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# 验证 Docker Compose 安装
if ! docker compose version &> /dev/null; then
    error "Docker Compose 安装失败，请检查网络或手动下载：https://github.com/docker/compose/releases"
fi

# 添加当前登录用户（非 root）到 docker 组（推荐操作）
# 尝试获取非 root 的第一个普通用户
USER_TO_ADD=""
for u in $(getent passwd {1000..60000} | cut -d: -f1); do
    if [ -d "/home/$u" ]; then
        USER_TO_ADD=$u
        break
    fi
done

if [ -n "$USER_TO_ADD" ]; then
    log "将用户 '$USER_TO_ADD' 添加到 docker 组，避免每次使用 sudo..."
    usermod -aG docker "$USER_TO_ADD"
    log "请注销并重新登录，或执行：newgrp docker 以立即生效。"
else
    warn "未检测到非 root 用户，跳过用户组配置。"
fi

# 验证安装
log "正在验证 Docker 和 Docker Compose 安装..."
docker --version
docker compose version

# 运行测试容器
log "运行测试容器：hello-world..."
docker run --rm hello-world

# 成功提示
echo -e "\n${GREEN}🎉 安装完成！🎉${NC}"
echo -e "${GREEN}✅ Docker 和 Docker Compose 已成功安装。${NC}"
echo -e "${YELLOW}💡 建议：重启终端或执行 'newgrp docker' 以无需 sudo 使用 docker 命令。${NC}"
