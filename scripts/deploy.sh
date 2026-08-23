#!/bin/bash
#
# deploy.sh — 服务器本地构建并部署
#
# 用法：
#   bash scripts/deploy.sh              # 使用 VERSION 文件的版本号
#   IMAGE_TAG=v1.0.1 bash scripts/deploy.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

if [ -n "${IMAGE_TAG:-}" ]; then
    VERSION="${IMAGE_TAG}"
elif [ -f package.json ] && command -v node >/dev/null 2>&1; then
    VERSION="v$(node -p "require('./package.json').version")"
elif [ -f VERSION ]; then
    VERSION=$(tr -d '[:space:]' < VERSION)
else
    VERSION="latest"
fi

if [ -z "$VERSION" ]; then
    VERSION="latest"
fi

IMAGE_NAME="ai-conding-github:${VERSION}"

echo "========================================"
echo "  本地构建: ${IMAGE_NAME}"
echo "========================================"

if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo "⚠️  .env 不存在，从 .env.example 复制..."
        cp .env.example .env
    else
        echo "❌ .env 不存在，请先创建 .env"
        exit 1
    fi
fi

echo "🔨 构建镜像..."
docker build -t "${IMAGE_NAME}" .

export IMAGE_TAG="${VERSION}"

echo ""
echo "🚀 启动容器..."
docker compose -f docker-compose.prod.yml up -d

echo ""
echo "========================================"
echo "  部署完成: ${IMAGE_NAME}"
echo "========================================"
docker compose -f docker-compose.prod.yml ps
