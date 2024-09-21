#!/usr/bin/env bash

# 此文件包含部分代码来自以下项目:
# 项目名称: fscarmen/warp
# 项目链接: https://gitlab.com/fscarmen/warp/
# 许可证: GNU General Public License v3.0 or later

# 通过 ip route get 获取出口接口
test_ip="192.168.193.10"
test_ip6="2606:4700:d0::a29f:c001"
out_iface=$(ip route get $test_ip 2>/dev/null | awk '{for (i=0; i<NF; i++) if ($i=="dev") {print $(i+1)}}')
out_iface6=$(ip -6 route get $test_ip6 2>/dev/null | awk '{for (i=0; i<NF; i++) if ($i=="dev") {print $(i+1)}}')

# 如果找不到出口接口，退出脚本
if [ -z "$out_iface" ] && [ -z "$out_iface6" ]; then
    echo "未找到访问 $test_ip 或 $test_ip6 的出口接口，退出脚本。"
    exit 1
fi

echo "检测到出口接口: $out_iface (IPv4) 和 $out_iface6 (IPv6)"

# 定义要插入的 IPv4 配置
ipv4_config=$(cat <<'EOF'
    # 获取 LAN4 地址并添加 IPv4 路由规则
    post-up LAN4=$(ip route get 192.168.193.10 2>/dev/null | awk '{for (i=0; i<NF; i++) if ($i=="src") {print $(i+1)}}') && ip -4 rule add from $LAN4 lookup main
    pre-down LAN4=$(ip route get 192.168.193.10 2>/dev/null | awk '{for (i=0; i<NF; i++) if ($i=="src") {print $(i+1)}}') && ip -4 rule del from $LAN4 lookup main
EOF
)

# 定义要插入的 IPv6 配置
ipv6_config=$(cat <<'EOF'
    # 获取 LAN6 地址并添加 IPv6 路由规则
    post-up LAN6=$(ip -6 route get 2606:4700:d0::a29f:c001 2>/dev/null | awk '{for (i=0; i<NF; i++) if ($i=="src") {print $(i+1)}}') && ip -6 rule add from $LAN6 lookup main
    pre-down LAN6=$(ip -6 route get 2606:4700:d0::a29f:c001 2>/dev/null | awk '{for (i=0; i<NF; i++) if ($i=="src") {print $(i+1)}}') && ip -6 rule del from $LAN6 lookup main
EOF
)

backup_content=$(cat /etc/network/interfaces)

# 初始化一个标志，用于检测是否需要修改文件
changed=false

# 检查 /etc/network/interfaces 是否存在该接口的 IPv4 配置
if [ -n "$out_iface" ] && grep -q "iface $out_iface inet[^6]" /etc/network/interfaces; then
    echo "发现出口接口 $out_iface 的 IPv4 配置"
    if grep -q "post-up LAN4" /etc/network/interfaces; then
        echo "IPv4 post-up 规则已经存在，跳过..."
    else
        # 标志文件将被修改
        changed=true
        # 通过 echo 和 sed 将 IPv4 配置插入到接口配置之后
        echo "$ipv4_config" | sed -i "/iface $out_iface inet[^6]/r /dev/stdin" /etc/network/interfaces
        echo "已为接口 $out_iface 添加 IPv4 规则。"
        
        LAN4=$(ip route get 192.168.193.10 2>/dev/null | awk '{for (i=0; i<NF; i++) if ($i=="src") {print $(i+1)}}')
        ip -4 rule add from $LAN4 lookup main
        echo "IPv4 规则已立即生效。"
    fi
else
    echo "未找到出口接口 $out_iface 的 IPv4 配置，可能需要手动添加。"
fi

# 检查 /etc/network/interfaces 是否存在该接口的 IPv6 配置
if [ -n "$out_iface6" ] && grep -q "iface $out_iface6 inet6" /etc/network/interfaces; then
    echo "发现出口接口 $out_iface6 的 IPv6 配置"
    if grep -q "post-up LAN6" /etc/network/interfaces; then
        echo "IPv6 post-up 规则已经存在，跳过..."
    else
        # 标志文件将被修改
        changed=true
        # 通过 echo 和 sed 将 IPv6 配置插入到接口配置之后
        echo "$ipv6_config" | sed -i "/iface $out_iface6 inet6/r /dev/stdin" /etc/network/interfaces
        echo "已为接口 $out_iface6 添加 IPv6 规则。"

        LAN6=$(ip -6 route get 2606:4700:d0::a29f:c001 2>/dev/null | awk '{for (i=0; i<NF; i++) if ($i=="src") {print $(i+1)}}')
        ip -6 rule add from $LAN6 lookup main
        echo "IPv6 规则已立即生效。"
    fi
else
    echo "未找到出口接口 $out_iface6 的 IPv6 配置，可能需要手动添加。"
fi

# 如果有更改，创建备份并显示文件差异
if $changed; then
    # 创建备份
    backup_file="/etc/network/interfaces.bak.$(date +%F-%T)"
    echo $backup_content > "$backup_file"
    echo "备份已保存到: $backup_file"
    
    # 打印修改前后的差异
    diffs=$(diff "$backup_file" /etc/network/interfaces)
    echo "以下是文件的差异:"
    echo "$diffs"
else
    echo "没有发现配置变化，文件未被修改"
fi

echo

set -x
cat /etc/network/interfaces
set +x
echo
set -x
ip rule
