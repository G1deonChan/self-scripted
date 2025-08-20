#!/bin/bash

# SSH密钥管理脚本
# 功能：为Linux服务器添加/管理SSH公钥
# 作者：GitHub Copilot
# 日期：2025年8月5日

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 确认函数
confirm() {
    local prompt="$1"
    local choice
    
    while true; do
        echo -e "${YELLOW}$prompt [y/n]:${NC} "
        read -r choice
        case $choice in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) print_warning "请输入 y 或 n";;
        esac
    done
}

# 显示当前用户的SSH密钥
show_current_keys() {
    local target_user="$1"
    local ssh_dir="/home/$target_user/.ssh"
    
    if [ "$target_user" = "root" ]; then
        ssh_dir="/root/.ssh"
    fi
    
    local auth_keys="$ssh_dir/authorized_keys"
    
    if [ -f "$auth_keys" ]; then
        print_info "当前用户 $target_user 的SSH公钥："
        echo "----------------------------------------"
        cat -n "$auth_keys"
        echo "----------------------------------------"
        return 0
    else
        print_warning "用户 $target_user 还没有SSH公钥文件"
        return 1
    fi
}

# 清除指定公钥
remove_specific_key() {
    local target_user="$1"
    local ssh_dir="/home/$target_user/.ssh"
    
    if [ "$target_user" = "root" ]; then
        ssh_dir="/root/.ssh"
    fi
    
    local auth_keys="$ssh_dir/authorized_keys"
    
    if [ ! -f "$auth_keys" ]; then
        print_error "公钥文件不存在"
        return 1
    fi
    
    show_current_keys "$target_user"
    
    echo -e "${YELLOW}请输入要删除的公钥行号:${NC} "
    read -r line_number
    
    # 验证输入是否为数字
    if ! [[ "$line_number" =~ ^[0-9]+$ ]]; then
        print_error "无效的行号"
        return 1
    fi
    
    # 获取总行数
    local total_lines=$(wc -l < "$auth_keys")
    
    if [ "$line_number" -lt 1 ] || [ "$line_number" -gt "$total_lines" ]; then
        print_error "行号超出范围（1-$total_lines）"
        return 1
    fi
    
    # 显示要删除的公钥内容
    local key_to_delete=$(sed -n "${line_number}p" "$auth_keys")
    print_warning "将要删除的公钥："
    echo "$key_to_delete"
    
    if confirm "确认删除这个公钥吗？"; then
        # 创建备份
        cp "$auth_keys" "${auth_keys}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # 删除指定行
        sed -i "${line_number}d" "$auth_keys"
        print_success "公钥已删除"
        
        # 显示更新后的公钥列表
        echo ""
        show_current_keys "$target_user"
    else
        print_info "取消删除操作"
    fi
}

# 清除公钥
clear_keys() {
    local target_user="$1"
    local ssh_dir="/home/$target_user/.ssh"
    
    if [ "$target_user" = "root" ]; then
        ssh_dir="/root/.ssh"
    fi
    
    local auth_keys="$ssh_dir/authorized_keys"
    
    if [ ! -f "$auth_keys" ]; then
        print_warning "用户 $target_user 没有现有的公钥文件"
        return 0
    fi
    
    print_info "选择清除方式："
    echo "1) 清除全部公钥"
    echo "2) 清除指定公钥"
    echo "3) 取消"
    
    echo -e "${YELLOW}请选择 [1-3]:${NC} "
    read -r clear_choice
    
    case $clear_choice in
        1)
            show_current_keys "$target_user"
            if confirm "确认清除用户 $target_user 的所有公钥吗？"; then
                # 创建备份
                cp "$auth_keys" "${auth_keys}.backup.$(date +%Y%m%d_%H%M%S)"
                > "$auth_keys"
                print_success "所有公钥已清除"
            else
                print_info "取消清除操作"
            fi
            ;;
        2)
            remove_specific_key "$target_user"
            ;;
        3)
            print_info "取消清除操作"
            ;;
        *)
            print_error "无效选择"
            ;;
    esac
}

# 添加SSH公钥
add_ssh_key() {
    local target_user="$1"
    local ssh_dir="/home/$target_user/.ssh"
    
    if [ "$target_user" = "root" ]; then
        ssh_dir="/root/.ssh"
    fi
    
    local auth_keys="$ssh_dir/authorized_keys"
    
    # 创建.ssh目录（如果不存在）
    if [ ! -d "$ssh_dir" ]; then
        print_info "创建SSH目录: $ssh_dir"
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        chown "$target_user:$target_user" "$ssh_dir"
    fi
    
    print_info "请粘贴SSH公钥（完成后按回车）："
    echo -e "${YELLOW}公钥内容:${NC}"
    read -r public_key
    
    # 验证公钥格式
    if [[ ! "$public_key" =~ ^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
        print_error "无效的SSH公钥格式"
        return 1
    fi
    
    print_info "您输入的公钥："
    echo "$public_key"
    
    if confirm "确认添加这个公钥到用户 $target_user 吗？"; then
        # 检查公钥是否已存在
        if [ -f "$auth_keys" ] && grep -Fq "$public_key" "$auth_keys"; then
            print_warning "这个公钥已经存在"
            return 1
        fi
        
        # 添加公钥
        echo "$public_key" >> "$auth_keys"
        chmod 600 "$auth_keys"
        chown "$target_user:$target_user" "$auth_keys"
        
        print_success "SSH公钥已成功添加到用户 $target_user"
        
        # 显示更新后的公钥列表
        echo ""
        show_current_keys "$target_user"
    else
        print_info "取消添加操作"
    fi
}

# 选择目标用户
select_user() {
    local current_user=$(whoami)
    
    print_info "选择目标用户："
    echo "1) 当前用户 ($current_user)"
    echo "2) root用户"
    echo "3) 其他用户"
    
    echo -e "${YELLOW}请选择 [1-3]:${NC} "
    read -r user_choice
    
    case $user_choice in
        1)
            echo "$current_user"
            ;;
        2)
            if [ "$current_user" != "root" ]; then
                print_warning "操作root用户需要sudo权限"
                if ! confirm "继续操作吗？"; then
                    return 1
                fi
            fi
            echo "root"
            ;;
        3)
            echo -e "${YELLOW}请输入用户名:${NC} "
            read -r target_user
            
            # 验证用户是否存在
            if ! id "$target_user" &>/dev/null; then
                print_error "用户 $target_user 不存在"
                return 1
            fi
            
            if confirm "确认操作用户 $target_user 吗？"; then
                echo "$target_user"
            else
                return 1
            fi
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac
}

# 主菜单
main_menu() {
    while true; do
        echo ""
        echo "========================================="
        echo "          SSH密钥管理工具"
        echo "========================================="
        echo "1) 添加SSH公钥"
        echo "2) 查看现有公钥"
        echo "3) 清除公钥"
        echo "4) 退出"
        echo "========================================="
        
        echo -e "${YELLOW}请选择操作 [1-4]:${NC} "
        read -r choice
        
        case $choice in
            1)
                print_info "开始添加SSH公钥..."
                target_user=$(select_user)
                if [ $? -eq 0 ] && [ -n "$target_user" ]; then
                    # 询问是否清除原有公钥
                    if confirm "是否要先清除用户 $target_user 的原有公钥？"; then
                        clear_keys "$target_user"
                    fi
                    add_ssh_key "$target_user"
                fi
                ;;
            2)
                print_info "查看现有公钥..."
                target_user=$(select_user)
                if [ $? -eq 0 ] && [ -n "$target_user" ]; then
                    show_current_keys "$target_user"
                fi
                ;;
            3)
                print_info "清除公钥..."
                target_user=$(select_user)
                if [ $? -eq 0 ] && [ -n "$target_user" ]; then
                    clear_keys "$target_user"
                fi
                ;;
            4)
                print_success "感谢使用SSH密钥管理工具！"
                exit 0
                ;;
            *)
                print_error "无效选择，请输入 1-4"
                ;;
        esac
    done
}

# 检查是否以root权限运行（可选）
check_permissions() {
    local current_user=$(whoami)
    if [ "$current_user" != "root" ]; then
        print_warning "当前以用户 $current_user 身份运行"
        print_warning "某些操作可能需要sudo权限"
        if ! confirm "继续执行吗？"; then
            exit 1
        fi
    fi
}

# 主程序入口
main() {
    clear
    print_info "欢迎使用SSH密钥管理工具"
    print_info "脚本版本：1.0"
    print_info "运行日期：$(date '+%Y-%m-%d %H:%M:%S')"
    
    check_permissions
    main_menu
}

# 执行主程序
main "$@"