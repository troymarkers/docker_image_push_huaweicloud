#!/usr/bin/env bash
set -uo pipefail

# 登录华为云 SWR
echo "Logging in to Huawei Cloud SWR..."
echo "$HUAWEICLOUD_PASSWORD" | docker login -u "$HUAWEICLOUD_USER" --password-stdin "$HUAWEICLOUD_REGISTRY"

echo "Reading images from images.txt..."

while read -r line || [[ -n "$line" ]]; do
  # 跳过空行和注释行
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

  # 去掉行尾注释（# 前面有空格的情况）
  line="${line%%#*}"

  # 解析格式：image:tag [arch]
  # arch 可选，不写默认 amd64
  # arch 简写如 arm64 会自动补全为 linux/arm64
  rest="$line"
  img_tag="${rest%% *}"
  arch_raw="${rest#"$img_tag"}"
  arch_raw="${arch_raw## }"

  # 解析 image:tag（无冒号则默认 latest）
  if [[ "$img_tag" == *:* ]]; then
    image="${img_tag%:*}"
    tag="${img_tag##*:}"
  else
    image="$img_tag"
    tag="latest"
  fi

  # 处理架构：未指定默认 amd64，简写自动补 linux/ 前缀
  arch_specified="true"
  if [[ -z "$arch_raw" ]]; then
    arch_raw="amd64"
    arch_specified="false"
  fi
  if [[ "$arch_raw" != */* ]]; then
    platform="linux/$arch_raw"
  else
    platform="$arch_raw"
  fi

  # 标准化镜像名称
  clean_image=$(sed 's/@sha256.*//; s/[^a-zA-Z0-9._/-]//g' <<< "$image")

  full_image="$image:$tag"

  echo "============================================"
  echo "Image: $image  |  Tag: $tag  |  Arch: $arch_raw"

  # 生成 SWR 目标路径：registry/org/namespace/repo
  if [[ "$clean_image" =~ ^([^/]+)/(.+)$ ]]; then
    hw_image="$HUAWEICLOUD_REGISTRY/$HUAWEICLOUD_ORG_NAME/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  else
    hw_image="$HUAWEICLOUD_REGISTRY/$HUAWEICLOUD_ORG_NAME/$clean_image"
  fi
  echo "Target: $hw_image"

  # 拉取指定架构镜像
  echo "  Pulling $full_image for $platform..."
  docker pull --platform "$platform" "$full_image"

  if [[ "$arch_specified" == "true" && "$arch_raw" != "amd64" ]]; then
    # 显式指定非 amd64 架构：推送架构标签 + 通用标签
    arch_tag="${tag}-${arch_raw}"
    echo "  Tagging ${hw_image}:${arch_tag} ..."
    docker tag "$full_image" "${hw_image}:${arch_tag}"
    echo "  Pushing ${hw_image}:${arch_tag} ..."
    docker push "${hw_image}:${arch_tag}"

    echo "  Tagging ${hw_image}:${tag} ..."
    docker tag "$full_image" "${hw_image}:${tag}"
    echo "  Pushing ${hw_image}:${tag} ..."
    docker push "${hw_image}:${tag}"
  else
    # 未指定架构或指定 amd64：仅推送带 amd64 架构后缀的标签
    echo "  Tagging ${hw_image}:${tag}-amd64 ..."
    docker tag "$full_image" "${hw_image}:${tag}-amd64"
    echo "  Pushing ${hw_image}:${tag}-amd64 ..."
    docker push "${hw_image}:${tag}-amd64"
  fi

  # 清理
  docker rmi "$full_image" || true
  echo ""
done < images.txt

echo "Performing global cleanup..."
docker image prune -f

# 立即清除登录凭据
docker logout "$HUAWEICLOUD_REGISTRY" || true
rm -f /home/runner/.docker/config.json || true
