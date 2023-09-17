#!/bin/bash

# GitHub 仓库所有者和仓库名称
OWNER="ClementTsang"
REPO="bottom"

# GitHub Release 页面 URL
RELEASES_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"

# 获取最新 Release 的信息
release_info=$(curl -sSL "${RELEASES_URL}")

# 提取最新 Release 的 tag_name（版本号）
tag_name=$(echo "$release_info" | grep -o '"tag_name": "[^"]*' | sed 's/"tag_name": "//')

if [ -z "${tag_name}" ]; then
  echo "获取到的 tag_name 为空，无法下载，release_info: ${release_info}"
  exit 1
fi

# 构建文件下载 URL
file_url="https://github.com/${OWNER}/${REPO}/releases/latest/download/bottom_${tag_name}_amd64.deb"

# 下载文件到当前目录
curl -sLJO "${file_url}"

echo "已下载最新版本的 bottom_${tag_name}_amd64.deb 文件，版本号：$tag_name"

dpkg -i "bottom_${tag_name}_amd64.deb"
