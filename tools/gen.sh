#!/bin/bash

# =============================================================================
# 妙码代码生成工具
# 支持配置文件驱动的代码生成
# =============================================================================

set -e  # 遇到错误立即退出

# 引入公共日志工具
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/logger.sh"

# 全局变量
MIAOMA_CONFIG_PROJECT_PATH=""
MIAOMA_DATABASE_FILE=""
MIAOMA_DATABASE_PATH=""  # 新增：数据库路径
OUTPUT_DIR=""
MIAOMA_ROOT=""
SHOW_PYTHON_LOGS="false"
TOOL_MODE="1"  # 新增：工具模式

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -o, --output DIR    指定输出目录（必需）"
    echo "  -h, --help          显示此帮助信息"
    echo ""
    echo "工具模式（在project.ini中配置）:"
    echo "  TOOL_MODE=1         使用gen-code命令（单文件模式）"
    echo "  TOOL_MODE=2         使用gen-project命令（工程模式）"
    echo ""
    echo "示例:"
    echo "  $0 -o /path/to/output        # 使用指定的输出目录"
    echo "  $0 --output ~/my-project     # 使用指定的输出目录"
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                if [[ -n "$2" ]] && [[ "$2" != -* ]]; then
                    OUTPUT_DIR="$2"
                    shift 2
                else
                    log_error "选项 $1 需要一个参数"
                    show_help
                    exit 1
                fi
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 检查必需的参数
    if [[ -z "$OUTPUT_DIR" ]]; then
        log_error "缺少必需的输出目录参数"
        show_help
        exit 1
    fi
}

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
            "MIAOMA_DATABASE_PATH")
                MIAOMA_DATABASE_PATH="$value"
                ;;
            "TOOL_MODE")
                TOOL_MODE="$value"
                ;;
            "SHOW_PYTHON_LOGS")
                SHOW_PYTHON_LOGS="$value"
                ;;
        esac
    done < "$config_file"
    
    # 验证必要的配置项
    if [[ -z "$MIAOMA_CONFIG_PROJECT_PATH" ]] || [[ -z "$MIAOMA_DATABASE_FILE" ]]; then
        log_error "配置文件中缺少必要的配置项 (MIAOMA_CONFIG_PROJECT_PATH, MIAOMA_DATABASE_FILE)"
        exit 1
    fi
    
    # 验证TOOL_MODE
    if [[ "$TOOL_MODE" != "1" ]] && [[ "$TOOL_MODE" != "2" ]]; then
        log_error "无效的TOOL_MODE值: $TOOL_MODE，必须是1或2"
        exit 1
    fi
    
    log_info "配置读取完成:"
    log_info "  工具模式: $TOOL_MODE"
    log_info "  项目路径: $MIAOMA_CONFIG_PROJECT_PATH"
    log_info "  数据库文件: $MIAOMA_DATABASE_FILE"
    log_info "  数据库路径: $MIAOMA_DATABASE_PATH"
    log_info "  输出目录: $OUTPUT_DIR"
    log_info "  显示Python日志: $SHOW_PYTHON_LOGS"
}

dump_config_info() {
    log_info "打印配置信息..."

    local dependencies=(
        "miaoma.py"
        "$MIAOMA_CONFIG_PROJECT_PATH"
        "$MIAOMA_DATABASE_FILE"
    )

    for dep in "${dependencies[@]}"; do
        if [[ ! -e "$dep" ]]; then
            log_error "依赖文件或目录不存在: $dep"
            exit 1
        fi
        log_info "✓ $dep"
    done

    # 打印配置信息
    log_info "配置信息:"
    log_info "  工具模式: $TOOL_MODE"
    log_info "  项目路径: $MIAOMA_CONFIG_PROJECT_PATH"
    log_info "  数据库文件: $MIAOMA_DATABASE_FILE"
    log_info "  数据库路径: $MIAOMA_DATABASE_PATH"
    log_info "  输出目录: $OUTPUT_DIR"
}

# 检查输出目录
check_output_directory() {
    # 如果输出目录是相对路径，则相对于miaoma根目录
    if [[ "$OUTPUT_DIR" != /* ]]; then
        OUTPUT_DIR="$MIAOMA_ROOT/$OUTPUT_DIR"
    fi
    
    log_info "输出目录: $OUTPUT_DIR"
    
    # 检查输出目录是否存在，不存在则创建
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        log_info "输出目录不存在，正在创建: $OUTPUT_DIR"
        if mkdir -p "$OUTPUT_DIR"; then
            log_info "✓ 输出目录创建成功"
        else
            log_error "无法创建输出目录: $OUTPUT_DIR"
            log_error "请检查路径权限或手动创建该目录"
            exit 1
        fi
    else
        log_info "✓ 输出目录已存在"
    fi

    # 删除输出目录中的旧文件
    log_info "删除输出目录中的旧文件: $OUTPUT_DIR/miaoma/artifacts"
    rm -rf "$OUTPUT_DIR"/miaoma/artifacts

    # 删除配置目录中的旧文件
    log_info "删除配置目录中的旧文件: $MIAOMA_CONFIG_PROJECT_PATH/config"
    rm -rf "$MIAOMA_CONFIG_PROJECT_PATH"/config

    log_info "✓ 输出目录检查通过"
}

# 执行代码生成
run_generation() {
    log_info "开始执行代码生成..."

    local cmd
    local temp_log_file="$MIAOMA_ROOT/tools/.temp_gen.log"
    
    # 根据TOOL_MODE选择不同的命令
    if [[ "$TOOL_MODE" == "1" ]]; then
        cmd="python3 miaoma.py gen-code --project-dir $MIAOMA_CONFIG_PROJECT_PATH -f $MIAOMA_DATABASE_FILE"
        log_info "使用gen-code命令（单文件模式）"
    elif [[ "$TOOL_MODE" == "2" ]]; then
        cmd="python3 miaoma.py gen-project --project-dir $MIAOMA_CONFIG_PROJECT_PATH -d $MIAOMA_DATABASE_PATH"
        log_info "使用gen-project命令（工程模式）"
    else
        log_error "无效的TOOL_MODE值: $TOOL_MODE"
        exit 1
    fi

    log_info "执行命令: $cmd"

    # 执行命令并捕获输出
    if [[ "$SHOW_PYTHON_LOGS" == "true" ]]; then
        log_info "执行命令: $cmd"
        if $cmd 2>&1 | tee "$temp_log_file"; then
            # 提取输出目录（只取第一个匹配项，避免重复）
            extracted_dir=$(grep "\[MIAOMA_OUTPUT_DIR\]" "$temp_log_file" | head -1 | sed 's/.*\[MIAOMA_OUTPUT_DIR\] 输出目录: //')
            if [[ -n "$extracted_dir" ]]; then
                # 构建完整的绝对路径
                full_output_dir="$MIAOMA_ROOT/$extracted_dir"
                echo "$full_output_dir" > "$MIAOMA_ROOT/tools/.last_output_dir"
                log_info "完整输出目录: $full_output_dir"
            fi
            log_success "代码生成完成！"
            log_info "生成的代码位于: $OUTPUT_DIR"
        else
            log_error "代码生成失败！"
            exit 1
        fi
    else
        # 静默执行，完全抑制输出
        if $cmd > "$temp_log_file" 2>&1; then
            # 提取输出目录（只取第一个匹配项）
            extracted_dir=$(grep "\[MIAOMA_OUTPUT_DIR\]" "$temp_log_file" | head -1 | sed 's/.*\[MIAOMA_OUTPUT_DIR\] 输出目录: //')
            if [[ -n "$extracted_dir" ]]; then
                # 构建完整的绝对路径
                full_output_dir="$MIAOMA_ROOT/$extracted_dir"
                echo "$full_output_dir" > "$MIAOMA_ROOT/tools/.last_output_dir"
                log_info "完整输出目录: $full_output_dir"
            fi
            log_success "代码生成完成！"
            log_info "生成的代码位于: $OUTPUT_DIR"
        else
            log_error "代码生成失败！"
            log_info "提示: 设置 SHOW_PYTHON_LOGS=true 查看详细错误信息"
            exit 1
        fi
    fi
    
    # 清理临时日志文件
    [[ -f "$temp_log_file" ]] && rm -f "$temp_log_file"
}

# 主函数
main() {
    log_title "妙码代码生成脚本 - 配置版本"
    echo

    # 解析命令行参数
    parse_arguments "$@"

    # 确保工作目录正确
    ensure_working_directory
    
    # 读取配置文件
    read_config
    
    # 检查输出目录
    check_output_directory

    # 执行代码生成
    run_generation
    
    log_success "所有操作完成！"
}

# 脚本入口
main "$@"
