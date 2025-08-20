#!/bin/bash

# 快速SSH密钥添加工具
# 功能：快速为当前用户添加SSH公钥

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 主函数
main() {
    clear
    current_user=$(whoami)
    
    echo "====================================="
    echo "    快速SSH密钥添加工具"
    echo "====================================="
    echo "当前用户: $current_user"
    echo ""
    
    # 设置SSH目录
    if [ "$current_user" = "root" ]; then
        ssh_dir="/root/.ssh"
    else
        ssh_dir="/home/$current_user/.ssh"
    fi
    
    auth_keys="$ssh_dir/authorized_keys"
    
    # 创建SSH目录
    if [ ! -d "$ssh_dir" ]; then
        print_info "创建SSH目录: $ssh_dir"
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        chown "$current_user:$current_user" "$ssh_dir" 2>/dev/null || true
    fi
    
    # 获取公钥
    print_info "请粘贴您的SSH公钥，然后按回车："
    echo -n "公钥: "
    read -r public_key
    
    # 验证公钥格式
    if [[ ! "$public_key" =~ ^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-) ]]; then
        print_error "无效的SSH公钥格式"
        exit 1
    fi
    
    echo ""
    print_info "收到的公钥:"
    echo "$public_key"
    echo ""
    
    # 询问确认
    echo -n "确认添加这个公钥到用户 $current_user 吗? [y/n]: "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy] ]]; then
        # 检查是否已存在
        if [ -f "$auth_keys" ] && grep -Fq "$public_key" "$auth_keys"; then
            print_error "这个公钥已经存在"
            exit 1
        fi
        
        # 添加公钥
        echo "$public_key" >> "$auth_keys"
        chmod 600 "$auth_keys"
        chown "$current_user:$current_user" "$auth_keys" 2>/dev/null || true
        
        print_success "SSH公钥已成功添加!"
        
        # 显示结果
        echo ""
        print_info "当前所有公钥:"
        echo "------------------------"
        cat -n "$auth_keys"
        echo "------------------------"
    else
        print_info "取消添加操作"
    fi
}

main "$@"
