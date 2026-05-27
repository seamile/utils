#!/bin/bash

PIPE="/tmp/ssh-tunnel.pipe"
PROXY_BIND="127.0.0.1"
PROXY_PORT=1086

# 记录日志
function log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*";
}

# 打开 SSH 代理
function open_tunnel() {
    if is_tunnel_opened; then
        log "Tunnel is already opened"
        return 0
    else
        log "Opening tunnel to '$1'"
        ssh -f -qTnN -D "${PROXY_BIND}:${PROXY_PORT}" "$1"  # 通过 -f 在后台运行
        log "Tunnel opened"
    fi
}

# 获取进程 ID
function get_tunnel_pid() {
    pid=$(pgrep -f "^ssh .*-D ${PROXY_BIND}:${PROXY_PORT}")
    if [ -n "$pid" ]; then
        echo $pid
    else
        return 1
    fi
}

# 检查 SSH 代理是否打开
function is_tunnel_opened() {
    pkill -0 -f "^ssh .*-D ${PROXY_BIND}:${PROXY_PORT}"
}

# 关闭 SSH 代理
function close_tunnel() {
    log 'Closing tunnel'
    pkill -f "^ssh .*-D ${PROXY_BIND}:${PROXY_PORT}"
}

# 检查守护进程 (tunnel.sh) 是否运行
function is_daemon_running() {
    pkill -0 -f "$(basename $0)" && [ -p "$PIPE" ]
}

# 关闭守护进程
function kill_daemon() {
    log "Killing daemon"
    rm -f "$PIPE"
    pkill -f "$(basename $0)"
}

# 确保 "命名管道" 存在
function touch_pipe() {
    if [ ! -p "$1" ]; then
        [ -e "$1" ] && rm -f "$1"
        mkfifo "$1"
    fi
}

# 监听管道，处理新的连接请求
function listen_pipe() {
    touch_pipe $PIPE

    while [ -p "$PIPE" ]; do
        if read server < "$PIPE"; then
            # 先关闭当前隧道
            close_tunnel

            # 如果输入是 exit，则退出
            if [[ "$server" == "exit" ]]; then
                log "Bye"
                return 0
            fi

            # 重新连接到指定服务器
            open_tunnel $server
        else
            # 理论上不会发生，但为安全起见，加一个短暂的等待
            sleep 0.3
        fi
    done

    rm -f "$PIPE"
}

function usage() {
    echo -e "\033[1mUsage:\033[0m $(basename "$0") SERVER"
}


# 主程序
if [[ $# -eq 0 ]]; then
    usage
    exit 1
elif is_daemon_running; then
    echo "$1" > $PIPE
else
    kill_daemon
    close_tunnel
    open_tunnel $1
    listen_pipe
fi
