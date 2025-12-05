#!/bin/sh

# 项目打包脚本 - 只打包明确指定的文件和文件夹
# 用法: ./pack.sh [配置文件名]

# 默认配置
PACK_DIR="pack"
INCLUDE_PATTERNS=""

# 加载配置文件
load_config() {
    local config_file="${1:-deploy.conf}"
    
    if [ -f "$config_file" ]; then
        echo "加载配置文件: $config_file"
        parse_config_file "$config_file"
    else
        echo "错误: 未找到配置文件 $config_file"
        exit 1
    fi
}

# 解析配置文件
parse_config_file() {
    local config_file="$1"
    local in_include_array=0
    local include_items=""
    
    while IFS= read -r line; do
        # 移除注释和空白
        line=$(echo "$line" | sed 's/#.*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        
        if [ -z "$line" ]; then
            continue
        fi
        
        # 检查数组开始
        case "$line" in
            "INCLUDE_PATTERNS=("*)
                in_include_array=1
                line=$(echo "$line" | sed 's/INCLUDE_PATTERNS=(//')
                ;;
        esac
        
        # 处理数组内容
        if [ $in_include_array -eq 1 ]; then
            # 检查数组结束
            if echo "$line" | grep -q "^\s*)\s*$"; then
                in_include_array=0
                continue
            fi
            
            # 移除引号和逗号
            item=$(echo "$line" | sed "s/^['\"]//" | sed "s/['\"],*$//" | sed 's/,$//')
            if [ -n "$item" ]; then
                if [ -n "$include_items" ]; then
                    include_items="$include_items|$item"
                else
                    include_items="$item"
                fi
            fi
            
        else
            # 处理普通变量赋值
            case "$line" in
                PACK_DIR=*)
                    PACK_DIR=$(echo "$line" | cut -d= -f2- | sed "s/^['\"]//" | sed "s/['\"]$//")
                    ;;
            esac
        fi
    done < "$config_file"
    
    if [ -z "$include_items" ]; then
        echo "错误: 配置文件中未指定要打包的文件或文件夹"
        exit 1
    fi
    
    INCLUDE_PATTERNS="$include_items"
}

# 创建打包目录
create_pack_dir() {
    if [ ! -d "$PACK_DIR" ]; then
        echo "创建打包目录: $PACK_DIR"
        mkdir -p "$PACK_DIR"
        if [ $? -ne 0 ]; then
            echo "错误: 无法创建打包目录 $PACK_DIR"
            exit 1
        fi
    fi
}

# 写入文件函数（覆盖模式）
write_to_file() {
    local file_path="$1"
    local content="$2"
    
    # 创建目录（如果不存在）
    local dir_path=$(dirname "$file_path")
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
    fi
    
    # 写入文件（覆盖模式）
    echo "$content" > "$file_path"
    
    if [ $? -eq 0 ]; then
        echo "✓ 文件写入成功: $file_path"
        return 0
    else
        echo "✗ 文件写入失败: $file_path"
        return 1
    fi
}
# 读取文件并判断内容是否等于指定字符串
check_file_content() {
    local file_path="$1"
    local expected_content="$2"
    
    # 检查文件是否存在
    if [ ! -f "$file_path" ]; then
        echo "文件不存在: $file_path"
        return 2  # 文件不存在的返回码
    fi
    
    # 读取文件内容（去除末尾换行符）
    local file_content=$(cat "$file_path" | tr -d '\n')
    local expected_clean=$(echo "$expected_content" | tr -d '\n')
    
    # 比较内容
    if [ "$file_content" = "$expected_clean" ]; then
        echo "✓ 文件内容匹配: $file_path"
        return 0
    else
        echo "✗ 文件内容不匹配: $file_path"
        echo "  期望: '$expected_clean'"
        echo "  实际: '$file_content'"
        return 1
    fi
}

# 复制文件或目录
copy_item() {
    local src="$1"
    local dest="$2"
    
    if [ -d "$src" ]; then
        echo "复制目录: $src -> $dest"
        mkdir -p "$dest"
        cp -r "$src"/* "$dest/" 2>/dev/null
    elif [ -f "$src" ]; then
        echo "复制文件: $src -> $dest"
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest" 2>/dev/null
    fi
}

# 主打包函数
pack_project() {
    echo "开始打包项目..."
    echo "打包目录: $PACK_DIR"
    echo "包含模式: $INCLUDE_PATTERNS"
    echo "----------------------------------------"
    
    # 清空打包目录（如果存在）
    if [ -d "$PACK_DIR" ]; then
        rm -rf "$PACK_DIR"/*
    fi
    
    # 处理包含模式
    OLD_IFS="$IFS"
    IFS="|"
    set -- $INCLUDE_PATTERNS
    IFS="$OLD_IFS"
    
    for pattern; do
        # 检查文件或目录是否存在
        if [ -e "$pattern" ]; then
            # 获取目标路径
            if [ "$pattern" = "." ] || [ "$pattern" = "./" ]; then
                # 复制当前目录所有内容
                for item in * .[!.]* ..?*; do
                    if [ "$item" != "." ] && [ "$item" != ".." ] && [ "$item" != "$PACK_DIR" ]; then
                        copy_item "$item" "$PACK_DIR/$item"
                    fi
                done
            else
                # 复制指定文件或目录
                copy_item "$pattern" "$PACK_DIR/$pattern"
            fi
        else
            echo "警告: 文件或目录不存在: $pattern"
        fi
    done
    
    echo "----------------------------------------"
    echo "打包完成！文件已保存到: $PACK_DIR/"
}

# 显示帮助信息
show_help() {
    echo "项目打包脚本 - 只打包明确指定的文件和文件夹"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -c, --config FILE   指定配置文件（默认: deploy.conf）"
    echo "  -h, --help          显示帮助信息"
    echo ""
    echo "配置文件示例 (deploy.conf):"
    echo "  PACK_DIR=\"pack\""
    echo "  INCLUDE_PATTERNS=("
    echo "    \"config.lua\""
    echo "    \"etc\""
    echo "    \"lualib\""
    echo "    \"server\""
    echo "    \"service\""
    echo "    \"shell\""
    echo "    \"script\""
    echo "    \"skynet/cservice\""
    echo "    \"skynet/luaclib\""
    echo "    \"skynet/lualib\""
    echo "    \"skynet/service\""
    echo "    \"skynet/skynet\""
    echo "    \"start_*.sh\""
    echo "  )"
}

# 解析命令行参数
parse_arguments() {
    while [ $# -gt 0 ]; do
        case $1 in
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主程序
main() {
    local config_file="deploy.conf"
    
    # 解析命令行参数
    parse_arguments "$@"
    
    # 加载配置
    load_config "$config_file"
    
    # 创建打包目录
    create_pack_dir
    
    # 执行打包
    pack_project

}

# 运行主程序
main "$@"