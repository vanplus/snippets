#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <service-name> <command-to-run> <restart-option>"
    exit 1
fi

SERVICE_NAME="$1"
COMMAND_TO_RUN="$2"
RESTART_OPTION="$3"

# 检查是否运行在 Alpine Linux 上
if [ -f /etc/alpine-release ]; then
    # 创建 init.d 服务文件
    SERVICE_FILE="/etc/init.d/$SERVICE_NAME"
    
    cat <<EOF > "$SERVICE_FILE"
#!/sbin/openrc-run

name="$SERVICE_NAME"
description="Custom Service: $SERVICE_NAME"

command="$COMMAND_TO_RUN"

command_args=""

pidfile="/var/run/\$RC_SVCNAME.pid"

start() {
    ebegin "Starting \$name"
    start-stop-daemon --start --exec \$command -- \$command_args
    eend $?
}

stop() {
    ebegin "Stopping \$name"
    start-stop-daemon --stop --exec \$command
    eend $?
}
EOF

    # 设置服务文件可执行权限
    chmod +x "$SERVICE_FILE"

    # 添加服务到启动项
    rc-update add "$SERVICE_NAME" default

    echo "Init.d service '$SERVICE_NAME' created and enabled."
    exit 0
fi

# 创建 Systemd 服务单元文件
service_file="/etc/systemd/system/$SERVICE_NAME.service"

cat <<EOF > "$service_file"
[Unit]
Description=$SERVICE_NAME
After=network.target

[Service]
ExecStart="$COMMAND_TO_RUN"
Restart=$RESTART_OPTION
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 Systemd 配置
systemctl daemon-reload

# 启用服务开机自启动
systemctl enable "$SERVICE_NAME"

# 启动服务
systemctl start "$SERVICE_NAME"

# 检查服务状态
systemctl status "$SERVICE_NAME"
