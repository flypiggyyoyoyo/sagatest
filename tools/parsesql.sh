#!/bin/bash

# =============================================================================
# 妙码SQL解析工具
# 支持配置文件驱动的SQL解析
# =============================================================================

set -e  # 遇到错误立即退出

# 引入公共日志工具
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/logger.sh"

# 全局变量
MIAOMA_CONFIG_PROJECT_PATH=""
MIAOMA_DATABASE_FILE=""
OUTPUT_DIR=""
MIAOMA_ROOT=""
SHOW_PYTHON_LOGS="false"

# 设置默认值
DEFAULT_SQL_FILE="sql/t_merchant_store.sql"

# 解析命令行参数
SQL_FILE="$DEFAULT_SQL_FILE"
TABLE_NAME=""
VERBOSE=""
HELP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --file|-f)
            SQL_FILE="$2"
            shift 2
            ;;
        --table|-n)
            TABLE_NAME="--table $2"
            shift 2
            ;;
        --verbose)
            VERBOSE="--verbose"
            set_log_level "debug"
            shift
            ;;
        --help|-h)
            HELP="true"
            shift
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

# 确定并切换到miaoma根目录
ensure_working_directory() {
    local current_dir=$(pwd)
    local script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    
    log_info "当前工作目录: $current_dir"
    log_info "脚本所在目录: $script_dir"
    
    # 从脚本目录向上查找miaoma根目录
    local search_dir="$script_dir"
    while [[ "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/miaoma.py" ]] && [[ -d "$search_dir/src" ]] && [[ -d "$search_dir/assets" ]]; then
            MIAOMA_ROOT="$search_dir"
            break
        fi
        search_dir=$(dirname "$search_dir")
    done
    
    if [[ -z "$MIAOMA_ROOT" ]]; then
        log_error "无法找到 miaoma 项目根目录！"
        log_error "请确保脚本在 miaoma 项目目录结构中"
        exit 1
    fi
    
    log_info "找到 miaoma 根目录: $MIAOMA_ROOT"
    
    # 切换到根目录
    if [[ "$current_dir" != "$MIAOMA_ROOT" ]]; then
        log_info "切换工作目录到: $MIAOMA_ROOT"
        cd "$MIAOMA_ROOT"
    fi
    
    log_info "工作目录设置完成"
}

# 读取配置文件
read_config() {
    local config_file="$MIAOMA_ROOT/tools/project.ini"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        exit 1
    fi
    
    log_info "读取配置文件: $config_file"
    
    # 读取配置项
    while IFS='=' read -r key value; do
        # 跳过注释和空行
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        
        # 去除前后空格
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        case "$key" in
            "MIAOMA_CONFIG_PROJECT_PATH")
                MIAOMA_CONFIG_PROJECT_PATH="$value"
                ;;
            "MIAOMA_DATABASE_FILE")
                MIAOMA_DATABASE_FILE="$value"
                ;;
            "OUTPUT_DIR")
                OUTPUT_DIR="$value"
                ;;
            "SHOW_PYTHON_LOGS")
                SHOW_PYTHON_LOGS="$value"
                ;;
        esac
    done < "$config_file"
    
    # 验证必要的配置项
    if [[ -z "$MIAOMA_CONFIG_PROJECT_PATH" ]]; then
        log_error "配置文件中缺少必要的配置项 (MIAOMA_CONFIG_PROJECT_PATH)"
        exit 1
    fi
    
    log_info "配置读取完成:"
    log_info "  项目路径: $MIAOMA_CONFIG_PROJECT_PATH"
    log_info "  数据库文件: $MIAOMA_DATABASE_FILE"
    log_info "  输出目录: $OUTPUT_DIR"
    log_info "  显示Python日志: $SHOW_PYTHON_LOGS"
}

# 处理SQL文件路径
process_sql_file_path() {
    # 如果SQL文件是相对路径，则相对于项目目录
    if [[ "$SQL_FILE" != /* ]]; then
        SQL_FILE="$MIAOMA_CONFIG_PROJECT_PATH/$SQL_FILE"
    fi
    
    # 检查SQL文件是否存在
    if [[ ! -f "$SQL_FILE" ]]; then
        log_error "SQL文件不存在: $SQL_FILE"
        exit 1
    fi
    
    log_info "SQL文件: $SQL_FILE"
}

# 显示帮助信息
show_help() {
    log_title "妙码SQL解析工具"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --file <文件>, -f       指定SQL文件 (默认: $DEFAULT_SQL_FILE)"
    echo "  --table <表名>, -n      指定表名 (可选)"
    echo "  --verbose              显示详细信息"
    echo "  --help, -h             显示此帮助信息"
    echo ""
    echo "配置信息 (来自 project.ini):"
    echo "  项目路径: $MIAOMA_CONFIG_PROJECT_PATH"
    echo "  数据库文件: $MIAOMA_DATABASE_FILE"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认SQL文件"
    echo "  $0 --file sql/t_merchant_info.sql    # 指定SQL文件"
    echo "  $0 -f sql/t_user.sql --table t_user  # 指定文件和表名"
    echo "  $0 --verbose                          # 显示详细信息"
}

# 执行SQL解析
run_parse_sql() {
    log_info "开始执行SQL解析..."
    
    # 构建完整命令
    local cmd="python3 miaoma.py parse-sql --project-dir $MIAOMA_CONFIG_PROJECT_PATH -f $SQL_FILE"
    
    if [[ -n "$TABLE_NAME" ]]; then
        cmd="$cmd $TABLE_NAME"
    fi
    
    if [[ -n "$VERBOSE" ]]; then
        cmd="$cmd $VERBOSE"
    fi
    
    # 根据配置决定是否显示命令执行日志
    if [[ "$SHOW_PYTHON_LOGS" == "true" ]]; then
        log_info "执行命令: $cmd"
        if eval $cmd; then
            log_success "SQL解析完成！"
        else
            log_error "SQL解析失败！"
            exit 1
        fi
    else
        # 显示命令但不显示python输出
        log_debug "执行命令: $cmd"
        if eval $cmd > /dev/null 2>&1; then
            log_success "SQL解析完成！"
        else
            log_error "SQL解析失败！"
            log_info "提示: 设置 SHOW_PYTHON_LOGS=true 查看详细错误信息"
            exit 1
        fi
    fi
}

# 主函数
main() {
    # 显示帮助信息
    if [[ "$HELP" == "true" ]]; then
        # 需要先读取配置才能显示完整帮助
        ensure_working_directory
        read_config
        show_help
        exit 0
    fi
    
    log_title "妙码SQL解析工具 - 配置版本"
    echo
    
    # 确保工作目录正确
    ensure_working_directory
    
    # 读取配置文件
    read_config
    
    # 处理SQL文件路径
    process_sql_file_path
    
    # 执行SQL解析
    run_parse_sql
    
    log_success "所有操作完成！"
}

# 脚本入口
main "$@"