#!/bin/bash

PIPE="/tmp/ssh-tunnel.pipe"
DAEMON_PID_FILE="/tmp/ssh-tunnel-daemon.pid"
PROXY_HOST="127.0.0.1"
PROXY_PORT=1086
SSH_PATTERN="^ssh .*-D ${PROXY_HOST}:${PROXY_PORT}"  # 用户匹配所有绑定到指定 IP 和端口的 ssh 进程
SERVICE_LABEL="ssh-tunnel.service"
SERVICE_PLIST="$HOME/Library/LaunchAgents/ssh-tunnel.service.plist"

# 记录日志
function log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# 打开 SSH 代理
function open_tunnel() {
    if is_tunnel_opened; then
        log "Tunnel is already opened"
        return 0
    else
        log "Opening tunnel to '$1'"
        ssh -f -qTnN -D "${PROXY_HOST}:${PROXY_PORT}" "$1"
        log "Tunnel opened"
    fi
}

# 检查 SSH 代理是否打开
function is_tunnel_opened() {
    # 不使用 pid 文件，是为了防止在异常退出后，pid 文件未被删除导致的误判
    pkill -0 -f "$SSH_PATTERN"
}

# 关闭 SSH 代理
function close_tunnel() {
    log 'Closing tunnel'
    pkill -f "$SSH_PATTERN"  # kill 掉所有匹配的 ssh 进程
    while is_tunnel_opened; do
        sleep 0.5  # 等待进程完全退出
    done
}

# 检查守护进程 (tunnel.sh) 是否运行
function is_daemon_running() {
    [ -f "$DAEMON_PID_FILE" ] || return 1
    local pid
    pid=$(cat "$DAEMON_PID_FILE" 2>/dev/null)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ -p "$PIPE" ]
}

# 确保 "命名管道" 存在
function touch_pipe() {
    if [ ! -p "$1" ]; then
        [ -e "$1" ] && rm -f "$1"
        mkfifo "$1"
    fi
}

# 清理管道文件
function cleanup() {
    log "Cleaning up"
    rm -f "$PIPE" "$DAEMON_PID_FILE"
}

# 监听管道，处理新的连接请求
function tunnel_daemon() {
    log "Starting daemon"
    echo $$ > "$DAEMON_PID_FILE"
    current_server=$1
    touch_pipe "$PIPE"
    exec 3<>"$PIPE"
    trap cleanup EXIT

    stopped=0
    while true; do
        if ! is_tunnel_opened && [ "$stopped" -eq 0 ]; then
            open_tunnel "$current_server"
            sleep 1
        fi
        if read -t 1 -u 3 current_server; then
            case "$current_server" in
                exit)
                    close_tunnel
                    log "Bye"
                    return 0
                    ;;
                close)
                    close_tunnel
                    stopped=1
                    log "Tunnel closed, waiting for next command"
                    ;;
                *)
                    stopped=0
                    close_tunnel
                    open_tunnel "$current_server"
                    ;;
            esac
        fi
    done
}

function usage() {
    echo -e "\033[1mUsage:\033[0m $(basename "$0") SERVER | close | exit"
}


# 主程序
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

# 由 launchd 启动时（PPID 为 1），直接作为守护进程运行，
# 不执行下面的命令分发逻辑
if [ "$PPID" -eq 1 ]; then
    tunnel_daemon "$1"
    exit $?
fi

if [[ "$1" == "exit" ]]; then
    if is_daemon_running; then
        pid=$(cat "$DAEMON_PID_FILE" 2>/dev/null)
        echo "exit" > "$PIPE"
        while kill -0 "$pid" 2>/dev/null; do
            sleep 0.5
        done
    fi
    launchctl bootout "gui/$UID/$SERVICE_LABEL" 2>/dev/null
    log "Service stopped"
elif [[ "$1" == "close" ]]; then
    if is_daemon_running; then
        echo "close" > "$PIPE"
    else
        close_tunnel
        log "Daemon is not running"
    fi
elif is_daemon_running; then
    echo "$1" > "$PIPE"
else
    close_tunnel
    if launchctl bootstrap "gui/$UID" "$SERVICE_PLIST" 2>/dev/null; then
        log "Service reloaded"
    else
        log "Failed to reload service, run: launchctl bootstrap gui/$UID $SERVICE_PLIST"
    fi
fi
