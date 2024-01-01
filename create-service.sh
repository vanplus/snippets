#!/bin/bash

# 默认值
DEFAULT_NAME="default-service"
DEFAULT_COMMAND="echo 'Hello, World!'"
DEFAULT_RELOAD_COMMAND="echo 'Reload command not specified'"
DEFAULT_STOP_COMMAND="echo 'Stop command not specified'"
DEFAULT_RESTART="always"
DEFAULT_WORKDIR="."

# 显示脚本用法
display_help() {
    echo "Usage: $0 [-n|--name <service-name>] [-c|--command <command-to-run>] [-rl|--reload-cmd <reload-command>] [-st|--stop-cmd <stop-command>] [-r|--restart <restart-option>] [-d|--workdir <working-directory>] [-h|--help]"
    echo "Options:"
    echo "  -n, --name        Name of the service. Default: $DEFAULT_NAME"
    echo "  -c, --command     Command to run as the service. Default: $DEFAULT_COMMAND"
    echo "  -rl, --reload-cmd Command to execute on reload. Default: $DEFAULT_RELOAD_COMMAND"
    echo "  -st, --stop-cmd   Command to execute on stop. Default: $DEFAULT_STOP_COMMAND"
    echo "  -r, --restart     Restart option for the service. Default: $DEFAULT_RESTART"
    echo "  -d, --workdir     Working directory for the service. Default: $DEFAULT_WORKDIR"
    echo "  -h, --help        Display this help message."
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
        -rl|--reload-cmd)
            RELOAD_COMMAND="$2"
            shift 2
            ;;
        -st|--stop-cmd)
            STOP_COMMAND="$2"
            shift 2
            ;;
        -r|--restart)
            RESTART="$2"
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
RELOAD_COMMAND="${RELOAD_COMMAND:-$DEFAULT_RELOAD_COMMAND}"
STOP_COMMAND="${STOP_COMMAND:-$DEFAULT_STOP_COMMAND}"
RESTART="${RESTART:-$DEFAULT_RESTART}"
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

cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=$NAME
After=network.target

[Service]
ExecStart=bash -c "$COMMAND"
ExecReload=bash -c "$RELOAD_COMMAND"
ExecStop=bash -c "$STOP_COMMAND"
Restart=$RESTART
User=$(whoami)
WorkingDirectory=$WORKDIR

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 Systemd 配置
systemctl daemon-reload

# 启用服务开机自启动
systemctl enable "$NAME"

# 启动服务
systemctl start "$NAME" --wait

# 检查服务状态
systemctl status "$NAME"

journalctl -u "$NAME"
