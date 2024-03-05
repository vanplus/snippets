#!/bin/bash -e

# 解析参数

# 显示帮助信息
show_usage() {
    echo "用法: $0 [选项]..."
    echo "选项:"
    echo "  --root-domain <domain>    设置根域名"
    echo "  --ip-gettype <type>       设置 IP 获取方式"
    echo "  --cf-token <token>        设置 Cloudflare Token"
    echo "  -- <cmd>                  传递给 ddns-go -s install 安装时的参数"
    echo "  --help                    显示此帮助信息"
}

# 检查并设置参数
set_parameter() {
    local param_name=$1
    local param_value=$2
    if [ -z "$param_value" ]; then
        echo "错误：$param_name 需要一个非空的值。"
        show_usage
        exit 1
    fi
    eval "$param_name='$param_value'"
}

# 默认参数
root_domain=""
ip_gettype="url"
cf_token=""
ddns_go_args="-f 10 -cacheTimes 180 -noweb"

# 查找 '--' 参数的位置
separator_pos=0
for arg in "$@"; do
    separator_pos=$((separator_pos + 1))
    if [ "$arg" = "--" ]; then
        break
    fi
done

# 检查是否存在 '--' 分隔符
if [ "$separator_pos" -lt "$#" ]; then
    # 使用 '--' 之后的参数
    ddns_go_args=("${@:separator_pos+1}")
    ddns_go_args="${ddns_go_args[@]}"
fi

# 解析命令行选项
while [ $# -gt 0 ]; do
    case "$1" in
        --root-domain)
            set_parameter root_domain "$2"
            shift 2
            ;;
        --ip-gettype)
            set_parameter ip_gettype "$2"
            shift 2
            ;;
        --cf-token)
            set_parameter cf_token "$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 1
            ;;
        *)
            shift
            ;;
    esac
done

# 如果 ddns-go 已经安装，则提示用户卸载
SERVICE_NAME="ddns-go"

# 检查 ddns-go 服务是否存在
if systemctl --quiet is-active $SERVICE_NAME > /dev/null 2>&1; then
    echo "ddns-go 服务已安装。请先卸载"
    exit 1
elif systemctl --quiet is-enabled $SERVICE_NAME > /dev/null 2>&1 ; then
    echo "ddns-go 服务已安装。请先卸载"
    exit 1
fi

# 检查 ddns-go 进程是否存在
if pgrep -x "ddns-go" > /dev/null; then
    echo "ddns-go 进程正在运行。请先停止"
    exit 1
fi

INSTALL_DIR=~/ddns-go

mkdir -p $INSTALL_DIR
CONFIG_FILE_NAME="${INSTALL_DIR}/config.yaml"

# 生成配置文件

# 获取当前网络接口列表
get_interfaces() {
    # 获取所有网络接口的名称，排除lo
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)

    # 创建一个空数组来存储接口名称和IP地址
    interface_info=()

    # 根据参数进行不同的输出
    if [ "$1" == "-4" ]; then
        # 输出每个接口的名称和 IPv4 地址
        for interface in $interfaces; do
            ipv4=$(ip -o -4 addr show dev $interface | awk '{print $4}')
            interface_info+=("$interface ($ipv4)")
        done
    elif [ "$1" == "-6" ]; then
        # 输出每个接口的名称和 IPv6 地址
        for interface in $interfaces; do
            ipv6=$(ip -o -6 addr show dev $interface | awk '{print $4}')
            interface_info+=("$interface ($ipv6)")
        done
    else
        echo "无效的参数。使用 -4 获取 IPv4 地址，使用 -6 获取 IPv6 地址。"
        return 1
    fi

    # 返回接口信息数组
    printf "%s\n" "${interface_info[@]}"
}

# 读取用户输入，支持默认值
read_with_default() {
    local prompt=$1 default=$2
    read -e -p "$prompt: " -i "${default}" input
    echo "${input:-$default}"
}

# 函数：读取必填项
read_required() {
    local input
    local prompt=$1
    while true; do
        read -e -p "$prompt: " input
        if [ -z "$input" ]; then
            echo "这是必填项，请输入一个值。"
        else
            echo "$input"
            break
        fi
    done
}

generate_random_hex() {
    dd if=/dev/urandom bs=4 count=1 2>/dev/null | xxd -p -c 8 | tr -d '\n'
}

generate_random_password() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12
}

ipv4_domain=""
ipv6_domain=""
# 如果指定了 --root-domain，生成特定格式的字符串
if [ ! -z "$root_domain" ]; then
    hostname=$(hostname)
    random_hex=$(generate_random_hex)
    ipv4_domain="${hostname}.${random_hex}:${root_domain}"
    ipv6_domain="${hostname}.v6.${random_hex}:${root_domain}"
fi

# 读取 dns.secret
echo "Cloudflare token 可访问 https://dash.cloudflare.com/profile/api-tokens 申请，Create Token -> Edit Zone DNS (Use template)"
dns_secret=$(read_with_default "请输入 Cloudflare token" $cf_token)

# 读取 IPv4 配置
ipv4_enable=$(read_with_default "IPv4 是否启用? (true/false)" "true")
ipv4_gettype=$ip_gettype
if [ "$ipv4_enable" = "true" ]; then
    ipv4_gettype=$(read_with_default "IPv4 获取 IP 的方式 (url/netInterface/cmd)" "$ipv4_gettype")
    if [ "$ipv4_gettype" = "cmd" ]; then
        ipv4_cmd=$(read_required "请输入 IPv4 获取 IP 的命令")
    elif [ "$ipv4_gettype" = "netInterface" ]; then
        readarray -t interface_array < <(get_interfaces -4)
        echo "可用网络接口："
        for item in "${interface_array[@]}"; do
            echo "$item"
        done

        ipv4_netinterface=$(echo "${interface_array[0]}" | awk '{print $1}')
        ipv4_netinterface=$(read_with_default "请输入网络接口名字" "$ipv4_netinterface")
    fi
    echo "请输入 IPv4 的 domains，「使用冒号」分隔子域名和根域名，比如 www:example.cn.eu.org（支持多条域名, 使用空格分隔）："
    read -e -ra ipv4_domains -i "$ipv4_domain"
fi

# 读取 IPv6 配置
ipv6_enable=$(read_with_default "IPv6 是否启用? (true/false)" "false")
ipv6_gettype=$ip_gettype
if [ "$ipv6_enable" = "true" ]; then
    ipv6_gettype=$(read_with_default "IPv6 获取 IP 的方式 (url/netInterface/cmd)" "$ipv6_gettype")
    if [ "$ipv6_gettype" = "cmd" ]; then
        ipv6_cmd=$(read_required "请输入 IPv6 获取IP的命令")
    elif [ "$ipv6_gettype" = "netInterface" ]; then
        readarray -t interface_array < <(get_interfaces -6)
        echo "可用网络接口："
        for item in "${interface_array[@]}"; do
            echo "$item"
        done

        ipv6_netinterface=$(echo "${interface_array[0]}" | awk '{print $1}')
        ipv6_netinterface=$(read_with_default "请输入网络接口名字" "$ipv6_netinterface")
    fi
    echo "请输入 IPv6 的 domains, 子域名和根域名之间用冒号分隔，比如 www:example.cn.eu.org（支持多条域名, 使用空格分隔）："
    read -e -ra ipv6_domains -i "$ipv6_domain"
fi

# 自动生成的用户名和密码
username="admin"
password=$(generate_random_password)

username=$(read_with_default "输入用户名" "${username}")
password=$(read_with_default "输入密码" "${password}")

# 创建配置文件
cat << EOF > $CONFIG_FILE_NAME
dnsconf:
    - ipv4:
        enable: $ipv4_enable
        gettype: $ipv4_gettype
        url: https://api.ipify.org, https://ddns.oray.com/checkip, https://ip.3322.net, https://4.ipw.cn
        netinterface: $ipv4_netinterface
        cmd: "$ipv4_cmd"
        domains:
EOF
for domain in "${ipv4_domains[@]}"; do
    echo "            - $domain" >> $CONFIG_FILE_NAME
done

cat << EOF >> $CONFIG_FILE_NAME
      ipv6:
        enable: $ipv6_enable
        gettype: $ipv6_gettype
        url: https://api64.ipify.org, https://speed.neu6.edu.cn/getIP.php, https://v6.ident.me, https://6.ipw.cn
        netinterface: $ipv6_netinterface
        cmd: "$ipv6_cmd"
        domains:
EOF
for domain in "${ipv6_domains[@]}"; do
    echo "            - $domain" >> $CONFIG_FILE_NAME
done

cat << EOF >> $CONFIG_FILE_NAME
      dns:
        name: cloudflare
        id: ""
        secret: $dns_secret
      ttl: ""
user:
    username: "${username}"
    password: "${password}"
webhook:
    webhookurl: ""
    webhookrequestbody: ""
    webhookheaders: ""
notallowwanaccess: true
lang: en
EOF

echo "配置文件 ${CONFIG_FILE_NAME} 已生成"

# 安装

# GitHub 仓库所有者和仓库名称
OWNER="jeessy2"
REPO="ddns-go"

# GitHub Release 页面 URL
RELEASES_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"

echo "解析 ddns-go 安装包下载地址"

response=$(curl -s ${RELEASES_URL})

if ! DOWNLOAD_URL=$(echo "$response" | python3 -c "import sys, json; print(next(item['browser_download_url'] for item in json.load(sys.stdin)['assets'] if 'ddns-go_' in item['name'] and 'linux_x86_64.tar.gz' in item['name']))"); then
    echo "解析失败：$response"
    exit 1
else
    echo "下载地址解析成功：$DOWNLOAD_URL"
fi

cleanup() {
    rm -rf "$TMP_DIR"
}

trap 'cleanup' EXIT

TMP_DIR="$(realpath ddns-go_install_tmp)"

mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

FILE_NAME="ddns-go_latest_linux_x86_64.tar.gz"

echo ”开始下载 ${FILE_NAME}“
curl -sL -o "$FILE_NAME" "$DOWNLOAD_URL"
tar -xzf "${FILE_NAME}"
cp ddns-go "$INSTALL_DIR"

ddns_go_args=$(read_with_default "输入 ddns-go 安装命令参数" "${ddns_go_args}")
# 如果启用 -noweb 则再次询问是否启用 web ui
if [[ "$ddns_go_args" == *"-noweb"* ]]; then
    # 询问用户是否启用 Web UI
    enable_web_ui=$(read_with_default "是否启用 Web UI? (n/y)" "n")
    if [[ "$enable_web_ui" == "y" ]]; then
        # 如果启用，则去掉 -noweb 参数
        ddns_go_args="${ddns_go_args/-noweb/}"
    fi
fi

echo "开始安装为服务"
$INSTALL_DIR/ddns-go -s install -c $CONFIG_FILE_NAME $ddns_go_args
systemctl status $SERVICE_NAME &

sleep 0.2
# ANSI 转义序列设置为绿色和重置
green="\033[32m"
reset="\033[0m"

echo -e "\n"
echo -e "用户名: ${green}${username}${reset}"
echo -e "密码: ${green}${password}${reset}"

for domain in "${ipv4_domains[@]}"; do
    echo -e "IPv4 域名： ${green}${domain//:/\.}${reset}"
done

for domain in "${ipv6_domains[@]}"; do
    echo -e "IPv6 域名： ${green}${domain//:/\.}${reset}"
done
