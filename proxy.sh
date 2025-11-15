#!/bin/bash
# 代理管理脚本 - 用于管理SSH代理和系统代理设置

# 配置参数
PAC_URL="https://seamile.cn/static/sweety.pac"
SOCKS_HOST="127.0.0.1"
SOCKS_PORT=1086
HTTPS_PORT=1087
DEVICE="" # 联网设备
REMOTE_HOST="bee" # 远程主机

# 日志函数
log_info() {
    printf "\n\033[1;34m%s\033[0m\n" "$1"
}

log_warn() {
    printf "\033[1;33m[警告] %s\033[0m\n" "$1"
}

log_error() {
    printf "\033[1;31m[错误] %s\033[0m\n" "$1"
}

# 检查远程主机是否可访问
check_remote_host() {
    log_info "正在检查远程主机 '$REMOTE_HOST' 连接性..."
    if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_HOST" exit; then
        log_warn "无法连接到远程主机 '$REMOTE_HOST'。请检查您的SSH配置。"
        return 1
    fi
    log_info "远程主机 '$REMOTE_HOST' 可访问。"
    return 0
}

# 启动 SSH 代理模式
open_ssh_proxy() {
    if ! check_remote_host; then
        read -n 1 -p "是否仍要尝试启动SSH代理？ [y/n] " continue
        echo
        if [[ $continue != "y" && $continue != "Y" ]]; then
            return 1
        fi
    fi

    # 检查SSH代理是否已在运行
    if ! pkill -0 -f 'ssh -fqTnN' 2>&1 >/dev/null; then
        log_info "正在启动 SSH 代理..."
        if ssh -fqTnN -D "$SOCKS_HOST:$SOCKS_PORT" "$REMOTE_HOST"; then
            log_info "代理已成功开启！"
        else
            local exit_code=$?
            log_error "启动SSH代理失败！退出代码: $exit_code"
            return 1
        fi
    else
        read -n 1 -p "代理已经在运行，是否要重启？ [y/n] " restart
        echo
        if [[ $restart == "y" || $restart == "Y" ]]; then
            log_info "正在重启 SSH 代理..."
            close_ssh_proxy
            if ssh -fqTnN -D "$SOCKS_HOST:$SOCKS_PORT" "$REMOTE_HOST"; then
                log_info "代理已成功重启！"
            else
                local exit_code=$?
                log_error "重启SSH代理失败！退出代码: $exit_code"
                return 1
            fi
        fi
    fi
    return 0
}

# 关闭 SSH 代理模式
close_ssh_proxy() {
    log_info "正在尝试关闭 SSH 代理..."
    if pkill -f "ssh -fqTnN" 2>&1; then
        log_info "SSH 代理已成功关闭。"
        return 0
    else
        local exit_code=$?
        log_warn "没有运行中的 SSH 代理。退出代码: $exit_code"
        return 1
    fi
}

# 展示和选择网络设备
choose_network_device() {
    log_info "正在获取网络设备列表..."
    local devices=()

    # 获取网络设备列表
    local network_services_output
    network_services_output=$(networksetup -listallnetworkservices 2>&1)
    if [ $? -ne 0 ]; then
        log_error "获取网络设备列表失败: $network_services_output"
        return 1
    fi

    while IFS= read -r line; do
        devices+=("$line")
    done < <(echo "$network_services_output" | tail -n +2)

    # 检查是否获取到设备
    if [ ${#devices[@]} -eq 0 ]; then
        log_error "未找到网络设备。"
        return 1
    fi

    printf "\n当前网络设备列表：\n"
    for i in "${!devices[@]}"; do
        printf "[$((i+1))] ${devices[$i]}\n"
    done

    while true; do
        read -p "请输入当前联网设备的序号: " device_number
        # 检查输入是否为数字
        if [[ ! $device_number =~ ^[0-9]+$ ]]; then
            log_warn "请输入有效的数字！"
            continue
        fi

        if [[ $device_number -ge 1 && $device_number -le ${#devices[@]} ]]; then
            DEVICE="${devices[$((device_number-1))]}"
            return 0
        else
            log_warn "无效序号！请输入 1 到 ${#devices[@]} 之间的数字。"
        fi
    done
}

# 检查设备是否已选择
check_device_selected() {
    if [ -z "$DEVICE" ]; then
        log_error "未选择网络设备。请先选择网络设备。"
        return 1
    fi
    return 0
}

# 设置自动代理
set_auto_proxy() {
    if ! check_device_selected; then
        choose_network_device
    fi

    log_info "正在设置自动代理 (PAC)..."

    # 设置自动代理URL
    local result_url
    result_url=$(networksetup -setautoproxyurl "$DEVICE" "$PAC_URL" 2>&1)
    if [ $? -ne 0 ]; then
        log_error "设置自动代理URL失败: $result_url"
        return 1
    fi

    # 启用自动代理
    local result_state
    result_state=$(networksetup -setautoproxystate "$DEVICE" on 2>&1)
    if [ $? -ne 0 ]; then
        log_error "启用自动代理失败: $result_state"
        return 1
    fi

    log_info "自动代理已成功开启！"
    return 0
}

# 设置全局 SOCKS5 代理
set_global_proxy() {
    if ! check_device_selected; then
        choose_network_device
    fi

    log_info "正在设置全局代理 (SOCKS5)..."

    # 设置SOCKS代理服务器
    local result_proxy
    result_proxy=$(networksetup -setsocksfirewallproxy "$DEVICE" "$SOCKS_HOST" "$SOCKS_PORT" 2>&1)
    if [ $? -ne 0 ]; then
        log_error "设置SOCKS代理服务器失败: $result_proxy"
        return 1
    fi

    # 启用SOCKS代理
    local result_state
    result_state=$(networksetup -setsocksfirewallproxystate "$DEVICE" on 2>&1)
    if [ $? -ne 0 ]; then
        log_error "启用SOCKS代理失败: $result_state"
        return 1
    fi

    log_info "全局代理已成功开启！"
    return 0
}

# 关闭系统代理
disable_system_proxy() {
    if ! check_device_selected; then
        choose_network_device
    fi

    log_info "正在关闭系统代理..."
    local success=true

    # 关闭自动代理
    local result_auto
    result_auto=$(networksetup -setautoproxystate "$DEVICE" off 2>&1)
    if [ $? -ne 0 ]; then
        log_error "关闭自动代理失败: $result_auto"
        success=false
    fi

    # 关闭SOCKS代理
    local result_socks
    result_socks=$(networksetup -setsocksfirewallproxystate "$DEVICE" off 2>&1)
    if [ $? -ne 0 ]; then
        log_error "关闭全局代理失败: $result_socks"
        success=false
    fi

    if [ "$success" = true ]; then
        log_info "系统代理已成功关闭！"
        return 0
    else
        return 1
    fi
}

# 查看系统代理状态
show_system_proxy_status() {
    if ! check_device_selected; then
        choose_network_device
    fi

    log_info "$DEVICE"
    log_info "> 自动代理状态："
    networksetup -getautoproxyurl "$DEVICE"        # 获取自动代理状态
    log_info "> 全局代理状态："
    networksetup -getsocksfirewallproxy "$DEVICE"  # 获取SOCKS代理状态

    return 0
}

# 终端代理设置
toggle_terminal_proxy() {
    # 检查是否有任何代理环境变量已设置
    if [ -z "${HTTP_PROXY}${HTTPS_PROXY}${ALL_PROXY}" ]; then
        # 检查 SSH 代理是否运行
        if ! pkill -0 -f 'ssh -fqTnN' 2>&1 >/dev/null; then
            log_warn "SSH 代理未运行，终端代理可能无法正常工作。"
            read -n 1 -p "是否仍要启用终端代理？ [y/n] " continue
            echo
            if [[ $continue != "y" && $continue != "Y" ]]; then
                return 1
            fi
        fi

        export HTTP_PROXY="socks5://$SOCKS_HOST:$SOCKS_PORT"
        export HTTPS_PROXY="socks5://$SOCKS_HOST:$SOCKS_PORT"
        export ALL_PROXY="socks5://$SOCKS_HOST:$SOCKS_PORT"
        log_info "终端代理已开启: $ALL_PROXY"
        return 0
    else
        unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
        log_info "终端代理已关闭"
        return 0
    fi
}

# 显示帮助信息
show_help() {
    echo "代理管理脚本 - 用于管理SSH代理和系统代理设置"
    echo "用法: $0"
    echo
    echo "选项:"
    echo "  1. 启动后台 SSH 代理"
    echo "  2. 关闭 SSH 代理"
    echo "  3. 开启系统代理-自动模式 (PAC)"
    echo "  4. 开启系统代理-全局模式 (SOCKS5)"
    echo "  5. 关闭系统代理"
    echo "  6. 查看系统代理状态"
    echo "  7. 为终端 打开/关闭 代理"
    echo
}

# 用户交互
main() {
    echo "代理管理脚本"
    echo "=============="
    echo "1. 启动后台 SSH 代理"
    echo "2. 关闭 SSH 代理"
    echo "3. 开启系统代理-自动模式 (PAC)"
    echo "4. 开启系统代理-全局模式 (SOCKS5)"
    echo "5. 关闭系统代理"
    echo "6. 查看系统代理状态"
    echo "7. 为终端 打开/关闭 代理"
    echo "h. 显示帮助信息"
    echo "q. 退出"
    read -n 1 -p "输入选择 [1-7,h,q]: " choice
    echo

    case $choice in
        1)
            open_ssh_proxy
            ;;
        2)
            close_ssh_proxy
            ;;
        3)
            choose_network_device
            set_auto_proxy
            ;;
        4)
            choose_network_device
            set_global_proxy
            ;;
        5)
            choose_network_device
            disable_system_proxy
            ;;
        6)
            choose_network_device
            show_system_proxy_status
            ;;
        7)
            toggle_terminal_proxy
            ;;
        h|H)
            show_help
            ;;
        q|Q)
            log_info "退出程序"
            exit 0
            ;;
        *)
            log_error "无效选择！请输入 1-7, h 或 q"
            ;;
    esac
}

main
