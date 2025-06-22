#!/bin/bash

# =============================================================================
# 妙码数据导出工具
# 支持配置文件驱动的数据导出
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
DEFAULT_TABLE="t_merchant_store"

# 解析命令行参数
TABLE="$DEFAULT_TABLE"
FORMAT=""
FILTER_PREFIX=""
FILTER_INCLUDE=""
FILTER_EXCLUDE=""
NO_DERIVED=""
VERBOSE=""
HELP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --table|-n)
            TABLE="$2"
            shift 2
            ;;
        --format)
            FORMAT="--format $2"
            shift 2
            ;;
        --filter-prefix)
            FILTER_PREFIX="--filter-prefix $2"
            shift 2
            ;;
        --prefix)
            FILTER_PREFIX="--prefix $2"
            shift 2
            ;;
        --filter-include)
            FILTER_INCLUDE="--filter-include $2"
            shift 2
            ;;
        --include)
            FILTER_INCLUDE="--include $2"
            shift 2
            ;;
        --filter-exclude)
            FILTER_EXCLUDE="--filter-exclude $2"
            shift 2
            ;;
        --exclude)
            FILTER_EXCLUDE="--exclude $2"
            shift 2
            ;;
        --no-derived)
            NO_DERIVED="--no-derived"
            shift
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

# 显示帮助信息
show_help() {
    log_title "妙码数据导出工具"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --table <表名>, -n      指定表名 (默认: $DEFAULT_TABLE)"
    echo "  --format <格式>         输出格式: flat | json (默认: flat)"
    echo "  --filter-prefix <字符串>, --prefix  只显示以指定前缀开头的字段"
    echo "  --filter-include <字符串>, --include 只显示键值包含指定字符串的字段"
    echo "  --filter-exclude <字符串>, --exclude 排除键值包含指定字符串的字段"
    echo "  --no-derived           跳过衍生配置处理"
    echo "  --verbose              显示详细信息"
    echo "  --help, -h             显示此帮助信息"
    echo ""
    echo "配置信息 (来自 project.ini):"
    echo "  项目路径: $MIAOMA_CONFIG_PROJECT_PATH"
    echo "  数据库文件: $MIAOMA_DATABASE_FILE"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认表名"
    echo "  $0 --table t_merchant_info            # 指定表名"
    echo "  $0 --format json                      # JSON格式输出"
    echo "  $0 --prefix table.sql                 # 只显示以table.sql开头的字段"
    echo "  $0 --include naming                   # 只显示包含'naming'的字段"
    echo "  $0 --exclude derived                  # 排除包含'derived'的字段"
    echo "  $0 --prefix table --exclude derived   # 组合过滤"
}

# 执行数据导出
run_dump() {
    log_info "开始执行数据导出..."
    
    # 构建完整命令
    local cmd="python3 miaoma.py dump-table-meta --project-dir $MIAOMA_CONFIG_PROJECT_PATH -n $TABLE"
    
    if [[ -n "$FORMAT" ]]; then
        cmd="$cmd $FORMAT"
    fi
    
    if [[ -n "$FILTER_PREFIX" ]]; then
        cmd="$cmd $FILTER_PREFIX"
    fi
    
    if [[ -n "$FILTER_INCLUDE" ]]; then
        cmd="$cmd $FILTER_INCLUDE"
    fi
    
    if [[ -n "$FILTER_EXCLUDE" ]]; then
        cmd="$cmd $FILTER_EXCLUDE"
    fi
    
    if [[ -n "$NO_DERIVED" ]]; then
        cmd="$cmd $NO_DERIVED"
    fi
    
    if [[ -n "$VERBOSE" ]]; then
        cmd="$cmd $VERBOSE"
    fi
    
    # 根据配置决定是否显示命令执行日志
    if [[ "$SHOW_PYTHON_LOGS" == "true" ]]; then
        log_info "执行命令: $cmd"
        if eval $cmd; then
            log_success "数据导出完成！"
        else
            log_error "数据导出失败！"
            exit 1
        fi
    else
        # 显示命令但不显示python输出
        log_debug "执行命令: $cmd"
        if eval $cmd > /dev/null 2>&1; then
            log_success "数据导出完成！"
        else
            log_error "数据导出失败！"
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
    
    log_title "妙码数据导出工具 - 配置版本"
    echo
    
    # 确保工作目录正确
    ensure_working_directory
    
    # 读取配置文件
    read_config
    
    # 执行数据导出
    run_dump
    
    log_success "所有操作完成！"
}

# 脚本入口
main "$@"