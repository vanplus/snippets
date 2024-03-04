#!/bin/bash -e

# 解析参数

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

echo "[INFO] ddns-go args: ${ddns_go_args}"
INSTALL_DIR=~/ddns-go

mkdir -p $INSTALL_DIR
CONFIG_FILE_NAME="${INSTALL_DIR}/config.yaml"

# 生成配置文件

# 函数：获取当前网络接口列表
list_net_interfaces() {
    ip -o link show | awk -F': ' '{print $2}' | grep -v lo
}

# 读取用户输入，支持默认值
read_with_default() {
    local prompt=$1 default=$2
    read -p "$prompt [$default]: " input
    echo "${input:-$default}"
}

# 函数：读取必填项
read_required() {
    local input
    local prompt=$1
    while true; do
        read -p "$prompt: " input
        if [ -z "$input" ]; then
            echo "这是必填项，请输入一个值。"
        else
            echo "$input"
            break
        fi
    done
}

# 读取 dns.secret
echo "Cloudflare token 可访问 https://dash.cloudflare.com/profile/api-tokens 申请，Create Token -> Edit Zone DNS (Use template)"
dns_secret=$(read_required "请输入 Cloudflare token")

# 读取 IPv4 配置
ipv4_enable=$(read_with_default "IPv4 是否启用? (true/false)" "true")
if [ "$ipv4_enable" = "true" ]; then
    ipv4_gettype=$(read_with_default "IPv4 获取 IP 的方式(url/netinterface/cmd)" "url")
    if [ "$ipv4_gettype" = "cmd" ]; then
        ipv4_cmd=$(read_required "请输入 IPv4 获取 IP 的命令")
    elif [ "$ipv4_gettype" = "netinterface" ]; then
        echo "可用网络接口:"
        list_net_interfaces
        ipv4_netinterface=$(read_required "请选择一个网络接口")
    fi
    echo "请输入 IPv4 的 domains，子域名和根域名之间用冒号分隔，比如 www:example.cn.eu.org（支持多条域名, 使用空格分隔）："
    read -ra ipv4_domains
fi

# 读取 IPv6 配置
ipv6_enable=$(read_with_default "IPv6 是否启用? (true/false)" "false")
if [ "$ipv6_enable" = "true" ]; then
    ipv6_gettype=$(read_with_default "IPv6 获取 IP 的方式(url/netinterface/cmd)" "url")
    if [ "$ipv6_gettype" = "cmd" ]; then
        ipv6_cmd=$(read_required "请输入 IPv6 获取IP的命令")
    elif [ "$ipv6_gettype" = "netinterface" ]; then
        echo "可用网络接口:"
        list_net_interfaces
        ipv6_netinterface=$(read_required "请选择一个网络接口")
    fi
    echo "请输入 IPv6 的 domains, 子域名和根域名之间用冒号分隔，比如 www:example.cn.eu.org（支持多条域名, 使用空格分隔）："
    read -ra ipv6_domains
fi

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
    username: ""
    password: ""
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
    echo "cleanup, pwd $(pwd)"
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

echo "开始安装为服务"

$INSTALL_DIR/ddns-go -s install -c $CONFIG_FILE_NAME $ddns_go_args

systemctl status ddns-go
