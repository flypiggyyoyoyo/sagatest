#!/usr/bin/env perl

# =============================================================================
# 妙码代码生成工具 - Perl实现
# 支持配置文件驱动的代码生成
# =============================================================================

use strict;
use warnings;
use utf8;
use Getopt::Long;
use File::Spec;
use File::Path qw(make_path remove_tree);
use File::Basename;
use Cwd qw(getcwd abs_path);
use POSIX qw(strftime);

# 启用UTF-8输出
binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

# 日志工具包
package Logger {
    # 颜色定义
    our %COLORS = (
        RED    => "\033[0;31m",
        GREEN  => "\033[0;32m",
        YELLOW => "\033[1;33m",
        BLUE   => "\033[0;34m",
        PURPLE => "\033[0;35m",
        CYAN   => "\033[0;36m",
        NC     => "\033[0m",  # No Color
    );
    
    # 日志级别
    our %LEVELS = (
        DEBUG => 0,
        INFO  => 1,
        WARN  => 2,
        ERROR => 3,
    );
    
    sub new {
        my ($class, %args) = @_;
        my $self = {
            level => $args{level} // $LEVELS{INFO},
            show_timestamp => $args{show_timestamp} // 0,
        };
        return bless $self, $class;
    }
    
    sub _format_message {
        my ($self, $level_name, $message) = @_;
        my $timestamp = $self->{show_timestamp} ? 
            "[" . strftime("%Y-%m-%d %H:%M:%S", localtime) . "] " : "";
        return "${timestamp}${level_name} ${message}";
    }
    
    sub debug {
        my ($self, $message) = @_;
        if ($self->{level} <= $LEVELS{DEBUG}) {
            print $self->_format_message("$COLORS{CYAN}[DEBUG]$COLORS{NC}", $message) . "\n";
        }
    }
    
    sub info {
        my ($self, $message) = @_;
        if ($self->{level} <= $LEVELS{INFO}) {
            print $self->_format_message("$COLORS{BLUE}[INFO]$COLORS{NC}", $message) . "\n";
        }
    }
    
    sub warn {
        my ($self, $message) = @_;
        if ($self->{level} <= $LEVELS{WARN}) {
            print $self->_format_message("$COLORS{YELLOW}[WARN]$COLORS{NC}", $message) . "\n";
        }
    }
    
    sub error {
        my ($self, $message) = @_;
        if ($self->{level} <= $LEVELS{ERROR}) {
            print STDERR $self->_format_message("$COLORS{RED}[ERROR]$COLORS{NC}", $message) . "\n";
        }
    }
    
    sub success {
        my ($self, $message) = @_;
        if ($self->{level} <= $LEVELS{INFO}) {
            print $self->_format_message("$COLORS{GREEN}[SUCCESS]$COLORS{NC}", $message) . "\n";
        }
    }
    
    sub title {
        my ($self, $title) = @_;
        print "$COLORS{PURPLE}=== $title ===$COLORS{NC}\n";
    }
}

# 妙码代码生成器
package MiaomaGenerator {
    sub new {
        my ($class) = @_;
        my $self = {
            logger => Logger->new(),
            miaoma_root => undef,
            output_dir => undef,
            config => {},
        };
        return bless $self, $class;
    }
    
    sub show_help {
        my ($self, $prog_name) = @_;
        print <<EOF;
用法: $prog_name [选项]
选项:
  -o, --output DIR    指定输出目录（必需）
  -h, --help          显示此帮助信息

工具模式（在project.ini中配置）:
  TOOL_MODE=1         使用gen-code命令（单文件模式）
  TOOL_MODE=2         使用gen-project命令（工程模式）

示例:
  $prog_name -o /path/to/output        # 使用指定的输出目录
  $prog_name --output ~/my-project     # 使用指定的输出目录
EOF
    }
    
    sub parse_arguments {
        my ($self) = @_;
        my %args;
        
        GetOptions(
            'o|output=s' => \$args{output},
            'h|help'     => \$args{help},
        ) or die "参数解析失败\n";
        
        if ($args{help}) {
            $self->show_help($0);
            exit 0;
        }
        
        unless ($args{output}) {
            $self->{logger}->error("缺少必需的输出目录参数");
            $self->show_help($0);
            exit 1;
        }
        
        return %args;
    }
    
    sub ensure_working_directory {
        my ($self) = @_;
        my $current_dir = getcwd();
        my $script_dir = abs_path(dirname($0));
        
        $self->{logger}->info("当前工作目录: $current_dir");
        $self->{logger}->info("脚本所在目录: $script_dir");
        
        # 从脚本目录向上查找miaoma根目录
        my $search_dir = $script_dir;
        while ($search_dir ne File::Spec->rootdir()) {
            if (-f File::Spec->catfile($search_dir, 'miaoma.py') &&
                -d File::Spec->catdir($search_dir, 'src') &&
                -d File::Spec->catdir($search_dir, 'assets')) {
                $self->{miaoma_root} = $search_dir;
                last;
            }
            $search_dir = dirname($search_dir);
        }
        
        unless ($self->{miaoma_root}) {
            $self->{logger}->error("无法找到 miaoma 项目根目录！");
            $self->{logger}->error("请确保脚本在 miaoma 项目目录结构中");
            exit 1;
        }
        
        $self->{logger}->info("找到 miaoma 根目录: $self->{miaoma_root}");
        
        # 切换到根目录
        if ($current_dir ne $self->{miaoma_root}) {
            $self->{logger}->info("切换工作目录到: $self->{miaoma_root}");
            chdir($self->{miaoma_root}) or die "无法切换到目录: $self->{miaoma_root}\n";
        }
        
        $self->{logger}->info("工作目录设置完成");
    }
    
    sub read_config {
        my ($self) = @_;
        my $config_file = File::Spec->catfile($self->{miaoma_root}, 'tools', 'project.ini');
        
        unless (-f $config_file) {
            $self->{logger}->error("配置文件不存在: $config_file");
            exit 1;
        }
        
        $self->{logger}->info("读取配置文件: $config_file");
        
        # 读取配置项
        open my $fh, '<:encoding(UTF-8)', $config_file or die "无法打开配置文件: $!\n";
        while (my $line = <$fh>) {
            chomp $line;
            $line =~ s/^\s+|\s+$//g;  # 去除前后空格
            
            # 跳过注释和空行
            next if $line =~ /^#/ || $line eq '';
            
            if ($line =~ /^([^=]+)=(.*)$/) {
                my ($key, $value) = ($1, $2);
                $key =~ s/^\s+|\s+$//g;
                $value =~ s/^\s+|\s+$//g;
                
                if ($key =~ /^(MIAOMA_CONFIG_PROJECT_PATH|MIAOMA_DATABASE_FILE|MIAOMA_DATABASE_PATH|TOOL_MODE|SHOW_PYTHON_LOGS)$/) {
                    $self->{config}{$key} = $value;
                }
            }
        }
        close $fh;
        
        # 验证必要的配置项
        my @required_keys = qw(MIAOMA_CONFIG_PROJECT_PATH MIAOMA_DATABASE_FILE);
        for my $key (@required_keys) {
            unless (exists $self->{config}{$key}) {
                $self->{logger}->error("配置文件中缺少必要的配置项: $key");
                exit 1;
            }
        }
        
        # 验证TOOL_MODE
        my $tool_mode = $self->{config}{TOOL_MODE} // '1';
        unless ($tool_mode =~ /^[12]$/) {
            $self->{logger}->error("无效的TOOL_MODE值: $tool_mode，必须是1或2");
            exit 1;
        }
        
        $self->{logger}->info("配置读取完成:");
        $self->{logger}->info("  工具模式: " . ($self->{config}{TOOL_MODE} // '1'));
        $self->{logger}->info("  项目路径: $self->{config}{MIAOMA_CONFIG_PROJECT_PATH}");
        $self->{logger}->info("  数据库文件: $self->{config}{MIAOMA_DATABASE_FILE}");
        $self->{logger}->info("  数据库路径: " . ($self->{config}{MIAOMA_DATABASE_PATH} // ''));
        $self->{logger}->info("  输出目录: $self->{output_dir}");
        $self->{logger}->info("  显示Python日志: " . ($self->{config}{SHOW_PYTHON_LOGS} // 'false'));
    }
    
    sub check_output_directory {
        my ($self, $output_dir) = @_;
        
        # 如果输出目录是相对路径，则相对于miaoma根目录
        if (File::Spec->file_name_is_absolute($output_dir)) {
            $self->{output_dir} = $output_dir;
        } else {
            $self->{output_dir} = File::Spec->catdir($self->{miaoma_root}, $output_dir);
        }
        
        $self->{logger}->info("输出目录: $self->{output_dir}");
        
        # 检查输出目录是否存在，不存在则创建
        unless (-d $self->{output_dir}) {
            $self->{logger}->info("输出目录不存在，正在创建: $self->{output_dir}");
            eval {
                make_path($self->{output_dir});
                $self->{logger}->info("✓ 输出目录创建成功");
            };
            if ($@) {
                $self->{logger}->error("无法创建输出目录: $self->{output_dir}");
                $self->{logger}->error("错误: $@");
                exit 1;
            }
        } else {
            $self->{logger}->info("✓ 输出目录已存在");
        }
        
        # 删除输出目录中的旧文件
        my $artifacts_dir = File::Spec->catdir($self->{output_dir}, 'miaoma', 'artifacts');
        if (-d $artifacts_dir) {
            $self->{logger}->info("删除输出目录中的旧文件: $artifacts_dir");
            remove_tree($artifacts_dir);
        }
        
        # 删除配置目录中的旧文件
        my $config_dir = File::Spec->catdir($self->{config}{MIAOMA_CONFIG_PROJECT_PATH}, 'config');
        if (-d $config_dir) {
            $self->{logger}->info("删除配置目录中的旧文件: $config_dir");
            remove_tree($config_dir);
        }
        
        $self->{logger}->info("✓ 输出目录检查通过");
    }
    
    sub run_generation {
        my ($self) = @_;
        $self->{logger}->info("开始执行代码生成...");
        
        # 根据TOOL_MODE选择不同的命令
        my $tool_mode = $self->{config}{TOOL_MODE} // '1';
        my @cmd;
        
        if ($tool_mode eq '1') {
            @cmd = (
                'python3', 'miaoma.py', 'gen-code',
                '--project-dir', $self->{config}{MIAOMA_CONFIG_PROJECT_PATH},
                '-f', $self->{config}{MIAOMA_DATABASE_FILE}
            );
            $self->{logger}->info("使用gen-code命令（单文件模式）");
        } elsif ($tool_mode eq '2') {
            @cmd = (
                'python3', 'miaoma.py', 'gen-project',
                '--project-dir', $self->{config}{MIAOMA_CONFIG_PROJECT_PATH},
                '-d', $self->{config}{MIAOMA_DATABASE_PATH} // ''
            );
            $self->{logger}->info("使用gen-project命令（工程模式）");
        } else {
            $self->{logger}->error("无效的TOOL_MODE值: $tool_mode");
            exit 1;
        }
        
        $self->{logger}->info("执行命令: " . join(' ', @cmd));
        
        # 创建临时日志文件
        my $temp_log_file = File::Spec->catfile($self->{miaoma_root}, 'tools', '.temp_gen.log');
        
        my $show_logs = ($self->{config}{SHOW_PYTHON_LOGS} // 'false') eq 'true';
        
        # 执行命令
        my $exit_code;
        if ($show_logs) {
            # 显示日志模式
            $exit_code = system(join(' ', @cmd) . " 2>&1 | tee $temp_log_file");
        } else {
            # 静默模式
            $exit_code = system(join(' ', @cmd) . " > $temp_log_file 2>&1");
        }
        
        if ($exit_code != 0) {
            $self->{logger}->error("代码生成失败！");
            unless ($show_logs) {
                $self->{logger}->info("提示: 设置 SHOW_PYTHON_LOGS=true 查看详细错误信息");
            }
            exit 1;
        }
        
        # 提取输出目录
        $self->_extract_output_directory($temp_log_file);
        
        $self->{logger}->success("代码生成完成！");
        $self->{logger}->info("生成的代码位于: $self->{output_dir}");
        
        # 清理临时日志文件
        unlink $temp_log_file if -f $temp_log_file;
    }
    
    sub _extract_output_directory {
        my ($self, $log_file) = @_;
        return unless -f $log_file;
        
        open my $fh, '<:encoding(UTF-8)', $log_file or return;
        while (my $line = <$fh>) {
            if ($line =~ /\[MIAOMA_OUTPUT_DIR\] 输出目录: (.+)/) {
                my $extracted_dir = $1;
                $extracted_dir =~ s/^\s+|\s+$//g;
                
                # 构建完整的绝对路径
                my $full_output_dir = File::Spec->catdir($self->{miaoma_root}, $extracted_dir);
                
                # 保存到文件
                my $last_output_file = File::Spec->catfile($self->{miaoma_root}, 'tools', '.last_output_dir');
                open my $out_fh, '>:encoding(UTF-8)', $last_output_file or return;
                print $out_fh $full_output_dir;
                close $out_fh;
                
                $self->{logger}->info("完整输出目录: $full_output_dir");
                last;
            }
        }
        close $fh;
    }
    
    sub run {
        my ($self) = @_;
        $self->{logger}->title("妙码代码生成脚本 - 配置版本");
        print "\n";
        
        # 解析命令行参数
        my %args = $self->parse_arguments();
        
        # 确保工作目录正确
        $self->ensure_working_directory();
        
        # 读取配置文件
        $self->read_config();
        
        # 检查输出目录
        $self->check_output_directory($args{output});
        
        # 执行代码生成
        $self->run_generation();
        
        $self->{logger}->success("所有操作完成！");
    }
}

# 主程序
my $generator = MiaomaGenerator->new();
$generator->run();