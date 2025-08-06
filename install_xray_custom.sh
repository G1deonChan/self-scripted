#!/bin/bash

# Xray 自动安装和管理脚本
# 支持自动检测系统架构，安装最新版本，配置代理等功能
# 作者：GitHub Copilot
# 日期：2025年8月6日

# 配置变量
XRAY_DIR="/usr/local/xray"
CONFIG_FILE="$XRAY_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/xray.service"
LOG_FILE="$XRAY_DIR/xray.log"
GITHUB_API="https://api.github.com/repos/XTLS/Xray-core/releases"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

print_title() {
    echo -e "${PURPLE}[XRAY]${NC} $1"
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

# 检测系统架构
detect_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "linux-64"
            ;;
        aarch64|arm64)
            echo "linux-arm64-v8a"
            ;;
        armv7l)
            echo "linux-arm32-v7a"
            ;;
        armv6l)
            echo "linux-arm32-v6"
            ;;
        i386|i686)
            echo "linux-32"
            ;;
        *)
            print_error "不支持的架构: $arch"
            return 1
            ;;
    esac
}

# 获取最新版本
get_latest_version() {
    print_info "正在获取最新版本信息..."
    local version=$(curl -s "$GITHUB_API/latest" | grep -o '"tag_name": "[^"]*' | grep -o '[^"]*$')
    if [ -z "$version" ]; then
        print_error "无法获取最新版本信息"
        return 1
    fi
    echo "$version"
}

# 获取所有版本列表
list_versions() {
    print_info "正在获取版本列表..."
    curl -s "$GITHUB_API" | grep -o '"tag_name": "[^"]*' | grep -o '[^"]*$' | head -10
}

# 下载并安装 Xray
install_xray() {
    local version="$1"
    local arch=$(detect_architecture)
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    if [ -z "$version" ]; then
        version=$(get_latest_version)
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    print_info "准备安装 Xray $version ($arch)"
    
    # 创建目录
    sudo mkdir -p "$XRAY_DIR"
    
    # 下载 URL
    local download_url="https://github.com/XTLS/Xray-core/releases/download/$version/Xray-$arch.zip"
    local temp_file="/tmp/xray.zip"
    
    print_info "正在下载 Xray..."
    if ! curl -L "$download_url" -o "$temp_file"; then
        print_error "下载失败"
        return 1
    fi
    
    print_info "正在解压..."
    if ! sudo unzip -o "$temp_file" -d "$XRAY_DIR"; then
        print_error "解压失败"
        rm -f "$temp_file"
        return 1
    fi
    
    # 设置权限
    sudo chmod +x "$XRAY_DIR/xray"
    rm -f "$temp_file"
    
    print_success "Xray $version 安装完成"
    return 0
}

# 创建配置文件
create_config() {
    local url="$1"
    
    print_info "正在解析配置链接..."
    
    # 基础配置模板
    local config_template='{
  "log": {
    "loglevel": "warning",
    "access": "'$LOG_FILE'",
    "error": "'$LOG_FILE'"
  },
  "inbounds": [
    {
      "tag": "socks",
      "port": 1080,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "settings": {
        "auth": "noauth",
        "udp": false
      }
    },
    {
      "tag": "http",
      "port": 1081,
      "listen": "127.0.0.1",
      "protocol": "http",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    OUTBOUND_PLACEHOLDER,
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {
        "response": {
          "type": "http"
        }
      },
      "tag": "block"
    }
  ]
}'
    
    # 解析不同类型的链接
    if [[ "$url" == vless://* ]]; then
        parse_vless_url "$url" "$config_template"
    elif [[ "$url" == vmess://* ]]; then
        parse_vmess_url "$url" "$config_template"
    elif [[ "$url" == ss://* ]]; then
        parse_ss_url "$url" "$config_template"
    else
        print_error "不支持的链接格式"
        return 1
    fi
}

# 解析 VLESS 链接
parse_vless_url() {
    local url="$1"
    local template="$2"
    
    # 移除 vless:// 前缀
    local content="${url#vless://}"
    
    # 分离用户信息和服务器信息
    local user_server="${content%%\?*}"
    local params="${content#*\?}"
    
    # 提取 UUID 和服务器地址
    local uuid="${user_server%%@*}"
    local server_port="${user_server#*@}"
    local server="${server_port%:*}"
    local port="${server_port#*:}"
    
    # 解析参数
    local security flow sni alpn type host path
    IFS='&' read -ra ADDR <<< "$params"
    for param in "${ADDR[@]}"; do
        case "$param" in
            security=*) security="${param#*=}" ;;
            flow=*) flow="${param#*=}" ;;
            sni=*) sni="${param#*=}" ;;
            alpn=*) alpn="${param#*=}" ;;
            type=*) type="${param#*=}" ;;
            host=*) host="${param#*=}" ;;
            path=*) path="${param#*=}" ;;
        esac
    done
    
    # 构建 VLESS outbound
    local outbound='{
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "'$server'",
            "port": '$port',
            "users": [
              {
                "id": "'$uuid'",
                "alterId": 0,
                "security": "auto"'
    
    if [ -n "$flow" ]; then
        outbound+=',
                "flow": "'$flow'"'
    fi
    
    outbound+='
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "'${type:-tcp}'"'
    
    if [ "$security" = "tls" ] || [ "$security" = "reality" ]; then
        outbound+=',
        "security": "'$security'",
        "tlsSettings": {
          "allowInsecure": false'
        
        if [ -n "$sni" ]; then
            outbound+=',
          "serverName": "'$sni'"'
        fi
        
        if [ -n "$alpn" ]; then
            outbound+=',
          "alpn": ["'$alpn'"]'
        fi
        
        outbound+='
        }'
    fi
    
    if [ "$type" = "ws" ]; then
        outbound+=',
        "wsSettings": {
          "path": "'${path:-/}'"'
        
        if [ -n "$host" ]; then
            outbound+=',
          "headers": {
            "Host": "'$host'"
          }'
        fi
        
        outbound+='
        }'
    fi
    
    outbound+='
      }
    }'
    
    # 替换模板中的占位符
    local final_config="${template/OUTBOUND_PLACEHOLDER/$outbound}"
    
    # 保存配置
    echo "$final_config" | sudo tee "$CONFIG_FILE" > /dev/null
    print_success "VLESS 配置已生成"
}

# 解析 VMess 链接
parse_vmess_url() {
    local url="$1"
    local template="$2"
    
    # 移除 vmess:// 前缀并解码 base64
    local content="${url#vmess://}"
    local decoded=$(echo "$content" | base64 -d 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_error "VMess 链接解码失败"
        return 1
    fi
    
    # 解析 JSON
    local server=$(echo "$decoded" | grep -o '"add":"[^"]*' | cut -d'"' -f4)
    local port=$(echo "$decoded" | grep -o '"port":"[^"]*' | cut -d'"' -f4)
    local uuid=$(echo "$decoded" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    local alterId=$(echo "$decoded" | grep -o '"aid":"[^"]*' | cut -d'"' -f4)
    local security=$(echo "$decoded" | grep -o '"scy":"[^"]*' | cut -d'"' -f4)
    local network=$(echo "$decoded" | grep -o '"net":"[^"]*' | cut -d'"' -f4)
    local path=$(echo "$decoded" | grep -o '"path":"[^"]*' | cut -d'"' -f4)
    local host=$(echo "$decoded" | grep -o '"host":"[^"]*' | cut -d'"' -f4)
    local tls=$(echo "$decoded" | grep -o '"tls":"[^"]*' | cut -d'"' -f4)
    
    # 构建 VMess outbound
    local outbound='{
      "tag": "proxy",
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "'$server'",
            "port": '${port:-443}',
            "users": [
              {
                "id": "'$uuid'",
                "alterId": '${alterId:-0}',
                "security": "'${security:-auto}'"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "'${network:-tcp}'"'
    
    if [ "$tls" = "tls" ]; then
        outbound+=',
        "security": "tls",
        "tlsSettings": {
          "allowInsecure": false'
        
        if [ -n "$host" ]; then
            outbound+=',
          "serverName": "'$host'"'
        fi
        
        outbound+='
        }'
    fi
    
    if [ "$network" = "ws" ]; then
        outbound+=',
        "wsSettings": {
          "path": "'${path:-/}'"'
        
        if [ -n "$host" ]; then
            outbound+=',
          "headers": {
            "Host": "'$host'"
          }'
        fi
        
        outbound+='
        }'
    fi
    
    outbound+='
      }
    }'
    
    # 替换模板中的占位符
    local final_config="${template/OUTBOUND_PLACEHOLDER/$outbound}"
    
    # 保存配置
    echo "$final_config" | sudo tee "$CONFIG_FILE" > /dev/null
    print_success "VMess 配置已生成"
}

# 解析 Shadowsocks 链接
parse_ss_url() {
    local url="$1"
    local template="$2"
    
    # 移除 ss:// 前缀
    local content="${url#ss://}"
    
    # 分离认证信息和服务器信息
    if [[ "$content" == *"@"* ]]; then
        local auth_server="${content}"
        local auth_part="${auth_server%%@*}"
        local server_part="${auth_server#*@}"
    else
        print_error "SS 链接格式错误"
        return 1
    fi
    
    # 解码认证信息
    local decoded_auth=$(echo "$auth_part" | base64 -d 2>/dev/null)
    if [ $? -ne 0 ]; then
        # 可能是未编码的格式
        decoded_auth="$auth_part"
    fi
    
    # 提取方法和密码
    local method="${decoded_auth%%:*}"
    local password="${decoded_auth#*:}"
    
    # 提取服务器和端口
    local server="${server_part%:*}"
    local port="${server_part#*:}"
    
    # 构建 Shadowsocks outbound
    local outbound='{
      "tag": "proxy",
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "address": "'$server'",
            "port": '$port',
            "method": "'$method'",
            "password": "'$password'"
          }
        ]
      }
    }'
    
    # 替换模板中的占位符
    local final_config="${template/OUTBOUND_PLACEHOLDER/$outbound}"
    
    # 保存配置
    echo "$final_config" | sudo tee "$CONFIG_FILE" > /dev/null
    print_success "Shadowsocks 配置已生成"
}

# 创建系统服务
create_service() {
    print_info "正在创建系统服务..."
    
    sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls/xray-core
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$XRAY_DIR/xray run -config $CONFIG_FILE
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable xray
    print_success "系统服务已创建"
}

# 启动 Xray 服务
start_xray() {
    print_info "正在启动 Xray 服务..."
    sudo systemctl start xray
    
    if sudo systemctl is-active xray > /dev/null; then
        print_success "Xray 服务已启动"
        return 0
    else
        print_error "Xray 服务启动失败"
        return 1
    fi
}

# 停止 Xray 服务
stop_xray() {
    print_info "正在停止 Xray 服务..."
    sudo systemctl stop xray
    sudo systemctl disable xray
    print_success "Xray 服务已停止"
}

# 检查 Xray 状态
check_status() {
    if sudo systemctl is-active xray > /dev/null; then
        print_success "Xray 服务正在运行"
        echo "SOCKS5 代理: 127.0.0.1:1080"
        echo "HTTP 代理: 127.0.0.1:1081"
        
        # 显示最近的日志
        if [ -f "$LOG_FILE" ]; then
            echo ""
            print_info "最近日志:"
            tail -n 5 "$LOG_FILE" 2>/dev/null || echo "无法读取日志文件"
        fi
    else
        print_warning "Xray 服务未运行"
    fi
}

# 配置系统代理
configure_system_proxy() {
    if command -v gsettings > /dev/null; then
        print_info "正在配置系统代理 (GNOME)..."
        gsettings set org.gnome.system.proxy mode 'manual'
        gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
        gsettings set org.gnome.system.proxy.socks port 1080
        gsettings set org.gnome.system.proxy.http host '127.0.0.1'
        gsettings set org.gnome.system.proxy.http port 1081
        gsettings set org.gnome.system.proxy.https host '127.0.0.1'
        gsettings set org.gnome.system.proxy.https port 1081
        print_success "系统代理已配置"
    else
        print_warning "无法自动配置系统代理，请手动设置:"
        echo "SOCKS5: 127.0.0.1:1080"
        echo "HTTP/HTTPS: 127.0.0.1:1081"
    fi
}

# 禁用系统代理
disable_system_proxy() {
    if command -v gsettings > /dev/null; then
        print_info "正在禁用系统代理..."
        gsettings set org.gnome.system.proxy mode 'none'
        print_success "系统代理已禁用"
    else
        print_warning "请手动禁用系统代理"
    fi
}

# 卸载 Xray
uninstall_xray() {
    print_warning "这将完全卸载 Xray 及其配置文件"
    if confirm "确认卸载吗？"; then
        # 停止并删除服务
        sudo systemctl stop xray 2>/dev/null
        sudo systemctl disable xray 2>/dev/null
        sudo rm -f "$SERVICE_FILE"
        sudo systemctl daemon-reload
        
        # 删除文件
        sudo rm -rf "$XRAY_DIR"
        
        # 禁用系统代理
        disable_system_proxy
        
        print_success "Xray 已完全卸载"
    fi
}

# 管理配置链接
manage_configs() {
    while true; do
        echo ""
        echo "========================================="
        echo "          配置管理"
        echo "========================================="
        echo "1) 添加新配置链接"
        echo "2) 查看当前配置"
        echo "3) 测试连接"
        echo "4) 返回主菜单"
        echo "========================================="
        
        echo -e "${YELLOW}请选择操作 [1-4]:${NC} "
        read -r choice
        
        case $choice in
            1)
                echo -e "${YELLOW}请输入配置链接 (vless://、vmess://、ss://):${NC} "
                read -r config_url
                if [ -n "$config_url" ]; then
                    create_config "$config_url"
                    if [ $? -eq 0 ]; then
                        sudo systemctl restart xray
                        print_success "配置已更新并重启服务"
                    fi
                fi
                ;;
            2)
                if [ -f "$CONFIG_FILE" ]; then
                    print_info "当前配置:"
                    sudo cat "$CONFIG_FILE" | jq . 2>/dev/null || sudo cat "$CONFIG_FILE"
                else
                    print_warning "没有找到配置文件"
                fi
                ;;
            3)
                print_info "正在测试连接..."
                if sudo systemctl is-active xray > /dev/null; then
                    # 简单的连接测试
                    if curl -s --socks5 127.0.0.1:1080 --connect-timeout 5 https://www.google.com > /dev/null; then
                        print_success "连接测试成功"
                    else
                        print_error "连接测试失败"
                    fi
                else
                    print_error "Xray 服务未运行"
                fi
                ;;
            4)
                break
                ;;
            *)
                print_error "无效选择"
                ;;
        esac
    done
}

# 主菜单
main_menu() {
    while true; do
        echo ""
        echo "========================================="
        echo "          Xray 管理工具"
        echo "========================================="
        
        if [ -f "$XRAY_DIR/xray" ]; then
            if sudo systemctl is-active xray > /dev/null; then
                echo -e "${GREEN}状态: 已安装并运行${NC}"
            else
                echo -e "${YELLOW}状态: 已安装但未运行${NC}"
            fi
        else
            echo -e "${RED}状态: 未安装${NC}"
        fi
        
        echo "========================================="
        echo "1) 安装/升级 Xray"
        echo "2) 配置代理链接"
        echo "3) 启动服务"
        echo "4) 停止服务"
        echo "5) 查看状态"
        echo "6) 配置系统代理"
        echo "7) 禁用系统代理"
        echo "8) 管理配置"
        echo "9) 卸载 Xray"
        echo "0) 退出"
        echo "========================================="
        
        echo -e "${YELLOW}请选择操作 [0-9]:${NC} "
        read -r choice
        
        case $choice in
            1)
                echo ""
                echo "1) 安装最新版本"
                echo "2) 选择特定版本"
                echo -e "${YELLOW}请选择 [1-2]:${NC} "
                read -r install_choice
                
                case $install_choice in
                    1)
                        install_xray
                        if [ $? -eq 0 ]; then
                            create_service
                        fi
                        ;;
                    2)
                        echo ""
                        print_info "可用版本列表:"
                        list_versions
                        echo ""
                        echo -e "${YELLOW}请输入版本号 (如 v1.8.4):${NC} "
                        read -r version
                        if [ -n "$version" ]; then
                            install_xray "$version"
                            if [ $? -eq 0 ]; then
                                create_service
                            fi
                        fi
                        ;;
                esac
                ;;
            2)
                echo -e "${YELLOW}请输入配置链接 (vless://、vmess://、ss://):${NC} "
                read -r config_url
                if [ -n "$config_url" ]; then
                    create_config "$config_url"
                    if [ $? -eq 0 ]; then
                        print_info "配置已保存，记得启动服务"
                    fi
                fi
                ;;
            3)
                start_xray
                ;;
            4)
                stop_xray
                ;;
            5)
                check_status
                ;;
            6)
                configure_system_proxy
                ;;
            7)
                disable_system_proxy
                ;;
            8)
                manage_configs
                ;;
            9)
                uninstall_xray
                ;;
            0)
                print_success "感谢使用 Xray 管理工具！"
                exit 0
                ;;
            *)
                print_error "无效选择，请输入 0-9"
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    for cmd in curl unzip systemctl; do
        if ! command -v "$cmd" > /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "缺少以下依赖: ${missing_deps[*]}"
        print_info "请先安装这些依赖，然后重新运行脚本"
        exit 1
    fi
}

# 检查权限
check_permissions() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "检测到以 root 身份运行"
    else
        print_info "当前以普通用户身份运行，某些操作需要 sudo 权限"
    fi
}

# 主函数
main() {
    print_title "Xray 自动安装和管理脚本"
    echo ""
    
    check_dependencies
    check_permissions
    
    main_menu
}

# 运行主函数
main "$@"
