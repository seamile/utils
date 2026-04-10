#!/bin/bash

# 确定 Bun 全局安装路径，优先使用环境变量，缺省值为 ~/.bun
BASE_PATH="${BUN_INSTALL:-$HOME/.bun}"
GLOBAL_DIR="$BASE_PATH/install/global"

if [ ! -d "$GLOBAL_DIR" ]; then
    echo "错误: 找不到目录 $GLOBAL_DIR"
    exit 1
fi

cd "$GLOBAL_DIR"

# 检查是否存在 package.json，不存在则初始化
if [ ! -f "package.json" ]; then
    echo "{}" > package.json
fi

# 执行信任操作并重新安装以激活脚本
echo -e "正在进入 $GLOBAL_DIR 执行信任操作...\n"
bun pm trust --all
bun install

echo -e "\n---\nChecking again\n"

bun pm -g untrusted
