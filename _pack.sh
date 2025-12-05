#!/bin/bash

# 配置部分 - 默认值（当没有参数传入时使用）
PACKAGE_PREFIX="skynet"         # 压缩包名前缀
TARGET_DIRS=(3rd etc lualib server service skynet)  # 要打包的目录列表（去掉引号）
TARGET_FILES=(moon moon.conf start_monitor.sh start_moon.sh start_rank.sh)  # 要打包的文件列表
OUTPUT_FORMAT="tar.gz"         # 打包格式 (tar.gz 或 zip)
OUTPUT_DIR="."                 # 默认输出到当前目录
SAFE_MODE="unsafe"      # 默认打包模式 unsafe 或 safe
WORK_PATH="."      # 默认工作路径为当前目录

# 解析参数
while getopts "p:f:o:s:w:" opt; do
  case $opt in
    p) PACKAGE_PREFIX="$OPTARG" ;;
    f) OUTPUT_FORMAT="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    s) SAFE_MODE="$OPTARG" ;;
    w) WORK_PATH="$OPTARG" ;;
    *) echo "无效选项: -$OPTARG" >&2; exit 1 ;;
  esac
done

# 确保输出目录存在（相对于当前工作目录）
mkdir -p "$OUTPUT_DIR"

# 获取当前时间并格式化
TIMESTAMP=$(date "+%Y-%m-%d-%H-%M-%S")
OUTPUT_NAME="${OUTPUT_DIR}/${PACKAGE_PREFIX}-${TIMESTAMP}.${OUTPUT_FORMAT}"

# 检查多个文件是否存在并提示
check_encryption_files() {
    if [ $SAFE_MODE != "safe" ]; then
        echo "⚠️  警告:当前正在打包未加密代码，是否继续？ (y/N)"
        read -r user_input
        
        user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')
        
        if [ "$user_input" != "y" ] && [ "$user_input" != "yes" ]; then
            echo "用户取消操作，程序退出。"
            exit 1
        fi
        PACKAGE_PREFIX="${PACKAGE_PREFIX}-unsafe"
        OUTPUT_NAME="${OUTPUT_DIR}/${PACKAGE_PREFIX}-${TIMESTAMP}.${OUTPUT_FORMAT}"
    fi
}

# 打包函数
function create_package() {
    echo "正在打包..."
    echo "工作路径: $WORK_PATH"
    
    # 保存当前目录
    local original_dir=$(pwd)
    
    # 切换到工作目录
    cd "$WORK_PATH" || {
        echo "错误: 无法切换到工作目录 '$WORK_PATH'"
        exit 1
    }
    
    # 构建有效的目录和文件列表
    local valid_dirs=()
    for dir in "${TARGET_DIRS[@]}"; do
        if [ -e "$dir" ]; then
            valid_dirs+=("$dir")
        else
            echo "警告: '$dir' 不存在，已跳过"
        fi
    done
    
    local valid_files=()
    for file in "${TARGET_FILES[@]}"; do
        if [ -e "$file" ]; then
            valid_files+=("$file")
        else
            echo "警告: '$file' 不存在，已跳过"
        fi
    done
    
    # 如果没有有效的文件或目录，则报错
    if [ ${#valid_dirs[@]} -eq 0 ] && [ ${#valid_files[@]} -eq 0 ]; then
        echo "错误: 没有有效的文件或目录可打包!也许你该用 sh pack_mini.sh 先进行打包!"
        cd "$original_dir"  # 返回原目录
        exit 1
    fi

    # 使用绝对路径确保输出文件在正确的位置
    local absolute_output_path="${original_dir}/${OUTPUT_NAME}"
    
    if [ "$OUTPUT_FORMAT" == "tar.gz" ]; then
        tar -czf "$absolute_output_path" "${valid_dirs[@]}" "${valid_files[@]}" 2>/dev/null
    elif [ "$OUTPUT_FORMAT" == "zip" ]; then
        zip -r "$absolute_output_path" "${valid_dirs[@]}" "${valid_files[@]}" >/dev/null
    else
        echo "错误: 不支持的打包格式 '$OUTPUT_FORMAT'"
        cd "$original_dir"  # 返回原目录
        exit 1
    fi

    if [ $? -eq 0 ]; then
        echo "打包完成: $(du -sh "$absolute_output_path" 2>/dev/null | cut -f1)"
        echo "输出文件: $absolute_output_path"
    else
        echo "打包失败!"
        cd "$original_dir"  # 返回原目录
        exit 1
    fi
    
    # 返回原目录
    cd "$original_dir"
}

# 主程序
echo "===== 打包脚本 ====="
check_encryption_files
create_package