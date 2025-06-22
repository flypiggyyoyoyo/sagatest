#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=============================================================================
妙码数据导出工具 - Python实现
支持配置文件驱动的数据导出
=============================================================================
"""

import os
import sys
import argparse
import subprocess
import configparser
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any


class Logger:
    """日志工具类"""
    
    # 颜色定义
    COLORS = {
        'RED': '\033[0;31m',
        'GREEN': '\033[0;32m',
        'YELLOW': '\033[1;33m',
        'BLUE': '\033[0;34m',
        'PURPLE': '\033[0;35m',
        'CYAN': '\033[0;36m',
        'NC': '\033[0m',  # No Color
    }
    
    # 日志级别
    LEVELS = {
        'DEBUG': 0,
        'INFO': 1,
        'WARN': 2,
        'ERROR': 3,
    }
    
    def __init__(self, level: str = 'INFO', show_timestamp: bool = False):
        self.level = self.LEVELS.get(level.upper(), self.LEVELS['INFO'])
        self.show_timestamp = show_timestamp
    
    def _format_message(self, level_name: str, message: str) -> str:
        """格式化日志消息"""
        timestamp = f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] " if self.show_timestamp else ""
        return f"{timestamp}{level_name} {message}"
    
    def debug(self, message: str):
        if self.level <= self.LEVELS['DEBUG']:
            print(self._format_message(f"{self.COLORS['CYAN']}[DEBUG]{self.COLORS['NC']}", message))
    
    def info(self, message: str):
        if self.level <= self.LEVELS['INFO']:
            print(self._format_message(f"{self.COLORS['BLUE']}[INFO]{self.COLORS['NC']}", message))
    
    def warn(self, message: str):
        if self.level <= self.LEVELS['WARN']:
            print(self._format_message(f"{self.COLORS['YELLOW']}[WARN]{self.COLORS['NC']}", message))
    
    def error(self, message: str):
        if self.level <= self.LEVELS['ERROR']:
            print(self._format_message(f"{self.COLORS['RED']}[ERROR]{self.COLORS['NC']}", message), file=sys.stderr)
    
    def success(self, message: str):
        if self.level <= self.LEVELS['INFO']:
            print(self._format_message(f"{self.COLORS['GREEN']}[SUCCESS]{self.COLORS['NC']}", message))
    
    def title(self, title: str):
        print(f"{self.COLORS['PURPLE']}=== {title} ==={self.COLORS['NC']}")
    
    def set_level(self, level: str):
        """设置日志级别"""
        self.level = self.LEVELS.get(level.upper(), self.LEVELS['INFO'])


class MiaomaDumper:
    """妙码数据导出器"""
    
    def __init__(self):
        self.logger = Logger()
        self.miaoma_root: Optional[Path] = None
        self.config: Dict[str, Any] = {}
        
        # 默认值
        self.default_table = "t_merchant_store"
    
    def ensure_working_directory(self) -> bool:
        """确定并切换到miaoma根目录"""
        current_dir = Path.cwd()
        script_dir = Path(__file__).parent.absolute()
        
        self.logger.info(f"当前工作目录: {current_dir}")
        self.logger.info(f"脚本所在目录: {script_dir}")
        
        # 从脚本目录向上查找miaoma根目录
        search_dir = script_dir
        while search_dir != search_dir.parent:
            if (search_dir / "miaoma.py").exists() and \
               (search_dir / "src").is_dir() and \
               (search_dir / "assets").is_dir():
                self.miaoma_root = search_dir
                break
            search_dir = search_dir.parent
        
        if not self.miaoma_root:
            self.logger.error("无法找到 miaoma 项目根目录！")
            self.logger.error("请确保脚本在 miaoma 项目目录结构中")
            return False
        
        self.logger.info(f"找到 miaoma 根目录: {self.miaoma_root}")
        
        # 切换到根目录
        if current_dir != self.miaoma_root:
            self.logger.info(f"切换工作目录到: {self.miaoma_root}")
            os.chdir(self.miaoma_root)
        
        self.logger.info("工作目录设置完成")
        return True
    
    def read_config(self) -> bool:
        """读取配置文件"""
        config_file = self.miaoma_root / "tools" / "project.ini"
        
        if not config_file.exists():
            self.logger.error(f"配置文件不存在: {config_file}")
            return False
        
        self.logger.info(f"读取配置文件: {config_file}")
        
        try:
            # 手动解析INI文件（简单格式）
            with open(config_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    
                    if '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip()
                        
                        if key in ['MIAOMA_CONFIG_PROJECT_PATH', 'MIAOMA_DATABASE_FILE', 
                                  'OUTPUT_DIR', 'SHOW_PYTHON_LOGS']:
                            self.config[key] = value
            
            # 验证必要的配置项
            if not self.config.get('MIAOMA_CONFIG_PROJECT_PATH'):
                self.logger.error("配置文件中缺少必要的配置项 (MIAOMA_CONFIG_PROJECT_PATH)")
                return False
            
            self.logger.info("配置读取完成:")
            self.logger.info(f"  项目路径: {self.config.get('MIAOMA_CONFIG_PROJECT_PATH', '')}")
            self.logger.info(f"  数据库文件: {self.config.get('MIAOMA_DATABASE_FILE', '')}")
            self.logger.info(f"  输出目录: {self.config.get('OUTPUT_DIR', '')}")
            self.logger.info(f"  显示Python日志: {self.config.get('SHOW_PYTHON_LOGS', 'false')}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"读取配置文件失败: {e}")
            return False
    
    def show_help(self, prog_name: str):
        """显示帮助信息"""
        self.logger.title("妙码数据导出工具")
        print(f"用法: {prog_name} [选项]")
        print()
        print("选项:")
        print(f"  --table <表名>, -n      指定表名 (默认: {self.default_table})")
        print("  --format <格式>         输出格式: flat | json (默认: flat)")
        print("  --filter-prefix <字符串>, --prefix  只显示以指定前缀开头的字段")
        print("  --filter-include <字符串>, --include 只显示键值包含指定字符串的字段")
        print("  --filter-exclude <字符串>, --exclude 排除键值包含指定字符串的字段")
        print("  --no-derived           跳过衍生配置处理")
        print("  --verbose              显示详细信息")
        print("  --help, -h             显示此帮助信息")
        print()
        print("配置信息 (来自 project.ini):")
        print(f"  项目路径: {self.config.get('MIAOMA_CONFIG_PROJECT_PATH', '')}")
        print(f"  数据库文件: {self.config.get('MIAOMA_DATABASE_FILE', '')}")
        print()
        print("示例:")
        print(f"  {prog_name}                                    # 使用默认表名")
        print(f"  {prog_name} --table t_merchant_info            # 指定表名")
        print(f"  {prog_name} --format json                      # JSON格式输出")
        print(f"  {prog_name} --prefix table.sql                 # 只显示以table.sql开头的字段")
        print(f"  {prog_name} --include naming                   # 只显示包含'naming'的字段")
        print(f"  {prog_name} --exclude derived                  # 排除包含'derived'的字段")
        print(f"  {prog_name} --prefix table --exclude derived   # 组合过滤")
    
    def run_dump(self, args) -> bool:
        """执行数据导出"""
        self.logger.info("开始执行数据导出...")
        
        # 构建完整命令
        cmd = [
            "python3", "miaoma.py", "dump-table-meta",
            "--project-dir", self.config['MIAOMA_CONFIG_PROJECT_PATH'],
            "-n", args.table
        ]
        
        if args.format:
            cmd.extend(["--format", args.format])
        
        if args.filter_prefix:
            cmd.extend(["--filter-prefix", args.filter_prefix])
        
        if args.filter_include:
            cmd.extend(["--filter-include", args.filter_include])
        
        if args.filter_exclude:
            cmd.extend(["--filter-exclude", args.filter_exclude])
        
        if args.no_derived:
            cmd.append("--no-derived")
        
        if args.verbose:
            cmd.append("--verbose")
        
        # 根据配置决定是否显示命令执行日志
        show_logs = self.config.get('SHOW_PYTHON_LOGS', 'false').lower() == 'true'
        
        try:
            if show_logs:
                self.logger.info(f"执行命令: {' '.join(cmd)}")
                result = subprocess.run(cmd, check=True)
            else:
                self.logger.debug(f"执行命令: {' '.join(cmd)}")
                result = subprocess.run(cmd, check=True, capture_output=True, text=True)
                if result.stdout:
                    print(result.stdout, end='')
            
            self.logger.success("数据导出完成！")
            return True
            
        except subprocess.CalledProcessError as e:
            self.logger.error("数据导出失败！")
            if not show_logs:
                self.logger.info("提示: 设置 SHOW_PYTHON_LOGS=true 查看详细错误信息")
                if e.stderr:
                    self.logger.error(f"错误信息: {e.stderr}")
            return False
        except Exception as e:
            self.logger.error(f"执行命令时发生错误: {e}")
            return False
    
    def main(self):
        """主函数"""
        # 解析命令行参数
        parser = argparse.ArgumentParser(
            description='妙码数据导出工具',
            add_help=False  # 自定义帮助
        )
        
        parser.add_argument('--table', '-n', default=self.default_table,
                          help=f'指定表名 (默认: {self.default_table})')
        parser.add_argument('--format', choices=['flat', 'json'],
                          help='输出格式: flat | json (默认: flat)')
        parser.add_argument('--filter-prefix', '--prefix',
                          help='只显示以指定前缀开头的字段')
        parser.add_argument('--filter-include', '--include',
                          help='只显示键值包含指定字符串的字段')
        parser.add_argument('--filter-exclude', '--exclude',
                          help='排除键值包含指定字符串的字段')
        parser.add_argument('--no-derived', action='store_true',
                          help='跳过衍生配置处理')
        parser.add_argument('--verbose', action='store_true',
                          help='显示详细信息')
        parser.add_argument('--help', '-h', action='store_true',
                          help='显示此帮助信息')
        
        args = parser.parse_args()
        
        # 设置日志级别
        if args.verbose:
            self.logger.set_level('DEBUG')
        
        # 显示帮助信息
        if args.help:
            # 需要先读取配置才能显示完整帮助
            if not self.ensure_working_directory():
                sys.exit(1)
            if not self.read_config():
                sys.exit(1)
            self.show_help(sys.argv[0])
            sys.exit(0)
        
        self.logger.title("妙码数据导出工具 - 配置版本")
        print()
        
        # 确保工作目录正确
        if not self.ensure_working_directory():
            sys.exit(1)
        
        # 读取配置文件
        if not self.read_config():
            sys.exit(1)
        
        # 执行数据导出
        if not self.run_dump(args):
            sys.exit(1)
        
        self.logger.success("所有操作完成！")


if __name__ == '__main__':
    dumper = MiaomaDumper()
    dumper.main()