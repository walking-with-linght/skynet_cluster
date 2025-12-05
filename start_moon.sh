#!/bin/bash

# 配置参数
PORT=60029
APP_NAME="moon"
LOG_DIR="./log"
MAX_LOG_FILES=10

# 创建日志目录
mkdir -p "$LOG_DIR"

# 生成带时间戳的日志文件名
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
LOG_FILE="${LOG_DIR}/${APP_NAME}_${TIMESTAMP}.log"

echo "🚀 开始部署 $APP_NAME..."

# 函数：检查端口是否被占用
check_port() {
    if sudo lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
        return 0
    else
        return 1
    fi
}

# 函数：优雅停止进程
stop_process() {
    echo "正在停止旧的 $APP_NAME 进程..."
    
    # 尝试优雅停止
    pids=$(sudo lsof -ti:$PORT 2>/dev/null)
    if [ -n "$pids" ]; then
        echo "找到进程: $pids"
        sudo kill $pids 2>/dev/null
        
        # 等待最多5秒
        for i in {1..5}; do
            if check_port; then
                sleep 1
                echo "等待进程退出... ($i/5)"
            else
                echo "进程已退出"
                return
            fi
        done
        
        # 强制杀死
        echo "强制杀死进程..."
        sudo kill -9 $pids 2>/dev/null
        sleep 1
    else
        echo "没有找到运行中的 $APP_NAME 进程"
    fi
}

# 停止旧进程
stop_process

# 再次确认端口是否释放
if check_port; then
    echo "❌ 端口 $PORT 仍然被占用，无法启动"
    exit 1
fi

echo "启动新的 $APP_NAME 进程..."
echo "📝 日志文件: $LOG_FILE"

# 切换到脚本所在目录，确保相对路径正确
cd "$(dirname "$0")"

# 启动新进程
nohup ./$APP_NAME > "$LOG_FILE" 2>&1 &
APP_PID=$!

# 等待进程启动
sleep 3

# 检查启动状态
if check_port && ps -p $APP_PID > /dev/null 2>&1; then
    echo "✅ $APP_NAME 启动成功!"
    echo "📋 进程ID: $APP_PID"
    echo "🌐 监听端口: $PORT"
    echo "📝 日志文件: $LOG_FILE"
    
    # 创建当前日志软链接（使用绝对路径）
    ln -sf "$(pwd)/$LOG_FILE" "$(pwd)/${APP_NAME}_current.log"
    echo "🔗 当前日志链接: ${APP_NAME}_current.log"
    
    # 清理旧日志文件（保留最新的10个）
    cd "$LOG_DIR"
    ls -t ${APP_NAME}_*.log 2>/dev/null | tail -n +$(($MAX_LOG_FILES + 1)) | xargs rm -f 2>/dev/null
    cd - >/dev/null
    
else
    echo "❌ $APP_NAME 启动失败"
    echo "请查看日志文件: $LOG_FILE"
    tail -20 "$LOG_FILE"
    exit 1
fi

echo ""
echo "🎉 部署完成!"
echo "📋 使用以下命令查看日志:"
echo "tail -f $LOG_FILE"
echo "或者: tail -f ${APP_NAME}_current.log"

# 显示日志文件的实际位置
echo ""
echo "📁 日志文件位置: $(pwd)/$LOG_FILE"