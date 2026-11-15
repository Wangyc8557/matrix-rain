#!/bin/bash

# -----------------------------------------------------------------------------
# Matrix Rain - Final Perfect Edition
# 1. 视觉：高亮+光晕模糊 (白头 -> 亮绿光晕 -> 普绿边缘)
# 2. 兼容：SSH/MobaXterm 主动轮询适配 F11 全屏
# 3. 退出：无痕退出，完美恢复运行前的屏幕内容
# -----------------------------------------------------------------------------

# --- 1. 退出清理逻辑 (关键修改) ---
trap 'cleanup' EXIT SIGINT

cleanup() {
    tput cnorm       # 恢复光标可见
    tput rmcup       # 切换回"主屏幕缓冲区" (这一步会找回你原来的屏幕内容)
    echo -e "\e[0m"  # 重置颜色设置，防止影响后续命令行
    # 删除了这里的 clear，不再清空原来的屏幕
    exit 0
}

# --- 2. 颜色定义 (高亮光晕版) ---
COLOR_CORE="\e[1;37m"    # 核心：亮白
COLOR_GLOW="\e[1;32m"    # 光晕：亮绿 (加粗)
COLOR_EDGE="\e[0;32m"    # 边缘：普绿 (不加粗，模拟模糊)
RESET="\e[0m"

# 字符集
CHARS="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz@#$%&+=*~-::.."

# 变量初始化
declare -a drops
declare -a lens
LINES=0
COLS=0

# --- 3. 屏幕适配函数 ---
resize_screen() {
    local new_lines=$1
    local new_cols=$2

    if [[ $new_cols -gt $COLS ]]; then
        for ((c=0; c<new_cols; c++)); do
            if [[ -z "${drops[$c]}" ]]; then
                drops[$c]=$((RANDOM % (new_lines + 20) * -1))
                lens[$c]=$((RANDOM % 25 + 15))
            fi
        done
    fi

    LINES=$new_lines
    COLS=$new_cols
    clear # 这里的clear只作用于"屏保屏幕"，不影响"原屏幕"
}

# --- 4. 启动逻辑 ---
tput smcup  # 切换到"备用屏幕缓冲区" (相当于铺了一张新纸，旧纸被压在下面)
tput civis  # 隐藏光标
clear       # 清空这张"新纸"

# --- 5. 动画循环 ---
while :; do
    # 速度控制
    read -rsn1 -t 0.01 input
    if [[ "$input" == $'\x1b' ]]; then
        break
    fi

    # 主动检测窗口大小 (SSH/MobaXterm 专用)
    curr_size=$(stty size 2>/dev/null)
    curr_lines=${curr_size% *}
    curr_cols=${curr_size#* }

    if [[ "$curr_lines" != "$LINES" || "$curr_cols" != "$COLS" ]]; then
        resize_screen "$curr_lines" "$curr_cols"
    fi

    # 绘制循环
    for ((c=0; c<COLS; c++)); do
        y=${drops[$c]}
        l=${lens[$c]}
        
        glow_point=$((y - l / 3))
        tail_point=$((y - l))

        # 1. 白核
        if [[ $y -ge 0 && $y -lt $LINES ]]; then
             char=${CHARS:$((RANDOM % ${#CHARS})):1}
             printf "\e[%d;%dH%b%s" $((y+1)) $((c+1)) "${COLOR_CORE}" "$char"
        fi

        # 2. 亮绿光晕 (视觉暂留)
        prev_y=$((y - 1))
        if [[ $prev_y -ge 0 && $prev_y -lt $LINES ]]; then
             char=${CHARS:$((RANDOM % ${#CHARS})):1}
             printf "\e[%d;%dH%b%s" $((prev_y+1)) $((c+1)) "${COLOR_GLOW}" "$char"
        fi

        # 3. 普绿边缘 (模糊感)
        if [[ $glow_point -ge 0 && $glow_point -lt $LINES ]]; then
             char=${CHARS:$((RANDOM % ${#CHARS})):1}
             printf "\e[%d;%dH%b%s" $((glow_point+1)) $((c+1)) "${COLOR_EDGE}" "$char"
        fi
        
        # 4. 擦除
        if [[ $tail_point -ge 0 && $tail_point -lt $LINES ]]; then
            printf "\e[%d;%dH " $((tail_point+1)) $((c+1))
        fi

        drops[$c]=$((y + 1))

        if [[ $tail_point -ge $LINES ]]; then
            drops[$c]=$((RANDOM % 20 * -1))
            lens[$c]=$((RANDOM % 25 + 15))
        fi
    done
done