#!/usr/bin/env bash

mkdir -p /root/toggle_ipv6
SCRIPT_PATH="/root/toggle_ipv6/toggle_ipv6.sh"
SERVICE_PATH="/etc/systemd/system/toggle-ipv6.service"
TIMER_PATH="/etc/systemd/system/toggle-ipv6.timer"

# 创建切换 IPv6 状态的脚本
cat > "$SCRIPT_PATH" << 'EOF'
#!/usr/bin/env bash

ipv6_status=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)

ipv4_check() {
    local domains=("http://1.1.1.1" "https://8.8.8.8/dns-query" "https://9.9.9.9/dns-query" "http://cp.cloudflare.com" "http://google.com" "http://example.com")
    local domain
    for i in {1..3}; do
        for domain in "${domains[@]}"; do
            if curl -4 --silent --connect-timeout 10 "$domain" > /dev/null; then
                return 0
            fi
            sleep 1
        done
        sleep 3
    done
    return 1
}

if ipv4_check; then
    echo "IPv4 出口可用，检查是否需要禁用 IPv6..."
    if [ "$ipv6_status" -eq 0 ]; then
        echo "正在禁用 IPv6..."
        sysctl -w net.ipv6.conf.all.disable_ipv6=1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1
    else
        echo "IPv6 已经禁用，无需执行"
    fi
else
    echo "连续 10 次 IPv4 出口检测失败，检查是否需要启用 IPv6..."
    if [ "$ipv6_status" -eq 1 ]; then
        echo "正在启用 IPv6..."
        sysctl -w net.ipv6.conf.all.disable_ipv6=0
        sysctl -w net.ipv6.conf.default.disable_ipv6=0
        systemctl restart networking
    else
        echo "IPv6 已经启用，无需执行"
    fi
fi
EOF

# 赋予脚本执行权限
chmod +x "$SCRIPT_PATH"

# 创建 systemd 服务文件
cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Toggle IPv6 status based on IPv4 connectivity

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH

[Install]
WantedBy=multi-user.target
EOF

# 创建 systemd 定时器文件
cat > "$TIMER_PATH" << 'EOF'
[Unit]
Description=Run Toggle IPv6 script every half hour

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 重新加载 systemd 管理器配置
systemctl daemon-reload

# 启用并启动定时器
systemctl enable toggle-ipv6.timer
systemctl start toggle-ipv6.timer

echo "Installation complete. The IPv6 toggle script is now set up and scheduled to run"
