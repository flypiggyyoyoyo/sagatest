#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
妙码代码生成工具 - Python实现
支持配置文件驱动的代码生成
"""

import sys
import os
import argparse
import subprocess
import re
import tempfile
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any


class Logger:
    """日志工具类"""
    
    # 颜色定义
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color
    
    # 日志级别
    DEBUG = 0
    INFO = 1
    WARN = 2
    ERROR = 3
    
    def __init__(self, level: int = INFO, show_timestamp: bool = False):
        self.level = level
        self.show_timestamp = show_timestamp
    
    def _format_message(self, level_name: str, message: str) -> str:
        """格式化日志消息"""
        timestamp = f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] " if self.show_timestamp else ""
        return f"{timestamp}{level_name} {message}"
    
    def debug(self, message: str):
        if self.level <= self.DEBUG:
            print(self._format_message(f"{self.CYAN}[DEBUG]{self.NC}", message))
    
    def info(self, message: str):
        if self.level <= self.INFO:
            print(self._format_message(f"{self.BLUE}[INFO]{self.NC}", message))
    
    def warn(self, message: str):
        if self.level <= self.WARN:
            print(self._format_message(f"{self.YELLOW}[WARN]{self.NC}", message))
    
    def error(self, message: str):
        if self.level <= self.ERROR:
            print(self._format_message(f"{self.RED}[ERROR]{self.NC}", message), file=sys.stderr)
    
    def success(self, message: str):
        if self.level <= self.INFO:
            print(self._format_message(f"{self.GREEN}[SUCCESS]{self.NC}", message))
    
    def title(self, title: str):
        print(f"{self.PURPLE}=== {title} ==={self.NC}")


class MiaomaGenerator:
    """妙码代码生成器"""
    
    def __init__(self):
        self.logger = Logger()
        self.miaoma_root: Optional[Path] = None
        self.output_dir: Optional[Path] = None
        self.config: Dict[str, Any] = {}
    
    def show_help(self, prog_name: str):
        """显示帮助信息"""
        help_text = f"""用法: {prog_name} [选项]
选项:
  -o, --output DIR    指定输出目录（必需）
  -h, --help          显示此帮助信息

工具模式（在project.ini中配置）:
  TOOL_MODE=1         使用gen-code命令（单文件模式）
  TOOL_MODE=2         使用gen-project命令（工程模式）

示例:
  {prog_name} -o /path/to/output        # 使用指定的输出目录
  {prog_name} --output ~/my-project     # 使用指定的输出目录"""
        print(help_text)
    
    def parse_arguments(self) -> argparse.Namespace:
        """解析命令行参数"""
        parser = argparse.ArgumentParser(add_help=False)
        parser.add_argument('-o', '--output', required=True, help='指定输出目录（必需）')
        parser.add_argument('-h', '--help', action='store_true', help='显示此帮助信息')
        
        args = parser.parse_args()
        
        if args.help:
            self.show_help(sys.argv[0])
            sys.exit(0)
        
        return args
    
    def ensure_working_directory(self):
        """确定并切换到miaoma根目录"""
        current_dir = Path.cwd()
        script_dir = Path(__file__).parent.absolute()
        
        self.logger.info(f"当前工作目录: {current_dir}")
        self.logger.info(f"脚本所在目录: {script_dir}")
        
        # 从脚本目录向上查找miaoma根目录
        search_dir = script_dir
        while search_dir != search_dir.parent:
            if (search_dir / 'miaoma.py').exists() and \
               (search_dir / 'src').is_dir() and \
               (search_dir / 'assets').is_dir():
                self.miaoma_root = search_dir
                break
            search_dir = search_dir.parent
        
        if not self.miaoma_root:
            self.logger.error("无法找到 miaoma 项目根目录！")
            self.logger.error("请确保脚本在 miaoma 项目目录结构中")
            sys.exit(1)
        
        self.logger.info(f"找到 miaoma 根目录: {self.miaoma_root}")
        
        # 切换到根目录
        if current_dir != self.miaoma_root:
            self.logger.info(f"切换工作目录到: {self.miaoma_root}")
            os.chdir(self.miaoma_root)
        
        self.logger.info("工作目录设置完成")
    
    def read_config(self):
        """读取配置文件"""
        config_file = self.miaoma_root / 'tools' / 'project.ini'
        
        if not config_file.exists():
            self.logger.error(f"配置文件不存在: {config_file}")
            sys.exit(1)
        
        self.logger.info(f"读取配置文件: {config_file}")
        
        # 读取配置项
        with open(config_file, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                # 跳过注释和空行
                if line.startswith('#') or not line:
                    continue
                
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    
                    if key in ['MIAOMA_CONFIG_PROJECT_PATH', 'MIAOMA_DATABASE_FILE', 
                              'MIAOMA_DATABASE_PATH', 'TOOL_MODE', 'SHOW_PYTHON_LOGS']:
                        self.config[key] = value
        
        # 验证必要的配置项
        required_keys = ['MIAOMA_CONFIG_PROJECT_PATH', 'MIAOMA_DATABASE_FILE']
        for key in required_keys:
            if key not in self.config:
                self.logger.error(f"配置文件中缺少必要的配置项: {key}")
                sys.exit(1)
        
        # 验证TOOL_MODE
        tool_mode = self.config.get('TOOL_MODE', '1')
        if tool_mode not in ['1', '2']:
            self.logger.error(f"无效的TOOL_MODE值: {tool_mode}，必须是1或2")
            sys.exit(1)
        
        self.logger.info("配置读取完成:")
        self.logger.info(f"  工具模式: {self.config.get('TOOL_MODE', '1')}")
        self.logger.info(f"  项目路径: {self.config['MIAOMA_CONFIG_PROJECT_PATH']}")
        self.logger.info(f"  数据库文件: {self.config['MIAOMA_DATABASE_FILE']}")
        self.logger.info(f"  数据库路径: {self.config.get('MIAOMA_DATABASE_PATH', '')}")
        self.logger.info(f"  输出目录: {self.output_dir}")
        self.logger.info(f"  显示Python日志: {self.config.get('SHOW_PYTHON_LOGS', 'false')}")
    
    def check_output_directory(self, output_dir: str):
        """检查输出目录"""
        # 如果输出目录是相对路径，则相对于miaoma根目录
        if not os.path.isabs(output_dir):
            self.output_dir = self.miaoma_root / output_dir
        else:
            self.output_dir = Path(output_dir)
        
        self.logger.info(f"输出目录: {self.output_dir}")
        
        # 检查输出目录是否存在，不存在则创建
        if not self.output_dir.exists():
            self.logger.info(f"输出目录不存在，正在创建: {self.output_dir}")
            try:
                self.output_dir.mkdir(parents=True, exist_ok=True)
                self.logger.info("✓ 输出目录创建成功")
            except Exception as e:
                self.logger.error(f"无法创建输出目录: {self.output_dir}")
                self.logger.error(f"错误: {e}")
                sys.exit(1)
        else:
            self.logger.info("✓ 输出目录已存在")
        
        # 删除输出目录中的旧文件
        artifacts_dir = self.output_dir / 'miaoma' / 'artifacts'
        if artifacts_dir.exists():
            self.logger.info(f"删除输出目录中的旧文件: {artifacts_dir}")
            import shutil
            shutil.rmtree(artifacts_dir)
        
        # 删除配置目录中的旧文件
        config_dir = Path(self.config['MIAOMA_CONFIG_PROJECT_PATH']) / 'config'
        if config_dir.exists():
            self.logger.info(f"删除配置目录中的旧文件: {config_dir}")
            import shutil
            shutil.rmtree(config_dir)
        
        self.logger.info("✓ 输出目录检查通过")
    
    def run_generation(self):
        """执行代码生成"""
        self.logger.info("开始执行代码生成...")
        
        # 根据TOOL_MODE选择不同的命令
        tool_mode = self.config.get('TOOL_MODE', '1')
        if tool_mode == '1':
            cmd = [
                'python3', 'miaoma.py', 'gen-code',
                '--project-dir', self.config['MIAOMA_CONFIG_PROJECT_PATH'],
                '-f', self.config['MIAOMA_DATABASE_FILE']
            ]
            self.logger.info("使用gen-code命令（单文件模式）")
        elif tool_mode == '2':
            cmd = [
                'python3', 'miaoma.py', 'gen-project',
                '--project-dir', self.config['MIAOMA_CONFIG_PROJECT_PATH'],
                '-d', self.config.get('MIAOMA_DATABASE_PATH', '')
            ]
            self.logger.info("使用gen-project命令（工程模式）")
        else:
            self.logger.error(f"无效的TOOL_MODE值: {tool_mode}")
            sys.exit(1)
        
        self.logger.info(f"执行命令: {' '.join(cmd)}")
        
        # 创建临时日志文件
        temp_log_file = self.miaoma_root / 'tools' / '.temp_gen.log'
        
        try:
            show_logs = self.config.get('SHOW_PYTHON_LOGS', 'false').lower() == 'true'
            
            if show_logs:
                # 显示日志模式
                with open(temp_log_file, 'w') as log_file:
                    process = subprocess.Popen(
                        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                        universal_newlines=True, cwd=self.miaoma_root
                    )
                    
                    for line in process.stdout:
                        print(line, end='')
                        log_file.write(line)
                    
                    process.wait()
                    if process.returncode != 0:
                        raise subprocess.CalledProcessError(process.returncode, cmd)
            else:
                # 静默模式
                with open(temp_log_file, 'w') as log_file:
                    subprocess.run(
                        cmd, stdout=log_file, stderr=subprocess.STDOUT,
                        check=True, cwd=self.miaoma_root
                    )
            
            # 提取输出目录
            self._extract_output_directory(temp_log_file)
            
            self.logger.success("代码生成完成！")
            self.logger.info(f"生成的代码位于: {self.output_dir}")
            
        except subprocess.CalledProcessError:
            self.logger.error("代码生成失败！")
            if not show_logs:
                self.logger.info("提示: 设置 SHOW_PYTHON_LOGS=true 查看详细错误信息")
            sys.exit(1)
        finally:
            # 清理临时日志文件
            if temp_log_file.exists():
                temp_log_file.unlink()
    
    def _extract_output_directory(self, log_file: Path):
        """从日志文件中提取输出目录"""
        if not log_file.exists():
            return
        
        with open(log_file, 'r', encoding='utf-8') as f:
            for line in f:
                if '[MIAOMA_OUTPUT_DIR]' in line:
                    # 提取输出目录（只取第一个匹配项）
                    match = re.search(r'\[MIAOMA_OUTPUT_DIR\] 输出目录: (.+)', line)
                    if match:
                        extracted_dir = match.group(1).strip()
                        # 构建完整的绝对路径
                        full_output_dir = self.miaoma_root / extracted_dir
                        
                        # 保存到文件
                        last_output_file = self.miaoma_root / 'tools' / '.last_output_dir'
                        with open(last_output_file, 'w') as f:
                            f.write(str(full_output_dir))
                        
                        self.logger.info(f"完整输出目录: {full_output_dir}")
                        break
    
    def run(self):
        """主执行函数"""
        self.logger.title("妙码代码生成脚本 - 配置版本")
        print()
        
        # 解析命令行参数
        args = self.parse_arguments()
        
        # 确保工作目录正确
        self.ensure_working_directory()
        
        # 读取配置文件
        self.read_config()
        
        # 检查输出目录
        self.check_output_directory(args.output)
        
        # 执行代码生成
        self.run_generation()
        
        self.logger.success("所有操作完成！")


if __name__ == '__main__':
    generator = MiaomaGenerator()
    generator.run()