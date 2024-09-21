#!/usr/bin/env bash -e

# 创建临时目录并进入
temp_dir="$(realpath btop_tmp)"

mkdir "$temp_dir"

cleanup() {
    cd ..
    echo "cleanup, pwd $(pwd)"
    rm -rf "$temp_dir"
}

trap 'cleanup' EXIT

cd "$temp_dir"

# 确定最新的 release 页面
latest_release_url=$(curl --http1.1 -sI https://github.com/aristocratos/btop/releases/latest | grep -i location | awk '{print $2}' | tr -d '\r')

# 提取版本号
version=$(echo $latest_release_url | grep -oP "tag/\K(v.*)")

# 构建下载链接
download_url="https://github.com/aristocratos/btop/releases/download/$version/btop-x86_64-linux-musl.tbz"

# 下载文件
curl --http1.1 -L $download_url -o btop-x86_64-linux-musl.tbz

echo "Download completed: btop-x86_64-linux-musl.tbz"

# 解压文件
tar -xjf btop-x86_64-linux-musl.tbz

# 将 btop 程序移动到 /usr/local/bin
mv btop/bin/btop /usr/local/bin/

# 给 btop 可执行权限
chmod +x /usr/local/bin/btop

echo "Installation completed: btop is now available in /usr/local/bin"
