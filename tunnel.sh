#!/bin/bash

PIPE="/tmp/ssh-tunnel.pipe"
PROXY_HOST="127.0.0.1"
PROXY_PORT=1086
SSH_PATTERN="^ssh .*-D ${PROXY_HOST}:${PROXY_PORT}"  # 用户匹配所有绑定到指定 IP 和端口的 ssh 进程

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
    local pids=$(pgrep -f "^/[a-z/]+/(sh|bash|zsh|fish) .*$(basename "$0")" | grep -v "^$$\$")
    [ -n "$pids" ] && [ -p "$PIPE" ]
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
    rm -f "$PIPE"
}

# 监听管道，处理新的连接请求
function tunnel_daemon() {
    log "Starting daemon"
    current_server=$1
    touch_pipe "$PIPE"
    exec 3<>"$PIPE"
    trap cleanup EXIT

    while true; do
        if ! is_tunnel_opened; then
            open_tunnel "$current_server"
            sleep 1
        fi
        if read -t 1 -u 3 current_server; then
            # 先关闭当前隧道
            close_tunnel

            # 如果输入是 exit，则退出
            if [[ "$current_server" == "exit" ]]; then
                log "Bye"
                return 0
            fi

            # 重新连接到指定服务器
            open_tunnel "$current_server"
        fi
    done
}

function usage() {
    echo -e "\033[1mUsage:\033[0m $(basename "$0") SERVER"
}


# 主程序
if [[ $# -eq 0 ]]; then
    usage
    exit 1
elif is_daemon_running; then
    echo "$1" > "$PIPE"
else
    close_tunnel
    tunnel_daemon "$1"
fi
