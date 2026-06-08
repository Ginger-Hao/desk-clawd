#!/bin/bash
# find-esp32.sh — 自动扫描局域网找到 ESP32 红绿灯并更新 Claude Code hooks
# 用法: 连上手机热点后:  bash find-esp32.sh

SETTINGS="$HOME/.claude/settings.json"

# 1. 先试试上次的 IP 还能不能用
LAST_IP=$(grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/light' "$SETTINGS" | head -1 | sed 's/\/light//')
if [ -n "$LAST_IP" ]; then
    echo "🔍 检查上次的 IP $LAST_IP ..."
    if curl -s --connect-timeout 2 "http://$LAST_IP/light?state=idle" > /dev/null 2>&1; then
        echo "  ✅ $LAST_IP 仍然有效，无需更新"
        exit 0
    else
        echo "  ❌ $LAST_IP 已失效，开始扫描..."
    fi
fi

# 2. 获取本机 IP 和网段 (Windows Git Bash 兼容)
LOCAL_IP=""
# 先用 hostname -I (部分 Git Bash 支持)
if command -v hostname &> /dev/null; then
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi
# 不行就用 ipconfig
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP=$(ipconfig 2>/dev/null | grep -i 'IPv4' | head -1 | sed 's/.*: //' | tr -d '\r')
fi
# 还不行就 ping 广播方式
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP=$(ip addr 2>/dev/null | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1 | head -1)
fi

if [ -z "$LOCAL_IP" ]; then
    echo "❌ 无法检测本机 IP，请确保已连上手机热点"
    exit 1
fi

PREFIX=$(echo "$LOCAL_IP" | sed 's/\.[0-9]*$//')
echo "📡 本机 IP: $LOCAL_IP  →  扫描 $PREFIX.1 ~ $PREFIX.254"
echo "⏳ 快速扫描中..."

# 3. 并发扫描端口 80
FOUND=""
for i in $(seq 1 254); do
    IP="$PREFIX.$i"
    curl -s --connect-timeout 0.5 "http://$IP/light?state=idle" > /dev/null 2>&1 && {
        FOUND="$IP"
        echo ""
        echo "  ✅ 发现 ESP32 红绿灯！IP: $IP"
        break
    } &
    if [ $((i % 30)) -eq 0 ]; then
        wait
        [ -n "$FOUND" ] && break
    fi
done
wait

# 4. 更新 settings.json
if [ -n "$FOUND" ]; then
    sed -i "s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\/light/$FOUND\/light/g" "$SETTINGS"
    echo "  ✅ 已自动更新 settings.json → $FOUND"
else
    echo ""
    echo "  ❌ 没找到 ESP32"
    echo "  💡 请确认:"
    echo "     1. 电脑已连上手机热点"
    echo "     2. ESP32 已通电启动"
    echo "     3. 防火墙没有拦截 curl"
fi
