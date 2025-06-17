#!/usr/bin/env bash -e

# 检查参数数量
if [ $# -ne 2 ]; then
    echo "用法: $0 <服务名> <OnCalendar 定时参数>"
    echo "示例: $0 nginx.service 'daily'"
    exit 1
fi

SERVICE_NAME=$1
ONCALENDAR=$2

TIMER_NAME="restart-${SERVICE_NAME//./-}.timer"
SERVICE_UNIT_NAME="restart-${SERVICE_NAME//./-}.service"

# 定义路径
TIMER_PATH="/etc/systemd/system/$TIMER_NAME"
SERVICE_PATH="/etc/systemd/system/$SERVICE_UNIT_NAME"

# 创建 Timer 文件
cat <<EOF > "$TIMER_PATH"
[Unit]
Description=Timer to restart $SERVICE_NAME

[Timer]
OnCalendar=$ONCALENDAR
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 创建对应的 Service 文件
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Restart $SERVICE_NAME

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl restart $SERVICE_NAME
EOF

# 重载systemd并启用定时器
systemctl daemon-reload
systemctl enable --now "$TIMER_NAME"

# 显示结果
echo "成功创建并启动了定时器：$TIMER_NAME"
systemctl list-timers --no-pager | grep "$TIMER_NAME"
