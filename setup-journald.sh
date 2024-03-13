#!/bin/bash

# 定义新的配置值
SYSTEM_MAX_USE="100M"
RUNTIME_MAX_USE="30M"
SYSTEM_KEEP_FREE="200M"
RUNTIME_KEEP_FREE="100M"

# 解析命令行选项
while getopts "s:r:k:f:" opt; do
  case $opt in
    s) SYSTEM_MAX_USE="$OPTARG" ;;
    r) RUNTIME_MAX_USE="$OPTARG" ;;
    k) SYSTEM_KEEP_FREE="$OPTARG" ;;
    f) RUNTIME_KEEP_FREE="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

# 配置文件路径
CONFIG_FILE="/etc/systemd/journald.conf"

# 备份原配置文件
cp ${CONFIG_FILE} ${CONFIG_FILE}.bak

# 更新配置函数
update_config() {
    local key=$1
    local value=$2
    local file=$3

    if grep -q "^${key}=" "$file"; then
        # 如果找到该配置项（已经存在），则替换它
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    elif grep -q "^#${key}=" "$file"; then
        # 如果找到该配置项（被注释），则替换它
        sed -i "s|^#${key}=.*|${key}=${value}|" "$file"
    else
        # 如果配置项不存在，则在文件末尾添加
        echo "${key}=${value}" >> "$file"
    fi

    echo "${key}=${value}"
}

# 更新配置项
update_config "SystemMaxUse" "$SYSTEM_MAX_USE" "$CONFIG_FILE"
update_config "RuntimeMaxUse" "$RUNTIME_MAX_USE" "$CONFIG_FILE"
update_config "SystemKeepFree" "$SYSTEM_KEEP_FREE" "$CONFIG_FILE"
update_config "RuntimeKeepFree" "$RUNTIME_KEEP_FREE" "$CONFIG_FILE"

echo -e ""
du -h --max-depth=1 /var/log

# 重启 systemd-journald 服务
systemctl restart systemd-journald

green="\033[32m"
reset="\033[0m"

echo -e ""
echo -e "${green}journald 配置已更新并重启应用${reset}"

echo -e ""
du -h --max-depth=1 /var/log
