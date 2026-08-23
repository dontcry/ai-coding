#!/bin/bash
#
# deploy.sh — 生产环境一键发布
# 从 CNB 制品库拉取镜像并启动容器
#
# 用法：
#   bash scripts/deploy.sh              # 使用 .env 中的 IMAGE_TAG，或 VERSION 文件
#   IMAGE_TAG=v1.0.0 bash scripts/deploy.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

IMAGE_REGISTRY="${IMAGE_REGISTRY:-docker.cnb.cool/ocean-data/dontcry/ai-coding}"

if [ -n "${IMAGE_TAG:-}" ]; then
    VERSION="${IMAGE_TAG}"
elif [ -f VERSION ]; then
    VERSION=$(tr -d '[:space:]' < VERSION)
else
    VERSION="latest"
fi

if [ -z "$VERSION" ]; then
    VERSION="latest"
fi

echo "========================================"
echo "  部署镜像: ${IMAGE_REGISTRY}:${VERSION}"
echo "========================================"
echo ""

if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo "⚠️  .env 不存在，从 .env.example 复制..."
        cp .env.example .env
    else
        echo "❌ .env 不存在，请先创建 .env"
        exit 1
    fi
fi

if grep -q "^IMAGE_TAG=" .env; then
    sed -i "s|^IMAGE_TAG=.*|IMAGE_TAG=${VERSION}|" .env
else
    echo "IMAGE_TAG=${VERSION}" >> .env
fi

# 移除历史回退遗留的 IMAGE_REGISTRY 配置
sed -i '/^IMAGE_REGISTRY=/d' .env 2>/dev/null || true
echo "✅ 已更新 .env: IMAGE_TAG=${VERSION}"

if ! grep -q '"docker.cnb.cool"' ~/.docker/config.json 2>/dev/null; then
    if [ -n "${CNB_TOKEN:-}" ]; then
        echo "🔐 登录 docker.cnb.cool ..."
        echo "${CNB_TOKEN}" | docker login docker.cnb.cool -u cnb --password-stdin
    else
        echo "❌ 未登录 docker.cnb.cool，请先执行："
        echo "  docker login docker.cnb.cool -u cnb -p <CNB_TOKEN>"
        echo "或在 .env 中设置 CNB_TOKEN=..."
        exit 1
    fi
fi

echo "📦 拉取镜像 ${IMAGE_REGISTRY}:${VERSION} ..."
if ! PULL_ERR=$(docker pull "${IMAGE_REGISTRY}:${VERSION}" 2>&1); then
    echo "$PULL_ERR"
    echo ""
    echo "❌ 镜像拉取失败: ${IMAGE_REGISTRY}:${VERSION}"
    if echo "$PULL_ERR" | grep -q 'unauthorized'; then
        echo ""
        echo "当前已 docker login，但令牌可能没有该制品包的 pull 权限。"
        echo "请在 CNB 控制台处理："
        echo "  1. 设置 → 访问令牌 → 新建令牌，勾选「制品库」读权限"
        echo "  2. 使用范围选择本仓库"
        echo "  3. 重新登录: docker login docker.cnb.cool -u cnb -p <新令牌>"
    else
        echo "  请确认 CNB 流水线已成功推送该版本标签"
    fi
    exit 1
fi

export IMAGE_TAG="${VERSION}"

echo ""
echo "🚀 启动容器..."
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

echo ""
echo "========================================"
echo "  部署完成: ${IMAGE_REGISTRY}:${VERSION}"
echo "========================================"
docker compose -f docker-compose.prod.yml ps
