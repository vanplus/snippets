#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <service-name> <command-to-run> <restart-option>"
    exit 1
fi

service_name="$1"
command_to_run="$2"
restart_option="$3"

# 创建 Systemd 服务单元文件
service_file="/etc/systemd/system/$service_name.service"

cat <<EOF > "$service_file"
[Unit]
Description=$service_name
After=network.target

[Service]
ExecStart="$command_to_run"
Restart=$restart_option
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 Systemd 配置
systemctl daemon-reload

# 启用服务开机自启动
systemctl enable "$service_name"

# 启动服务
systemctl start "$service_name"

# 检查服务状态
systemctl status "$service_name"
