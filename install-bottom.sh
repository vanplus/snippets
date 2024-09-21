#!/usr/bin/env bash -e

# GitHub 仓库所有者和仓库名称
OWNER="ClementTsang"
REPO="bottom"
MANUAL_INSTALL_DIR="/usr/local/bin/"

# GitHub Release 页面 URL
RELEASES_URL="https://github.com/$OWNER/$REPO/releases/latest"
FILE_URL_PREFIX="https://github.com/$OWNER/$REPO/releases/latest/download/"

# 确定最新的 release 页面
latest_release_url=$(curl --http1.1 -sI $RELEASES_URL | grep -i location | awk '{print $2}' | tr -d '\r')

# 提取版本号
tag_name=$(echo $latest_release_url | grep -oP "tag/\K(.*)")

check_libc() {
    libc=$(ldd /bin/ls | grep 'musl')
    if [ -n "$libc" ]; then
        echo "musl"
    else
        echo "gnu"
    fi
}

LIBC="$(check_libc)"
echo $LIBC

if [ -z "${tag_name}" ]; then
  echo "获取到的 tag_name 为空，无法下载"
  exit 1
fi

check_dpkg_support() {
    if [ -x "$(command -v dpkg)" ]; then
        echo "系统支持 dpkg。"
    fi
}

if [ "$1" != "--manual" ] && [ -n "$(check_dpkg_support)" ]; then
    cleanup() {
        echo "cleanup, dpkg, pwd $(pwd)"
        rm "${file_name}"
    }
    
    trap 'cleanup' EXIT

    if [[ "$LIBC" == "musl" ]]; then
        file_name="bottom-musl_${tag_name}-1_amd64.deb"
    else
        file_name="bottom_${tag_name}-1_amd64.deb"
    fi

    echo "开始下载最新版本的 ${file_name} 文件，版本号：$tag_name"

    # 构建文件下载 URL
    file_url="${FILE_URL_PREFIX}${file_name}"
    # 下载文件到当前目录
    curl --http1.1 -sLJO "${file_url}"
    dpkg -i "${file_name}"
    echo "dpkg 安装 btm 成功"

    exit 0
fi

cleanup() {
    echo "cleanup, manual, pwd $(pwd)"
    rm -rf "$TMP_DIR"
}

trap 'cleanup' EXIT

file_name="bottom_i686-unknown-linux-${LIBC}.tar.gz"
file_url="${FILE_URL_PREFIX}${file_name}"
TMP_DIR="$(realpath bottom_${tag_name}_tmp)"

mkdir "$TMP_DIR"
cd "$TMP_DIR"

echo "已下载最新版本的 ${file_name} 文件，版本号：$tag_name"

curl --http1.1 -sLJO "${file_url}"
tar -xzf "${file_name}"
cp btm "$MANUAL_INSTALL_DIR"
echo "手动安装 btm 到 $MANUAL_INSTALL_DIR 成功"
