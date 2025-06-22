#!/bin/bash

# =============================================================================
# 妙码工具 - 公共日志工具
# 提供统一的日志输出功能，支持不同级别的日志和颜色显示
# =============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志级别定义
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# 当前日志级别（默认为INFO）
CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# 是否显示时间戳（默认不显示）
SHOW_TIMESTAMP=${SHOW_TIMESTAMP:-false}

# 获取时间戳
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 格式化日志消息
format_log_message() {
    local level="$1"
    local message="$2"
    local timestamp=""
    
    if [[ "$SHOW_TIMESTAMP" == "true" ]]; then
        timestamp="[$(get_timestamp)] "
    fi
    
    echo "${timestamp}${level} ${message}"
}

# DEBUG级别日志
log_debug() {
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        echo -e "$(format_log_message "${CYAN}[DEBUG]${NC}" "$1")"
    fi
}

# INFO级别日志
log_info() {
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        echo -e "$(format_log_message "${BLUE}[INFO]${NC}" "$1")"
    fi
}

# WARN级别日志
log_warn() {
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]]; then
        echo -e "$(format_log_message "${YELLOW}[WARN]${NC}" "$1")"
    fi
}

# ERROR级别日志
log_error() {
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]]; then
        echo -e "$(format_log_message "${RED}[ERROR]${NC}" "$1")" >&2
    fi
}

# SUCCESS级别日志
log_success() {
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        echo -e "$(format_log_message "${GREEN}[SUCCESS]${NC}" "$1")"
    fi
}

# 设置日志级别
set_log_level() {
    case "$1" in
        "debug"|"DEBUG")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
            ;;
        "info"|"INFO")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
            ;;
        "warn"|"WARN")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_WARN
            ;;
        "error"|"ERROR")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR
            ;;
        *)
            log_error "无效的日志级别: $1"
            log_error "支持的级别: debug, info, warn, error"
            return 1
            ;;
    esac
}

# 启用时间戳
enable_timestamp() {
    SHOW_TIMESTAMP=true
}

# 禁用时间戳
disable_timestamp() {
    SHOW_TIMESTAMP=false
}

# 输出分隔线
log_separator() {
    echo -e "${BLUE}================================================${NC}"
}

# 输出标题
log_title() {
    local title="$1"
    echo -e "${PURPLE}=== $title ===${NC}"
}
            