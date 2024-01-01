#!/bin/bash

# 默认值
DEFAULT_NAME="default-service"
DEFAULT_COMMAND="echo 'Hello, World!'"
DEFAULT_RESTART="always"
DEFAULT_EXEC_RELOAD=""
DEFAULT_STOP=""
DEFAULT_WORKDIR="."

# 显示脚本用法
display_help() {
    echo "Usage: $0 [-n|--name <service-name>] [-c|--command <command-to-run>] [-r|--restart <restart-command>] [-x|--exec-reload <reload-command>] [-s|--stop <stop-command>] [-d|--workdir <working-directory>] [-h|--help]"
    echo "Options:"
    echo "  -n, --name          Name of the service. Default: $DEFAULT_NAME"
    echo "  -c, --command       Command to run as the service. Default: $DEFAULT_COMMAND"
    echo "  -r, --restart       Restart command for the service. Default: $DEFAULT_RESTART"
    echo "  -x, --exec-reload   Reload command for the service. Default: $DEFAULT_EXEC_RELOAD"
    echo "  -s, --stop          Stop command for the service. Default: $DEFAULT_STOP"
    echo "  -d, --workdir       Working directory for the service. Default: $DEFAULT_WORKDIR"
    echo "  -h, --help          Display this help message."
}

# 如果没有提供任何参数，则显示帮助信息
if [ "$#" -eq 0 ]; then
    display_help
    exit 0
fi

# 解析命令行选项
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -n|--name)
            NAME="$2"
            shift 2
            ;;
        -c|--command)
            COMMAND="$2"
            shift 2
            ;;
        -r|--restart)
            RESTART="$2"
            shift 2
            ;;
        -x|--exec-reload)
            EXEC_RELOAD="$2"
            shift 2
            ;;
        -s|--stop)
            STOP="$2"
            shift 2
            ;;
        -d|--workdir)
            WORKDIR="$2"
            shift 2
            ;;
        -h|--help)
            display_help
            exit 0
            ;;
        *)
            echo "Unknown option: $key"
            display_help
            exit 1
            ;;
    esac
done

# 设置默认值
NAME="${NAME:-$DEFAULT_NAME}"
COMMAND="${COMMAND:-$DEFAULT_COMMAND}"
RESTART="${RESTART:-$DEFAULT_RESTART}"
EXEC_RELOAD="${EXEC_RELOAD:-$DEFAULT_EXEC_RELOAD}"
STOP="${STOP:-$DEFAULT_STOP}"
WORKDIR="${WORKDIR:-$DEFAULT_WORKDIR}"

# 转换为绝对路径
WORKDIR=$(realpath "$WORKDIR")

# 检查是否运行在 Alpine Linux 上
if [ -f /etc/alpine-release ]; then
    # 创建 init.d 服务文件
    SERVICE_FILE="/etc/init.d/$NAME"

    cat <<EOF > "$SERVICE_FILE"
#!/sbin/openrc-run

name="$NAME"
description="Custom Service: $NAME"

command="$COMMAND"
command_args=""
pidfile="/var/run/\$RC_SVCNAME.pid"
directory="$WORKDIR"

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
    rc-update add "$NAME" default

    echo "Init.d service '$NAME' created and enabled."
    rc-service "$NAME" start
    rc-status
    exit 0
fi

# 创建 Systemd 服务单元文件
SERVICE_FILE="/etc/systemd/system/$NAME.service"

# 添加 ExecReload 指令，如果提供了 exec-reload 参数
EXEC_RELOAD_COMMAND=""
if [ -n "$EXEC_RELOAD" ]; then
    EXEC_RELOAD_COMMAND="ExecReload=$EXEC_RELOAD"
fi

# 添加 Stop 指令，如果提供了 stop 参数
STOP_COMMAND=""
if [ -n "$STOP" ]; then
    STOP_COMMAND="ExecStop=$STOP"
fi

cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=$NAME
After=network.target

[Service]
ExecStart=$COMMAND
User=$(whoami)
WorkingDirectory=$WORKDIR
$EXEC_RELOAD_COMMAND
$STOP_COMMAND
Restart=$RESTART

[Install]
WantedBy=multi-user.target
EOF

echo "systemctl status $NAME"
echo "journalctl -u $NAME"

# 重新加载 Systemd 配置
systemctl daemon-reload

# 启用服务开机自启动
systemctl enable "$NAME"

# 启动服务
systemctl start "$NAME" --wait

# 检查服务状态
systemctl status "$NAME"

journalctl -u "$NAME"
